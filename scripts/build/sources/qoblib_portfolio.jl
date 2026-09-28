# Canonical positions replace solver-specific bitstrings at the pinned QOBLIB
# snapshot. Reconstruct the u3_c10 encoding documented in upstream
# 06-portfolio/check/README.md and parameter_u3_c10.zpl. Positions and binary
# slack values are dimensionless; the reported objective remains provenance.
function _qoblib_portfolio_layout(root_path::AbstractString, problem::AbstractString)
    name = replace(_qoblib_qs_stem(problem), r"^(uqo_|po_)" => "")
    variant = match(r"^(a([0-9]+)_t([0-9]+)_(?:orig|s[0-9]+))_b([0-9]+)_l([^_]+)$", name)
    isnothing(variant) && error("[qoblib] Unsupported portfolio model '$problem'")
    instance, assets, periods, budget, risk = variant.captures
    n_assets, n_periods = parse(Int, assets), parse(Int, periods)
    directory = joinpath(root_path, "06-portfolio", "instances", "po_$instance")
    path = joinpath(directory, "stock_prices.txt")
    text = if isfile(path)
        read(path, String)
    else
        read(`gzip -cd $(path * ".gz")`, String)
    end
    symbols = String[]
    times = Set{Int}()
    for raw_line in eachsplit(text, '\n')
        line = strip(first(split(raw_line, '#'; limit = 2)))
        isempty(line) && continue
        cells = split(line)
        length(cells) == 3 || error("[qoblib] Invalid stock-price row: $line")
        push!(times, parse(Int, cells[1]))
        cells[2] in symbols || push!(symbols, cells[2])
    end
    length(symbols) == n_assets || error("[qoblib] Portfolio asset count mismatch")
    times == Set(0:(n_periods-1)) || error("[qoblib] Portfolio periods mismatch")
    return (;
        instance = "po_$instance",
        symbols,
        periods = n_periods,
        budget = parse(Int, budget),
        risk = parse(Float64, risk),
    )
end

function _qoblib_portfolio_positions(io::IO, layout)
    headers = Dict{String,String}()
    # Counts are per asset, direction (+1 then -1), and zero-based period.
    counts = zeros(Int, length(layout.symbols), 2, layout.periods)
    seen = Set{Tuple{Int,Int}}()
    for raw_line in eachline(io)
        line = strip(first(split(raw_line, '#'; limit = 2)))
        isempty(line) && continue
        cells = split(line)
        if cells[1] in ("instance", "budget", "lambda", "objective")
            length(cells) == 2 || error("[qoblib] Invalid portfolio header: $line")
            haskey(headers, cells[1]) &&
                error("[qoblib] Duplicate portfolio header: $(cells[1])")
            headers[cells[1]] = cells[2]
            continue
        end
        length(cells) == 4 || error("[qoblib] Invalid portfolio position: $line")
        period = parse(Int, cells[1]) + 1
        asset = findfirst(==(cells[2]), layout.symbols)
        isnothing(asset) && error("[qoblib] Unknown portfolio symbol: $(cells[2])")
        1 <= period <= layout.periods || error("[qoblib] Portfolio period out of range")
        (asset, period) in seen && error("[qoblib] Duplicate portfolio position")
        push!(seen, (asset, period))
        units = parse.(Int, cells[3:4])
        all(u -> 0 <= u <= 3, units) || error("[qoblib] Portfolio unit count out of range")
        counts[asset, :, period] = units
    end
    get(headers, "instance", layout.instance) == layout.instance ||
        error("[qoblib] Portfolio instance header mismatch")
    parse(Int, get(headers, "budget", "")) == layout.budget ||
        error("[qoblib] Portfolio budget header mismatch")
    parse(Float64, get(headers, "lambda", "")) == layout.risk ||
        error("[qoblib] Portfolio lambda header mismatch")
    objective =
        haskey(headers, "objective") ? parse(Float64, headers["objective"]) : missing
    ismissing(objective) ||
        isfinite(objective) ||
        error("[qoblib] Nonfinite portfolio objective")
    return counts, objective
end

"""Map canonical unit counts to the pinned u3_c10 model, not the original solver bits.

Fill copy slots in order, then reconstruct capital (4 bits) and budget (7 bits)
slacks. Reject positions whose slacks cannot represent a feasible source
solution; callers retain those submissions as unmapped provenance.
"""
function _qoblib_read_portfolio_solution(
    io::IO,
    root_path::AbstractString,
    problem::AbstractString,
    dimension::Integer,
)
    layout = _qoblib_portfolio_layout(root_path, problem)
    expected = (6 * length(layout.symbols) + 11) * layout.periods
    dimension == expected || error("[qoblib] Portfolio QUBO dimension mismatch")
    counts, source_value = _qoblib_portfolio_positions(io, layout)
    state = Int[]
    for asset in eachindex(layout.symbols),
        copy = 1:3,
        direction = 1:2,
        t = 1:layout.periods

        push!(state, Int(copy <= counts[asset, direction, t]))
    end
    cash_slack = [10 - sum(counts[:, 1, t]) + sum(counts[:, 2, t]) for t = 1:layout.periods]
    count_slack = [layout.budget - sum(counts[:, :, t]) for t = 1:layout.periods]
    for (slacks, width) in ((cash_slack, 4), (count_slack, 7))
        all(s -> 0 <= s < 2^width, slacks) || error("[qoblib] Infeasible portfolio slack")
        for bit = 0:(width-1), t = 1:layout.periods
            push!(state, (slacks[t] >> bit) & 1)
        end
    end
    return (;
        state,
        source_value,
        conversion = "Canonical portfolio positions to u3_c10 QUBO: ordered copy slots and reconstructed capital/budget slack bits; not the original solver bitstring.",
    )
end
