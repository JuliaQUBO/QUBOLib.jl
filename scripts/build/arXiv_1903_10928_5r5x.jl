const ARXIV_1903_10928_5R5X_URL = "https://sites.usc.edu/itayhen/files/2019/09/5r5x.zip"

function load_arXiv_1903_10928_5r5x!(index::QUBOLib.LibraryIndex)
    @info "[arXiv_1903_10928_5r5x] Downloading instances"

    _cache_path = mkpath(abspath(QUBOLib.cache_path(index; create = true), "arXiv-1903-10928-5r5x"))
    _data_path  = mkpath(abspath(_cache_path, "data"))
    _zip_path   = abspath(_cache_path, "arXiv_1903_10928_5r5x.zip")

    # Download arXiv_1903_10928 5r5x archive
    if isfile(_zip_path)
        @info "[arXiv_1903_10928_5r5x] Archive already downloaded"
    else
        @info "[arXiv_1903_10928_5r5x] Downloading archive"

        Downloads.download(ARXIV_1903_10928_5R5X_URL, _zip_path)
    end

    # Extract arXiv_1903_10928 5r5x archive
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QPLIB archive"

    @info "[arXiv_1903_10928_5r5x] Extracting archive"

    run(```
        unzip -qq -o -j 
            $_zip_path
            'instance*.txt'
            -d $_data_path
        ```)

    return nothing
end

function build_arXiv_1903_10928_5r5x!(index::QUBOLib.LibraryIndex; cache::Bool = true)
    if QUBOLib.has_collection(index, "arXiv-1903-10928-5r5x")
        @info "[arXiv_1903_10928_5r5x] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, "arXiv-1903-10928-5r5x")
        end
    end

    QUBOLib.add_collection!(
        index,
        "arXiv-1903-10928-5r5x",
        Dict{String,Any}(
            "name"        => "5-Regular 5-XORSAT (arXiv:1903.10928)",
            "author"      => ["Itay Hen"],
            "description" => "5R5X instances for \"Equation Planting: A Tool for Benchmarking Ising Machines\"",
            "year"        => 2019,
            "url"         => ARXIV_1903_10928_5R5X_URL,
        ),
    )

    load_arXiv_1903_10928_5r5x!(index)

    _data_path = abspath(
        QUBOLib.cache_path(index),
        "arXiv-1903-10928-5r5x",
        "data",
    )

    @info "[arXiv_1903_10928_5r5x] Building index"

    for path in readdir(_data_path; join = true)
        model = QUBOTools.read_model(path, QUBOTools.Qubist())
        mod_i = QUBOLib.add_instance!(index, model, "arXiv-1903-10928-5r5x")

        if isnothing(mod_i)
            @warn "[arXiv_1903_10928_5r5x] Failed to read instance '$path'"
        end
    end

    return nothing
end
