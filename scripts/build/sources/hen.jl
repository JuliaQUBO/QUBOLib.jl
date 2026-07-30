const HEN_MIRROR_URLS = Dict(
    "arXiv-1903-10928-3r3x" => "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/data-mirror/arXiv-1903-10928-3r3x.zip",
    "arXiv-1903-10928-5r5x" => "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/data-mirror/arXiv-1903-10928-5r5x.zip",
    "arXiv-2103-08464-3r3x" => "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/data-mirror/arXiv-2103-08464-3r3x.zip",
)

const HEN_MIRROR_SHA256 = Dict(
    "arXiv-1903-10928-3r3x" => "a1b13f38112276f010e5559868eeeb3816b43b5c6753d1f44d49acb910ad13b0",
    "arXiv-1903-10928-5r5x" => "da773fab84c4e6e621efdf090a2fda9fa43420be4c2f2010a6d8fe88b1f34045",
    "arXiv-2103-08464-3r3x" => "a99b22c02aac03446589b7d366354bc448e6a8bae3e67120ac4bcc821601735b",
)

const HEN_LICENSE_GRANT_URL =
    "https://github.com/JuliaQUBO/QUBOLib.jl/issues/70#issuecomment-5132166520"

function _hen_verified_collection_metadata(code::AbstractString, citation_doi::AbstractString)
    return Dict{String,Any}(
        "citation_doi"               => citation_doi,
        "mirror_url"                 => HEN_MIRROR_URLS[code],
        "mirror_sha256"              => HEN_MIRROR_SHA256[code],
        "provenance_status"          => "verified",
        "provenance_evidence_status" => "verified-public-evidence",
        "provenance_evidence_url"    => HEN_LICENSE_GRANT_URL,
        "rights_status"              => "verified",
        "rights_evidence_status"     => "verified-public-evidence",
        "license_evidence_url"       => HEN_LICENSE_GRANT_URL,
        "rights_note"                => "Itay Hen confirms that he owns or is authorized by all applicable rights holders to license the named archive under CC BY 4.0 and authorizes QUBOLib hosting, redistribution, conversion, packaging, GitHub Releases, and Zenodo.",
        "transformation_note"        => "QUBOLib parses the Qubist source files and stores the converted models in the artifact's HDF5/SQLite representation.",
    )
end

const HEN_DATA = Dict(
    "arXiv-1903-10928-3r3x" => Dict(
        :url           => HEN_MIRROR_URLS["arXiv-1903-10928-3r3x"],
        :mirror_sha256 => HEN_MIRROR_SHA256["arXiv-1903-10928-3r3x"],
        :data          => Dict{String,Any}(
            "name"         => "3-Regular 3-XORSAT (arXiv:1903.10928)",
            "author"       => ["Itay Hen"],
            "description"  => "3R3X instances for 'Equation Planting: A Tool for Benchmarking Ising Machines'",
            "year"         => 2019,
            "url"          => "https://arxiv.org/abs/1903.10928",
            "citation"     => "https://doi.org/10.1103/PhysRevApplied.12.011003",
            "data_license" => "CC-BY-4.0",
            "metadata"     => _hen_verified_collection_metadata(
                "arXiv-1903-10928-3r3x",
                "10.1103/PhysRevApplied.12.011003",
            ),
        ),
    ),
    "arXiv-1903-10928-5r5x" => Dict(
        :url           => HEN_MIRROR_URLS["arXiv-1903-10928-5r5x"],
        :mirror_sha256 => HEN_MIRROR_SHA256["arXiv-1903-10928-5r5x"],
        :data          => Dict{String,Any}(
            "name"         => "5-Regular 5-XORSAT (arXiv:1903.10928)",
            "author"       => ["Itay Hen"],
            "description"  => "5R5X instances for 'Equation Planting: A Tool for Benchmarking Ising Machines'",
            "year"         => 2019,
            "url"          => "https://arxiv.org/abs/1903.10928",
            "citation"     => "https://doi.org/10.1103/PhysRevApplied.12.011003",
            "data_license" => "CC-BY-4.0",
            "metadata"     => _hen_verified_collection_metadata(
                "arXiv-1903-10928-5r5x",
                "10.1103/PhysRevApplied.12.011003",
            ),
        ),
    ),
    "arXiv-2103-08464-3r3x" => Dict(
        :url           => HEN_MIRROR_URLS["arXiv-2103-08464-3r3x"],
        :mirror_sha256 => HEN_MIRROR_SHA256["arXiv-2103-08464-3r3x"],
        :data          => Dict{String,Any}(
            "name"         => "3-Regular 3-XORSAT (arXiv:2103.08464)",
            "author"       => ["Matthew Kowalsky", "Tameem Albash", "Itay Hen", "Daniel A. Lidar"],
            "description"  => "3R3X instances for '3-Regular 3-XORSAT Planted Solutions Benchmark of Classical and Quantum Heuristic Optimizers'",
            "year"         => 2021,
            "url"          => "https://arxiv.org/abs/2103.08464",
            "citation"     => "https://doi.org/10.1088/2058-9565/ac4d1b",
            "data_license" => "CC-BY-4.0",
            "metadata"     => _hen_verified_collection_metadata(
                "arXiv-2103-08464-3r3x",
                "10.1088/2058-9565/ac4d1b",
            ),
        ),
    ),
)

