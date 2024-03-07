const ARXIV_1903_10928_5R5X_URL = "https://sites.usc.edu/itayhen/files/2019/09/5r5x.zip"

function _load_arXiv_1903_10928_5r5x!()
    @info "[arXiv_1903_10928_5r5x] Downloading instances"

    arXiv_1903_10928_5r5x_cache_path = mkpath(abspath(QUBOLib.cache_path(), "arXiv_1903_10928_5r5x"))
    arXiv_1903_10928_5r5x_data_path  = mkpath(abspath(arXiv_1903_10928_5r5x_cache_path, "data"))
    arXiv_1903_10928_5r5x_zip_path   = abspath(arXiv_1903_10928_5r5x_cache_path, "arXiv_1903_10928_5r5x.zip")

    # Download arXiv_1903_10928 5r5x archive
    if isfile(arXiv_1903_10928_5r5x_zip_path)
        @info "[arXiv_1903_10928_5r5x] Archive already downloaded"
    else
        @info "[arXiv_1903_10928_5r5x] Downloading archive"
        Downloads.download(ARXIV_1903_10928_5R5X_URL, arXiv_1903_10928_5r5x_zip_path)
    end

    # Extract arXiv_1903_10928 5r5x archive
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QPLIB archive"

    @info "[arXiv_1903_10928_5r5x] Extracting archive"

    run(```
        unzip -qq -o -j 
            $arXiv_1903_10928_5r5x_zip_path
            'instance*.txt'
            -d $arXiv_1903_10928_5r5x_data_path
        ```)

    return nothing
end

function build_arXiv_1903_10928_5r5x!(index::LibraryIndex; cache::Bool = true)
    if QUBOLib.has_collection(index, :arXiv_1903_10928_5r5x)
        @info "[arXiv_1903_10928_5r5x] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, :arXiv_1903_10928_5r5x)
        end
    end

    QUBOLib.add_collection!(
        index,
        :arXiv_1903_10928_5r5x,
        Dict{String,Any}(
            "name"        => "arXiv_1903_10928_5r5x",
            "title"       => "5R5X instances for \"Equation Planting: A Tool for Benchmarking Ising Machines\"",
            "author"      => ["Itay Hen"],
            "description" => "The Quadratic Programming Library",
            "year"        => 2019,
            "url"         => ARXIV_1903_10928_5R5X_URL,
        ),
    )

    _load_arXiv_1903_10928_5r5x!()

    arXiv_1903_10928_5r5x_data_path = abspath(QUBOLib.cache_path(), "arXiv_1903_10928_5r5x", "data")

    @info "[arXiv_1903_10928_5r5x] Building index"

    for path in readdir(arXiv_1903_10928_5r5x_data_path; join=true)
        model = QUBOTools.read_model(path, QUBOTools.Qubist())
        mod_i = QUBOLib.add_instance!(index, :arXiv_1903_10928_5r5x, model)

        if isnothing(mod_i)
            @warn "[arXiv_1903_10928_5r5x] Failed to read instance '$path'"
        end
    end

    return nothing
end
