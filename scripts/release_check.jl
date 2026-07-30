#!/usr/bin/env julia

using Pkg
using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))

function release_line_compat(version::VersionNumber)
    if version.major == 0
        return version.minor == 0 ? "0.0.$(version.patch)" : "0.$(version.minor)"
    end

    return string(version.major)
end

function check!(failures::Vector{String}, condition::Bool, message::String)
    condition || push!(failures, message)
    return nothing
end

function project_file(parts...)
    return joinpath(ROOT, parts...)
end

function read_toml(parts...)
    return TOML.parsefile(project_file(parts...))
end

function compat_entries(compat::AbstractString)
    return strip.(split(compat, ","))
end

function compat_allows(compat::AbstractString, version::VersionNumber)
    return version in Pkg.Types.semver_spec(compat)
end

function release_heading_matches(line::AbstractString, version::VersionNumber)
    prefix = "## v$(version)"
    startswith(line, prefix) || return false
    length(line) == length(prefix) && return true
    return line[length(prefix) + 1] in (' ', '-', '(')
end

function release_section(changelog::String, version::VersionNumber)
    lines = split(changelog, '\n')
    start = findfirst(line -> release_heading_matches(line, version), lines)
    start === nothing && return nothing

    next_heading = findnext(line -> startswith(line, "## "), lines, start + 1)
    stop = next_heading === nothing ? lastindex(lines) : next_heading - 1
    return join(lines[start:stop], "\n")
end

function is_lower_hex(value, expected_length::Integer)
    value isa AbstractString || return false
    ncodeunits(value) == expected_length || return false
    return occursin(Regex("^[0-9a-f]{$expected_length}\$"), value)
end

function artifact_data_tag(url::AbstractString)
    m = match(r"/releases/download/([^/]+)/qubolib\.tar\.gz$", url)
    return isnothing(m) ? nothing : only(m.captures)
end

function cff_scalar(contents::AbstractString, key::AbstractString)
    prefix = "$key:"

    for line in eachline(IOBuffer(contents))
        startswith(line, prefix) || continue
        value = strip(line[nextind(line, lastindex(key)+1):end])

        if ncodeunits(value) >= 2 &&
           first(value) == last(value) &&
           first(value) in ('"', '\'')
            return value[nextind(value, firstindex(value)):prevind(value, lastindex(value))]
        end

        return value
    end

    return nothing
end

function check_citation_metadata!(failures::Vector{String}, project_version::VersionNumber)
    path = project_file("CITATION.cff")
    check!(failures, isfile(path), "CITATION.cff is missing.")
    isfile(path) || return nothing

    contents = read(path, String)
    version = cff_scalar(contents, "version")
    date_released = cff_scalar(contents, "date-released")

    check!(
        failures,
        cff_scalar(contents, "cff-version") == "1.2.0",
        "CITATION.cff must use CFF schema version 1.2.0.",
    )
    check!(
        failures,
        cff_scalar(contents, "type") == "software",
        "CITATION.cff must identify QUBOLib as software.",
    )
    check!(
        failures,
        cff_scalar(contents, "license") == "MIT",
        "CITATION.cff must record the QUBOLib software license as MIT.",
    )
    check!(
        failures,
        version == string(project_version),
        "CITATION.cff version must match Project.toml version $project_version.",
    )
    check!(
        failures,
        date_released !== nothing && occursin(r"^\d{4}-\d{2}-\d{2}$", date_released),
        "CITATION.cff date-released must use YYYY-MM-DD.",
    )
    check!(
        failures,
        occursin(r"(?m)^preferred-citation:\s*$", contents),
        "CITATION.cff must provide a preferred citation.",
    )
    check!(
        failures,
        occursin(r"(?m)^  doi:\s*[\"']?10\.", contents),
        "CITATION.cff preferred citation must include a DOI.",
    )

    return nothing
end

