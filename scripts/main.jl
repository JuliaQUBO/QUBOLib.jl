using ArgParse
using QUBOLib

include("build/build.jl")
# include("deploy/deploy.jl")
# include("run/run.jl")

"""
"""
function main()
    main_settings = ArgParseSettings()

    @add_arg_table! main_settings begin
        "build"
            help   = "an option with an argument"
            action = :command
        "run"
            help   = "another option"
            action = :command
        "clear"
            help   = "clears current QUBOLib instance"
            action = :command
        "deploy"
            help   = "Deploys current state to target"
            action = :command
    end

    QUBOLib.logo()

    args = parse_args(main_settings; as_symbols = true)

    let cmd = args[:_COMMAND_]
        @show cmd_args = args[cmd]
        
        return nothing

        if cmd === :clear
            QUBOLib.clear(cmd_args...)
        elseif cmd === :build
            QUBOLib.build(cmd_args...)
        elseif cmd === :run
            QUBOLib.run(cmd_args...)
        elseif cmd ===:deploy
            QUBOLib.deploy(cmd_args...)
        end
    end

    return nothing
end

main() # Here we go!
