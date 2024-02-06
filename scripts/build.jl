using QUBOLib

function main()
    QUBOLib.logo()
    QUBOLib.build(QUBOLib.root_path(); clear_cache=("--clear_cache" ∈ ARGS))

    return nothing
end

main() # Here we go!