function check_dataset_artifact!(
    failures::Vector{String},
    artifact::AbstractDict,
    qubolib::AbstractDict,
)
    downloads = get(qubolib, "download", Any[])
    check!(
        failures,
        downloads isa AbstractVector && length(downloads) == 1,
        "Artifacts.toml must contain exactly one qubolib download.",
    )

    if downloads isa AbstractVector && length(downloads) == 1
        download = only(downloads)
        url = get(download, "url", "")
        sha256 = get(download, "sha256", "")
        data_tag = url isa AbstractString ? artifact_data_tag(url) : nothing

        check!(
            failures,
            get(artifact, "asset_url", nothing) == url,
            "DATASET.toml artifact.asset_url must match Artifacts.toml.",
        )
        check!(
            failures,
            get(artifact, "sha256", nothing) == sha256,
            "DATASET.toml artifact.sha256 must match Artifacts.toml.",
        )
        check!(
            failures,
            get(artifact, "tag", nothing) == data_tag,
            "DATASET.toml artifact.tag must match the Artifacts.toml release URL.",
        )
    end

    check!(
        failures,
        get(artifact, "git_tree_sha1", nothing) == get(qubolib, "git-tree-sha1", nothing),
        "DATASET.toml artifact.git_tree_sha1 must match Artifacts.toml.",
    )
    check!(
        failures,
        is_lower_hex(get(artifact, "release_tag_commit", nothing), 40),
        "DATASET.toml artifact.release_tag_commit must be a lowercase 40-character SHA-1.",
    )
    check!(
        failures,
        is_lower_hex(get(artifact, "sha256", nothing), 64),
        "DATASET.toml artifact.sha256 must be a lowercase 64-character SHA-256.",
    )
    check!(
        failures,
        is_lower_hex(get(artifact, "git_tree_sha1", nothing), 40),
        "DATASET.toml artifact.git_tree_sha1 must be a lowercase 40-character SHA-1.",
    )

    asset_size_bytes = get(artifact, "asset_size_bytes", 0)
    inventory_observed_at = get(artifact, "inventory_observed_at", "")
    check!(
        failures,
        asset_size_bytes isa Integer && asset_size_bytes > 0,
        "DATASET.toml artifact.asset_size_bytes must be positive.",
    )
    check!(
        failures,
        get(artifact, "archive_members", Any[]) == ["archive.h5", "index.db"],
        "DATASET.toml artifact.archive_members must record archive.h5 and index.db.",
    )
    check!(
        failures,
        inventory_observed_at isa AbstractString &&
        occursin(r"^\d{4}-\d{2}-\d{2}$", inventory_observed_at),
        "DATASET.toml artifact.inventory_observed_at must use YYYY-MM-DD.",
    )

    return nothing
end

