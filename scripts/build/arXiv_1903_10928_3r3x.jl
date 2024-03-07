const ARXIV_1903_10928_3R3X_URL = "https://sites.usc.edu/itayhen/files/2019/09/3r3x.zip"

function _load_arXiv_1903_10928_3r3x!()
    @info "[arXiv_1903_10928_3r3x] Downloading instances"

    arXiv_1903_10928_3r3x_cache_path = mkpath(abspath(QUBOLib.cache_path(), "arXiv_1903_10928_3r3x"))
    arXiv_1903_10928_3r3x_data_path  = mkpath(abspath(arXiv_1903_10928_3r3x_cache_path, "data"))
    arXiv_1903_10928_3r3x_zip_path   = abspath(arXiv_1903_10928_3r3x_cache_path, "arXiv_1903_10928_3r3x.zip")

    # Download arXiv_1903_10928 3r3x archive
    if isfile(arXiv_1903_10928_3r3x_zip_path)
        @info "[arXiv_1903_10928_3r3x] Archive already downloaded"
    else
        @info "[arXiv_1903_10928_3r3x] Downloading archive"
        Downloads.download(ARXIV_1903_10928_5R5X_URL, arXiv_1903_10928_3r3x_zip_path)
    end

    # Extract arXiv_1903_10928 3r3x archive
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QPLIB archive"

    @info "[arXiv_1903_10928_3r3x] Extracting archive"

    run(```
        unzip -qq -o -j 
            $arXiv_1903_10928_3r3x_zip_path
            'instance*.txt'
            -d $arXiv_1903_10928_3r3x_data_path
        ```)

    return nothing
end

function build_arXiv_1903_10928_3r3x!(index::LibraryIndex; cache::Bool = true)
    if QUBOLib.has_collection(index, :arXiv_1903_10928_3r3x)
        @info "[arXiv_1903_10928_3r3x] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, :arXiv_1903_10928_3r3x)
        end
    end

    QUBOLib.add_collection!(
        index,
        :arXiv_1903_10928_3r3x,
        Dict{String,Any}(
            "name"        => "arXiv_1903_10928_3r3x",
            "title"       => "5R5X instances for \"Equation Planting: A Tool for Benchmarking Ising Machines\"",
            "author"      => ["Itay Hen"],
            "description" => "The Quadratic Programming Library",
            "year"        => 2019,
            "url"         => ARXIV_1903_10928_5R5X_URL,
        ),
    )

    _load_arXiv_1903_10928_3r3x!()

    arXiv_1903_10928_3r3x_data_path = abspath(QUBOLib.cache_path(), "arXiv_1903_10928_3r3x", "data")

    @info "[arXiv_1903_10928_3r3x] Building index"

    for path in readdir(arXiv_1903_10928_3r3x_data_path; join=true)
        model = QUBOTools.read_model(path, QUBOTools.Qubist())
        mod_i = QUBOLib.add_instance!(index, :arXiv_1903_10928_3r3x, model)

        if isnothing(mod_i)
            @warn "[arXiv_1903_10928_3r3x] Failed to read instance '$path'"
        end
    end

    return nothing
end