function _hen_qubist_format()
    if isdefined(QUBOTools, :Qubist)
        return getfield(QUBOTools, :Qubist)()
    else
        return QUBOTools.Format{:qubist}()
    end
end

function load_hen!(index::QUBOLib.LibraryIndex, code::AbstractString)
    @info "[$code] Downloading instances"

    data_path = mkpath(QUBOLib.cache_data_path(index, code))
    file_path = QUBOLib.cache_path(index, code, "$code.zip")

    # Download arXiv_2103_08464 3r3x archive
    if isfile(file_path)
        @info "[$code] Archive already downloaded"
    else
        @info "[$code] Downloading archive"

        Downloads.download(HEN_DATA[code][:url], file_path)
    end

    # Extract arXiv_2103_08464 3r3x archive
    @assert success(`which unzip`) "'unzip' is required to extract QPLIB archive"

    @info "[$code] Extracting archive"

    run(`unzip -qq -o -j $file_path '*.txt' -d $data_path`)

    patch_hen!(index, code)

    return nothing
end

function build_hen!(index::QUBOLib.LibraryIndex; cache::Bool = true)
    for code in keys(HEN_DATA)
        build_hen!(index, code; cache)
    end

    return nothing
end

function build_hen!(index::QUBOLib.LibraryIndex, code::AbstractString; cache::Bool = true)
    if QUBOLib.has_collection(index, code)
        @info "[$code] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, code)
        end
    end

    load_hen!(index, code)

    @info "[$code] Building index"

    QUBOLib.add_collection!(index, code, HEN_DATA[code][:data])

    data_path = QUBOLib.cache_data_path(index, code)

    for path in readdir(data_path; join = true)
        model = try
            QUBOTools.read_model(path, _hen_qubist_format())
        catch e
            if e isa QUBOTools.SyntaxError
                @warn """
                [$code] Failed to read instance @ '$path':
                $(sprint(showerror, e))
                """

                continue
            else
                rethrow(e)
            end
        end

        mod_i = QUBOLib.add_instance!(index, model, code; name = basename(path))

        if isnothing(mod_i)
            @warn "[$code] Failed to read instance @ '$path'"
        end
    end

    return nothing
end

function patch_hen!(index::QUBOLib.LibraryIndex, code::AbstractString)
    @info "[$code] Applying patches"

    if code == "arXiv-1903-10928-5r5x"
        let path = abspath(QUBOLib.cache_data_path(index, code), "._instance_5r5x_n24_s265.txt")
            @info "[$code] Removing '$path'"

            rm(path; force = true)
        end
    elseif code == "arXiv-1903-10928-3r3x"
        let path = abspath(QUBOLib.cache_data_path(index, code), "instance_3r3x_n35_s2301.txt")
            @info "[$code] Removing '$path'"

            rm(path; force = true)
        end
    end

    return nothing
end

function deploy_hen!(index::QUBOLib.LibraryIndex)
    close(index)

    for code in keys(HEN_DATA)
        src_path = QUBOLib.cache_data_path(index, code)
        dst_path = mkpath(joinpath(QUBOLib.build_path(index), "mirror"))
        zip_path = joinpath(dst_path, "$code.zip")

        run(`zip -q -j -r $zip_path $src_path`)
    end

    return nothing
end
