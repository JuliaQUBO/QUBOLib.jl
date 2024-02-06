function access(callback::Function)
    io = load_index()

    try
        return callback(io)
    catch e
        close(io)

        rethrow(e)
    end
end
