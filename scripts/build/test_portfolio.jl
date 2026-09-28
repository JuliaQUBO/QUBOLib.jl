function test_qoblib_portfolio_positions()
    @testset "Canonical portfolio positions" begin
        mktempdir() do root
            group = QOBLIB_GROUPS[3]
            problem = "po_a002_t2_s00_b004_l1e-4"
            instance = mkpath(joinpath(root, "06-portfolio/instances/po_a002_t2_s00"))
            prices = joinpath(instance, "stock_prices.txt")
            # Deliberately nonalphabetical asset order and unequal positions.
            write(prices, "0 ZZZ 10\n0 AAA 20\n1 ZZZ 11\n1 AAA 21\n")
            text = """
            instance po_a002_t2_s00
            budget 4
            lambda 0.0001
            objective -17
            0 ZZZ 2 0 # two long units [-]
            1 AAA 0 1
            """
            read_positions(s = text, n = 46) =
                _qoblib_read_portfolio_solution(IOBuffer(s), root, problem, n)
            solution = read_positions()
            # x: asset/copy/direction/period; y and s2: bit/period.
            @test findall(==(1), solution.state) == [1, 5, 16, 26, 28, 31, 32, 34, 35, 36]
            @test length(solution.state) == 46
            @test solution.source_value == -17
            @test_throws ErrorException read_positions(text, 45)
            for (old, bad) in (
                ("instance po_a002_t2_s00", "instance po_a002_t2_orig"),
                ("budget 4", "budget 5"),
                ("lambda 0.0001", "lambda 0.001"),
                ("0 ZZZ 2 0", "0 NOPE 2 0"),
                ("0 ZZZ 2 0", "2 ZZZ 2 0"),
                ("0 ZZZ 2 0", "0 ZZZ 4 0"),
                ("0 ZZZ 2 0", "0 ZZZ -1 0"),
                ("0 ZZZ 2 0", "0 ZZZ 3 3"),
                ("objective -17", "objective NaN"),
            )
                @test_throws ErrorException read_positions(replace(text, old => bad))
            end
            @test_throws ErrorException read_positions(text * "0 ZZZ 0 1\n")
            @test_throws ErrorException read_positions(text * "budget 4\n")
            @test_throws ArgumentError read_positions(replace(text, "budget 4\n" => ""))
            @test ismissing(
                read_positions(replace(text, "objective -17\n" => "")).source_value,
            )
            @test _qoblib_solution_key(group, "uqo_a002_t2_s00_b004_l0.0001.qs") ==
                  _qoblib_submission_key(group, problem)

            solutions = mkpath(joinpath(root, group.solution_path, "nested"))
            path = joinpath(solutions, problem * ".opt.sol")
            write(path, text)
            indexed = _qoblib_solution_index(root, group)
            info = indexed[_qoblib_solution_key(group, problem)]
            @test info.path == path
            @test info.proven_optimal
            @test _qoblib_read_submission_solution(
                path,
                group,
                46;
                root_path = root,
                problem,
            ).state == solution.state

            # Exercise the archive extraction path, including compressed prices.
            run(`gzip -n $prices`)
            @test read_positions().state == solution.state
            for f in ("README.md", "LICENSE", "LICENSE.data")
                write(joinpath(root, f), "fixture\n")
            end
            models = mkpath(joinpath(root, group.path, "a002_t2_s00_b004"))
            modelpath = joinpath(models, "uqo_a002_t2_s00_b004_l1e-4.qs")
            write(modelpath, "# Vars Non-zeros\n46 2\n1 1 -1\n1 2 1\n")
            run(`xz $modelpath`)
            write(joinpath(root, group.path, "README.md"), "fixture\n")
            write(
                joinpath(root, group.path, "metrics.csv"),
                "file,num_variables,density,min_coeff,max_coeff\n" *
                "uqo_a002_t2_s00_b004_l0.0001.qs,46,$(2 / 1081),-1,1\n",
            )
            write(joinpath(root, group.solution_path, "README.md"), "fixture\n")
            mktempdir() do build_root
                zip_path = joinpath(build_root, "source.zip")
                run(Cmd(`zip -qr $zip_path $(basename(root))`; dir = dirname(root)))
                fixture_group =
                    merge(group, (; expected_count = 1, expected_incumbents = 1))
                QUBOLib.access(; path = build_root, clear = true) do index
                    build_qoblib!(index; source_path = zip_path, groups = (fixture_group,))
                    @test QUBOLib.collection_size(index, QOBLIB_COLLECTION) == 1
                    record = only(eachrow(QUBOLib.list_solution_records(index, 1)))
                    @test record[:source_value] == -17
                    @test record[:qubo_value] == -1
                    @test record[:proven_optimal] == true
                    @test haskey(QUBOLib.JSON.parse(record[:metadata]), "conversion")
                end
            end
        end
    end
end

function test_qoblib_submission_bit_formats()
    @testset "QOBLIB submission bit formats" begin
        @test _qoblib_read_solution(IOBuffer("0101"), :bit_tokens, 4).state == [0, 1, 0, 1]
        @test _qoblib_read_solution(IOBuffer("0 1\n0 1"), :bit_tokens, 4).state ==
              [0, 1, 0, 1]
        @test_throws QUBOTools.SyntaxError _qoblib_read_solution(IOBuffer("010"), :bit_tokens, 4)
        @test_throws QUBOTools.SyntaxError _qoblib_read_solution(IOBuffer("0121"), :bit_tokens, 4)
        mktempdir() do root
            path = joinpath(root, "solution.sol")
            group = QOBLIB_GROUPS[4]
            write(path, "1\n0\n1\n0\n")
            @test _qoblib_read_submission_solution(
                path,
                group,
                4;
                root_path = root,
                problem = "fixture",
            ).state == [1, 0, 1, 0]
            write(path, "1\n3\n")
            @test _qoblib_read_submission_solution(
                path,
                group,
                4;
                root_path = root,
                problem = "fixture",
            ).state == [1, 0, 1, 0]
            write(path, "1\n")
            @test _qoblib_read_submission_solution(
                path,
                group,
                4;
                root_path = root,
                problem = "fixture",
            ).state == [1, 0, 0, 0]
        end
    end
end
