function _tag!(path::AbstractString; verbose::Bool = false)
    file_path = joinpath(path, "last.txt")

    if isfile(file_path)
        text = read(file_path, String)

        m = match(r"tag:\s*v(.*)", text)

        if isnothing(m)
            @error("Tag not found in 'last.txt'")

            exit(1)
        end

        last_tag = parse(VersionNumber, m[1])

        verbose && @info "Last tag: $last_tag"

        next_tag_path = joinpath(path, "next.tag")

        next_tag = VersionNumber(
            last_tag.major,
            last_tag.minor,
            last_tag.patch + 1,
            last_tag.prerelease,
            last_tag.build,
        )

        verbose && @info "Next tag: $next_tag"

        write(next_tag_path, "v$next_tag")
    else
        error("File 'last.txt' not found")
    end

    return nothing
end
