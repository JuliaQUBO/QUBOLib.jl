function access(callback::Function)
    io = Index()

    try
        return callback(io)
    catch e
        close(io)

        rethrow(e)
    end
end
