function _tag!(; verbose=true)
    filepath = joinpath(path, "latest.txt")

    if isfile(filepath)
        text = read(filepath, String)

        m = match(r"tag:\s*v(.*)", text)

        if isnothing(m)
            error("Tag not found in 'latest.txt'")
        end

        latest_tag = parse(VersionNumber, m[1])

        verbose && @show "Latest tag: $latest_tag"

        tagpath = joinpath(path, "tag.txt")

        new_tag = VersionNumber(
            latest_tag.major,
            latest_tag.minor,
            latest_tag.patch + 1,
            latest_tag.prerelease,
            latest_tag.build,
        )

        verbose && @show "New tag: $new_tag"

        write(tagpath, "v$new_tag")
    else
        error("File 'latest.txt' not found")
    end

    return nothing
end
