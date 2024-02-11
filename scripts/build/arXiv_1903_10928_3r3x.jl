function build_arXiv_1903_10928_3r3x!(index::LibraryIndex)
    QUBOLib.add_collection!(
        index,
        :arXiv_1903_10928_3r3x,
        Dict{String,Any}(
            "name" => "arXiv:1903_10928",
            "url"  => "http://qplib.zib.de/",
        ),
    )

    @info "[arXiv_1903_10928_3r3x] Building index"

    return nothing
end