function check_dataset_collections!(
    failures::Vector{String},
    collections::AbstractVector,
    artifact::AbstractDict,
)
    check!(
        failures,
        !isempty(collections),
        "DATASET.toml must contain at least one collection.",
    )

    ids = String[]
    instance_count = 0
    all_provenance_verified = true
    all_rights_verified = true

    for collection in collections
        raw_id = get(collection, "id", "")
        id = raw_id isa AbstractString ? String(raw_id) : ""
        provenance_status = get(collection, "provenance_status", "")
        provenance_evidence_status =
            get(collection, "provenance_evidence_status", nothing)
        provenance_evidence_url = get(collection, "provenance_evidence_url", nothing)
        rights_status = get(collection, "rights_status", "")
        rights_evidence_status = get(collection, "rights_evidence_status", nothing)
        instances = get(collection, "instances", 0)
        citation_doi = get(collection, "citation_doi", "")

        push!(ids, id)
        instance_count += instances isa Integer ? instances : 0
        all_provenance_verified &= provenance_status == "verified"
        all_rights_verified &= rights_status == "verified"

        check!(failures, !isempty(id), "Every DATASET.toml collection needs an id.")
        check!(
            failures,
            instances isa Integer && instances > 0,
            "Collection '$id' must record a positive instance count.",
        )
        check!(
            failures,
            provenance_status in ("partial", "verified"),
            "Collection '$id' has an invalid provenance_status.",
        )
        if !isnothing(provenance_evidence_status)
            check!(
                failures,
                provenance_evidence_status == "verified-public-evidence",
                "Collection '$id' has an invalid provenance_evidence_status.",
            )
        end
        check!(
            failures,
            rights_status in ("pending", "verified"),
            "Collection '$id' has an invalid rights_status.",
        )
        if !isnothing(rights_evidence_status)
            check!(
                failures,
                rights_evidence_status in
                ("preliminary-private-correspondence", "verified-public-evidence"),
                "Collection '$id' has an invalid rights_evidence_status.",
            )
        end
        check!(
            failures,
            citation_doi isa AbstractString && occursin(r"^10\.", citation_doi),
            "Collection '$id' must record a citation DOI.",
        )

        if rights_status == "verified"
            check!(
                failures,
                haskey(collection, "data_license"),
                "Collection '$id' has verified rights but no data_license.",
            )
            check!(
                failures,
                haskey(collection, "license_evidence_url"),
                "Collection '$id' has verified rights but no license evidence URL.",
            )
        end

        if provenance_status == "verified"
            has_source_commit =
                haskey(collection, "source_commit") &&
                is_lower_hex(collection["source_commit"], 40)
            has_public_evidence =
                provenance_evidence_status == "verified-public-evidence" &&
                provenance_evidence_url isa AbstractString &&
                startswith(provenance_evidence_url, "https://")
            check!(
                failures,
                has_source_commit || has_public_evidence,
                "Collection '$id' has verified provenance but neither a valid source commit nor verified public evidence.",
            )
        end

        if haskey(collection, "mirror_sha256")
            check!(
                failures,
                is_lower_hex(collection["mirror_sha256"], 64),
                "Collection '$id' has an invalid mirror SHA-256.",
            )
        end
    end

    check!(
        failures,
        length(ids) == length(unique(ids)),
        "DATASET.toml collection ids must be unique.",
    )
    check!(
        failures,
        length(ids) == get(artifact, "populated_collections", nothing),
        "DATASET.toml collection count must match artifact.populated_collections.",
    )
    check!(
        failures,
        instance_count == get(artifact, "instances", nothing),
        "DATASET.toml collection instances must sum to artifact.instances.",
    )

    return (
        all_provenance_verified = all_provenance_verified,
        all_rights_verified = all_rights_verified,
    )
end

