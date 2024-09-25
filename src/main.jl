"""
"""
function main()
    settings = ArgParseSettings()

    @add_arg_table! settings begin
        "build"
            action = :command
            help   = "an option with an argument"
        "clear"
            action = :command
            help   = "Clears current QUBOLib"
        "deploy"
            action = :command
            help   = "Deploys current state to target"
        "generate"
            action = :command
            help   = "Generates instances for a given problem"
        "run"
            action = :command
            help   = "another option"
    end

    @add_arg_table! settings["build"] begin
        "--source"
            default = nothing
            help    = "Selects data sources to build"
    end

    @add_arg_table! settings["deploy"] begin
        "--target"
            default = nothing
            help    = "Defines deployment target"
    end

    QUBOLib.print_logo()

    args = parse_args(settings; as_symbols = true)

    let cmd = args[:_COMMAND_]
        if cmd === :clear
            QUBOLib.clear(cmd_args)
        elseif cmd === :build
            QUBOLib.build(cmd_args)
        elseif cmd === :run
            QUBOLib.run(cmd_args)
        elseif cmd ===:deploy
            QUBOLib.deploy(cmd_args)
        end
    end

    return nothing
end
