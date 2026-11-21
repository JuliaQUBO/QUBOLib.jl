const RELEASED_PUBLIC_EVIDENCE = "PUBLIC-PROVENANCE.json"
const RELEASED_PUBLIC_SCHEMA = "qubolib-released-public-provenance-v1"
const RELEASED_PRIVATE_KEYS = ("audit", "environment")
const RELEASED_AUDIT_ARTIFACT_KEYS = ("polynomial", "variable_order", "domain_transformations", "source_order")

# This check also covers public report diagnostics and free-form JSON metadata.
# Public URLs and repo-relative names are valid. Local paths and file URIs are not.
function require_public_metadata(value)
    if value isa AbstractDict
        foreach(require_public_metadata, keys(value))
        foreach(require_public_metadata, values(value))
    elseif value isa AbstractVector
        foreach(require_public_metadata, value)
    elseif value isa AbstractString
        # Keep the web host as an ordinary word so its URL path stays relative
        # to it, while still checking punctuation-delimited diagnostic text.
        checked = replace(value, r"(?i)\bhttps?://[a-z0-9.-]+(?::[0-9]+)?" => "webhost")
        require(!occursin(r"(?i)file://|(?:\A|[\s\"'`=,:;([{])(?:/+[^/\s]|[a-z]:[\\/]|\\\\)", checked),
            "absolute operational path in generated public metadata")
    end
    return nothing
end

function require_public_attribution(item, original)
    lines = item["attribution_lines"]
    require(lines isa AbstractVector && all(line -> line isa AbstractString, lines) &&
        lines == original["attribution_lines"], "attribution text differs from the pinned inventory")
    checked = item
    if original["path"] == "05-sports/README.md"
        manual = "/05-sports/info/OrganizationITC2021_V7.pdf"
        url = "https://github.com/ZIB-AOPT/QOBLIB/blob/" * QOBLIB_COMMIT * manual
        checked = Dict{String,Any}(item)
        # The upstream Markdown link starts at the repository root.
        # Resolve just this pinned link for the scan and retain the original text.
        checked["attribution_lines"] = [replace(line, "($manual)" => "($url)") for line in lines]
    end
    return require_public_metadata(checked)
end

function released_public_projection(entry, audit, environment)
    audit_fields = ("schema", "auditor_sha256", "accepted", "passed", "original_validated",
        "full_metadata_validated", "case_id", "family", "auxiliary_row", "native_status",
        "source_snapshot_commit", "source_lp_path", "source_lp_compressed_sha256",
        "source_lp_decompressed_sha256", "case_manifest_sha256", "environment_sha256", "result_sha256")
    audit_public = Dict{String,Any}(k => audit[k] for k in audit_fields)
    audit_public["original"] = Dict(k => audit["original"][k] for k in ("n", "l", "m", "polynomial_sha256"))
    audit_public["metadata_document_audit"] = Dict(k => audit["metadata_document_audit"][k]
        for k in ("full_EOF_parsed", "target_dimension_matches", "bytes_parsed"))
    inventory = entry["audit_inventory_paths"]
    require(Set(keys(inventory)) == Set(RELEASED_AUDIT_ARTIFACT_KEYS),
        "unexpected keys in public audit inventory mapping")
    inventory_paths = Set(inventory[k] for k in RELEASED_AUDIT_ARTIFACT_KEYS)
    push!(inventory_paths, entry["raw_reformulation_metadata"]["path"])
    audit_public["inventory"] = [Dict(k => item[k] for k in ("path", "sha256", "bytes"))
        for item in audit["inventory"] if item["path"] in inventory_paths]
    sort!(audit_public["inventory"]; by = item -> item["path"])

    environment_fields = ("julia_version", "toqubo_commit", "release_identity_sha256",
        "project_sha256", "manifest_sha256", "registered_stack_verified",
        "package_source_is_official_release", "candidate_scope", "candidate_released")
    environment_public = Dict{String,Any}(k => environment[k] for k in environment_fields)
    environment_public["packages"] = Dict(name => Dict(k => environment["packages"][name][k]
        for k in ("version", "source_tree", "commit")) for name in RELEASED_OWNER_PACKAGES)
    projected = Dict("audit" => audit_public, "environment" => environment_public,
        "raw_sha256" => Dict(k => entry["artifacts"][k]["sha256"] for k in RELEASED_PRIVATE_KEYS))
    require_public_metadata(projected)
    return projected
end

# Stable order on JSON.jl 0.21 and 1.x, using their ordinary scalar encoders.
function write_sorted_json(io, value)
    if value isa AbstractDict
        print(io, '{')
        for (i, k) in enumerate(sort!(collect(keys(value))))
            i > 1 && print(io, ',')
            print(io, JSON.json(k), ':')
            write_sorted_json(io, value[k])
        end
        print(io, '}')
    elseif value isa AbstractVector
        print(io, '[')
        for (i, item) in enumerate(value)
            i > 1 && print(io, ',')
            write_sorted_json(io, item)
        end
        print(io, ']')
    else
        print(io, JSON.json(value))
    end
end

function write_released_public_evidence(root, models)
    path = joinpath(root, RELEASED_PUBLIC_EVIDENCE)
    require(!ispath(path) && !islink(path), "public released evidence already exists")
    open(path, "w") do io
        write_sorted_json(io, Dict("schema" => RELEASED_PUBLIC_SCHEMA, "models" => models))
        println(io)
    end
    return sha(path)
end

function read_released_public_evidence(root, manifest, expected_sha)
    path = relative_path(root, RELEASED_PUBLIC_EVIDENCE)
    require(sha256_text(expected_sha) && isfile(path) && 0 < filesize(path) <= 8 * 1024^2 &&
        sha(path) == expected_sha, "expected separately pinned public released provenance")
    content = JSON.parsefile(path)
    require(Set(keys(content)) == Set(("schema", "models")) && content["schema"] == RELEASED_PUBLIC_SCHEMA &&
        Set(keys(content["models"])) == Set(entry["case_id"] for entry in manifest["models"]),
        "public released provenance membership differs")
    require_public_metadata(content)
    return content["models"]
end