function check_zenodo_metadata!(
    failures::Vector{String},
    warnings::Vector{String},
    zenodo::AbstractDict,
    collection_state;
    require_publishable::Bool = false,
)
    status = get(zenodo, "status", "")
    manager_access_status = get(zenodo, "manager_access_status", "")
    byte_identity_status = get(zenodo, "byte_identity_status", "")
    related_identifiers_status = get(zenodo, "related_identifiers_status", "")
    active_managers = get(zenodo, "active_manager_count", 0)
    required_managers = get(zenodo, "required_active_managers", 0)
    blocking_reasons = get(zenodo, "blocking_reasons", Any[])

    check!(
        failures,
        status in ("blocked", "ready", "published"),
        "DATASET.toml zenodo.status must be blocked, ready, or published.",
    )
    check!(
        failures,
        get(zenodo, "license_model", "") == "per-collection",
        "DATASET.toml zenodo.license_model must remain per-collection.",
    )
    check!(
        failures,
        manager_access_status in ("not-recorded", "verified"),
        "DATASET.toml zenodo.manager_access_status is invalid.",
    )
    check!(
        failures,
        byte_identity_status in ("not-verified", "verified"),
        "DATASET.toml zenodo.byte_identity_status is invalid.",
    )
    check!(
        failures,
        related_identifiers_status in ("not-recorded", "verified"),
        "DATASET.toml zenodo.related_identifiers_status is invalid.",
    )
    check!(
        failures,
        active_managers isa Integer && active_managers >= 0,
        "DATASET.toml zenodo.active_manager_count must be a non-negative integer.",
    )
    check!(
        failures,
        required_managers isa Integer && required_managers >= 2,
        "DATASET.toml zenodo.required_active_managers must be at least 2.",
    )
    check!(
        failures,
        blocking_reasons isa AbstractVector,
        "DATASET.toml zenodo.blocking_reasons must be an array.",
    )

    if status == "blocked"
        push!(
            warnings,
            "Dataset publication remains blocked; see DATASET.toml zenodo.blocking_reasons.",
        )
        check!(
            failures,
            blocking_reasons isa AbstractVector && !isempty(blocking_reasons),
            "A blocked dataset must record at least one blocking reason.",
        )
    else
        check!(
            failures,
            blocking_reasons isa AbstractVector && isempty(blocking_reasons),
            "A ready or published dataset cannot retain blocking_reasons.",
        )
    end

    if status in ("ready", "published") || require_publishable
        check!(
            failures,
            collection_state.all_provenance_verified,
            "A ready or published dataset requires verified provenance for every collection.",
        )
        check!(
            failures,
            collection_state.all_rights_verified,
            "A ready or published dataset requires verified redistribution rights for every collection.",
        )
        check!(
            failures,
            manager_access_status == "verified",
            "A ready or published dataset requires verified Zenodo manager access.",
        )
        check!(
            failures,
            active_managers isa Integer &&
            required_managers isa Integer &&
            active_managers >= required_managers,
            "A ready or published dataset requires at least the recorded number of active managers.",
        )
        check!(
            failures,
            related_identifiers_status == "verified",
            "A ready or published dataset requires verified related identifiers.",
        )
        check!(
            failures,
            byte_identity_status == "verified",
            "A ready or published dataset requires verified byte identity.",
        )
    end

    if require_publishable
        check!(
            failures,
            status in ("ready", "published"),
            "Dataset publication requires zenodo.status to be ready or published.",
        )
    end

    if status == "published"
        check!(
            failures,
            haskey(zenodo, "concept_doi") && haskey(zenodo, "version_doi"),
            "A published dataset must record both concept and version DOIs.",
        )

        for key in ("concept_doi", "version_doi")
            if haskey(zenodo, key)
                value = zenodo[key]
                check!(
                    failures,
                    value isa AbstractString && occursin(r"^10\.", value),
                    "A published dataset must record a valid $key.",
                )
            end
        end
    end

    return nothing
end

function check_dataset_metadata!(
    failures::Vector{String},
    warnings::Vector{String};
    require_publishable::Bool = false,
)
    dataset_path = project_file("DATASET.toml")
    check!(failures, isfile(dataset_path), "DATASET.toml is missing.")
    isfile(dataset_path) || return nothing

    dataset = TOML.parsefile(dataset_path)
    artifacts = read_toml("Artifacts.toml")
    artifact = get(dataset, "artifact", Dict{String,Any}())
    zenodo = get(dataset, "zenodo", Dict{String,Any}())
    collections = get(dataset, "collections", Any[])

    check!(
        failures,
        get(dataset, "schema_version", nothing) == 1,
        "DATASET.toml schema_version must be 1.",
    )
    check!(
        failures,
        artifact isa AbstractDict,
        "DATASET.toml must contain an artifact table.",
    )
    check!(
        failures,
        zenodo isa AbstractDict,
        "DATASET.toml must contain a zenodo table.",
    )
    check!(
        failures,
        collections isa AbstractVector,
        "DATASET.toml collections must be an array of tables.",
    )

    artifact isa AbstractDict || return nothing
    qubolib = get(artifacts, "qubolib", Dict{String,Any}())
    check_dataset_artifact!(failures, artifact, qubolib)

    collection_state = if collections isa AbstractVector
        check_dataset_collections!(failures, collections, artifact)
    else
        (all_provenance_verified = false, all_rights_verified = false)
    end

    if zenodo isa AbstractDict
        check_zenodo_metadata!(
            failures,
            warnings,
            zenodo,
            collection_state;
            require_publishable,
        )
    end

    return nothing
end

function main()
    failures = String[]
    warnings = String[]
    require_dataset_publishable = "--require-dataset-publishable" in ARGS
    unknown_args = filter(!=("--require-dataset-publishable"), ARGS)

    check!(
        failures,
        isempty(unknown_args),
        "Unknown release-check argument(s): $(join(unknown_args, ", ")).",
    )

    project = read_toml("Project.toml")
    docs_project = read_toml("docs", "Project.toml")
    test_project = read_toml("test", "Project.toml")

    version = VersionNumber(project["version"])
    expected_self_compat = release_line_compat(version)

    check!(failures, project["name"] == "QUBOLib", "Project.toml name is not QUBOLib.")

    root_deps = project["deps"]
    docs_deps = docs_project["deps"]
    test_deps = test_project["deps"]
    root_compat = project["compat"]
    docs_compat = docs_project["compat"]
    docs_self_compat = get(docs_compat, "QUBOLib", nothing)

    check!(
        failures,
        get(docs_deps, "QUBOLib", nothing) == project["uuid"],
        "docs/Project.toml must depend on this package UUID for QUBOLib.",
    )
    check!(
        failures,
        docs_self_compat !== nothing,
        "docs/Project.toml must declare QUBOLib compat.",
    )

    if docs_self_compat !== nothing
        check!(
            failures,
            expected_self_compat in compat_entries(docs_self_compat),
            "docs/Project.toml compat for QUBOLib must include \"$expected_self_compat\" for version $version.",
        )
        check!(
            failures,
            compat_allows(docs_self_compat, version),
            "docs/Project.toml compat for QUBOLib must allow version $version.",
        )
    end

    check!(
        failures,
        get(docs_compat, "QUBOTools", nothing) == root_compat["QUBOTools"],
        "docs/Project.toml QUBOTools compat must match Project.toml.",
    )
    check!(
        failures,
        get(docs_compat, "SQLite", nothing) == root_compat["SQLite"],
        "docs/Project.toml SQLite compat must match Project.toml.",
    )
    check!(
        failures,
        get(docs_deps, "QUBOTools", nothing) == root_deps["QUBOTools"],
        "docs/Project.toml QUBOTools UUID must match Project.toml.",
    )
    check!(
        failures,
        get(test_deps, "QUBOTools", nothing) == root_deps["QUBOTools"],
        "test/Project.toml QUBOTools UUID must match Project.toml.",
    )
    check!(
        failures,
        haskey(root_compat, "julia"),
        "Project.toml must declare Julia compat.",
    )

    changelog = read(project_file("CHANGELOG.md"), String)
    section = release_section(changelog, version)
    check!(
        failures,
        section !== nothing,
        "CHANGELOG.md must contain a release heading for v$version.",
    )

    if section !== nothing &&
       version.major == 0 &&
       iszero(version.patch) &&
       !occursin(r"(?i)\b(breaking|changelog)\b", section)
        push!(
            warnings,
            "CHANGELOG.md section for v$version does not mention `breaking` or `changelog`; General AutoMerge may require one of those words if the registry labels the release BREAKING.",
        )
    end

    check_citation_metadata!(failures, version)
    check_dataset_metadata!(
        failures,
        warnings;
        require_publishable = require_dataset_publishable,
    )

    if isempty(failures)
        println("Release preflight passed for QUBOLib v$version.")
        println("Expected docs self-compat entry: QUBOLib = \"$expected_self_compat\".")
    else
        println(stderr, "Release preflight failed:")
        foreach(message -> println(stderr, "- ", message), failures)
    end

    if !isempty(warnings)
        println(stderr, "\nWarnings:")
        foreach(message -> println(stderr, "- ", message), warnings)
    end

    return isempty(failures) ? 0 : 1
end

exit(main())
