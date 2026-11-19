const HDF5 = QUBOLib.HDF5
const STREAMED_STORAGE = QUBOLib._COMPACT_QUBIN_STORAGE
const TERM_CHUNK_LENGTH = QUBOLib._HDF5_VECTOR_CHUNK_LENGTH

function term_dataset(group, name, ::Type{T}, count, block) where {T}
    return HDF5.create_dataset(group, name, T, (count,);
        chunk = (min(count, block),), shuffle = true, deflate = QUBOLib._HDF5_DEFAULT_DEFLATE)
end

mutable struct TermChunk
    datasets::Tuple{HDF5.Dataset,HDF5.Dataset,HDF5.Dataset}
    i::Vector{Int32}
    j::Vector{Int32}
    v::Vector{Float64}
    written::Int
    used::Int
    low::Float64
    high::Float64
    abs_low::Float64
    abs_high::Float64
end

function flush_terms!(chunk)
    chunk.used == 0 && return nothing
    range = (chunk.written + 1):(chunk.written + chunk.used)
    i, j, v = chunk.datasets
    selection = 1:chunk.used
    i[range] = view(chunk.i, selection)
    j[range] = view(chunk.j, selection)
    v[range] = view(chunk.v, selection)
    chunk.written += chunk.used
    chunk.used = 0
    return nothing
end

function write_quadratic!(chunk, i, j, value)
    require(chunk.written + chunk.used < length(chunk.datasets[3]), "quadratic count exceeds independent audit")
    chunk.used += 1
    chunk.i[chunk.used] = i
    chunk.j[chunk.used] = j
    chunk.v[chunk.used] = value
    chunk.low = min(chunk.low, value)
    chunk.high = max(chunk.high, value)
    chunk.abs_low = min(chunk.abs_low, abs(value))
    chunk.abs_high = max(chunk.abs_high, abs(value))
    chunk.used == length(chunk.v) && flush_terms!(chunk)
    return nothing
end

"""Write the standard QUBin groups with a bounded coordinate buffer."""
function stream_qubin!(group, path, expected; block = TERM_CHUNK_LENGTH)
    n, l, m = (expected[k] for k in ("n", "l", "m"))
    require(all(x -> x isa Int && !(x isa Bool), (n, l, m)) &&
        2 <= n <= 200_000 && 0 < l <= n && 0 < m <= min(60_000_000, Int64(n) * (n - 1) ÷ 2),
        "invalid independent audit model counts")
    require(block isa Int && 0 < block <= TERM_CHUNK_LENGTH, "invalid coordinate block size")
    model = HDF5.create_group(group, "model")
    form = HDF5.create_group(model, "form")
    HDF5.attrs(form)[QUBOLib._COMPACT_QUBIN_ATTRIBUTE] = STREAMED_STORAGE
    quadratic = HDF5.create_group(form, "quadratic")
    datasets = (term_dataset(quadratic, "i", Int32, m, block), term_dataset(quadratic, "j", Int32, m, block),
        term_dataset(quadratic, "v", Float64, m, block))
    capacity = min(m, block)
    chunk = TermChunk(datasets, Vector{Int32}(undef, capacity), Vector{Int32}(undef, capacity),
        Vector{Float64}(undef, capacity), 0, 0, Inf, -Inf, Inf, -Inf)
    li = Int32[]
    lv = Float64[]
    sizehint!(li, l)
    sizehint!(lv, l)
    p = try
        p = scan_polynomial(path) do i, j, value
            if j == 0
                require(length(li) < l, "linear count exceeds independent audit")
                push!(li, i)
                push!(lv, value)
            else
                write_quadratic!(chunk, i, j, value)
            end
        end
        require((p.n, p.l, p.m) == (n, l, m), "Original counts differ from independent audit")
        flush_terms!(chunk)
        p
    finally
        foreach(close, datasets)
    end
    QUBOLib._write_compressed_dataset!(model, "variables", Int32, collect(Int32(1):Int32(n)))
    linear = HDF5.create_group(form, "linear")
    QUBOLib._write_compressed_dataset!(linear, "i", Int32, li)
    QUBOLib._write_compressed_dataset!(linear, "v", Float64, lv)
    form["dimension"] = Int32(n)
    form["scale"] = p.scale
    form["offset"] = p.offset
    form["sense"] = p.h["sense"]
    form["domain"] = "bool"
    model["metadata"] = "{}"
    # Match the legacy empty solution frame with portable integer payloads.
    solution = HDF5.create_group(group, "solution")
    data = HDF5.create_group(solution, "data")
    data["state"] = zeros(Int32, 0, 0)
    data["value"] = Float64[]
    data["reads"] = Int32[]
    solution["metadata"] = "{}"
    solution["sense"] = "min"
    solution["domain"] = "bool"
    shape = (n = n, sense = p.h["sense"], domain = "bool", density = (2m + l) / Int64(n)^2,
        linear_density = l / n, quadratic_density = 2m / (Int64(n) * (n - 1)))
    linear_extrema = (min = minimum(lv), max = maximum(lv),
        abs_min = minimum(abs, lv), abs_max = maximum(abs, lv))
    quadratic_extrema = (min = chunk.low, max = chunk.high, abs_min = chunk.abs_low, abs_max = chunk.abs_high)
    return (; shape, linear_extrema, quadratic_extrema,
        identity = streamed_identity(p.h, l, m, p.fingerprint))
end

function streamed_identity(h, l, m, fingerprint)
    return Dict("schema" => FINGERPRINT_SCHEMA, "sha256" => fingerprint,
        "n" => h["n"], "l" => l, "m" => m, "domain" => h["domain"], "sense" => h["sense"],
        "scale_exact" => h["scale_exact"], "offset_exact" => h["offset_exact"])
end

"""Read sorted QUBin coordinates in bounded chunks when independently auditing a streamed build."""
function visit_stored_terms(visit, dataset, n, count, quadratic)
    i, v = dataset["i"], dataset["v"]
    j = quadratic ? dataset["j"] : nothing
    require(eltype(i) == Int32 && eltype(v) == Float64 && (!quadratic || eltype(j) == Int32) &&
        size(i) == size(v) == (count,) && (!quadratic || size(j) == (count,)), "invalid streamed coordinate layout")
    previous = (0, 0)
    for first_row in 1:TERM_CHUNK_LENGTH:count
        block = first_row:min(first_row + TERM_CHUNK_LENGTH - 1, count)
        rows, values = i[block], v[block]
        columns = quadratic ? j[block] : nothing
        for k in eachindex(rows)
            a = Int(rows[k])
            b = quadratic ? Int(columns[k]) : 0
            c = values[k]
            coordinates = (a, b)
            require(1 <= a <= n && (!quadratic || a < b <= n) && coordinates > previous &&
                isfinite(c) && !iszero(c), "invalid, duplicate or out-of-order streamed coordinate")
            visit(a, b, exact_text(c))
            previous = coordinates
        end
    end
    return nothing
end

function verify_streamed_model(entry, group)
    model = group["model"]
    form = model["form"]
    n, l, m = (entry["metrics"][k] for k in ("n", "l", "m"))
    scale, offset = read(form["scale"]), read(form["offset"])
    sense, domain = read(form["sense"]), read(form["domain"])
    dimension = read(form["dimension"])
    require(HDF5.attrs(form)[QUBOLib._COMPACT_QUBIN_ATTRIBUTE] == STREAMED_STORAGE &&
        dimension isa Int32 && n == dimension && domain == "bool" && sense in ("min", "max") &&
        scale isa Float64 && isfinite(scale) && !iszero(scale) && offset isa Float64 && isfinite(offset),
        "invalid streamed QUBin header")
    labels = model["variables"]
    require(eltype(labels) === Int32 && size(labels) == (n,) && read(labels) == collect(Int32(1):dimension),
        "stored variable order differs")
    require(JSON.parse(read(model["metadata"])) == Dict(), "unexpected inherited model metadata")
    QUBOLib._check_compact_solution(group["solution"])
    h = Dict("n" => n, "domain" => domain, "sense" => sense,
        "scale_exact" => exact_text(scale), "offset_exact" => exact_text(offset),
        "variable_order" => "one_based_internal")
    ctx = fingerprint_context(h)
    transport = saved_transport(h) do emit
        visit_stored_terms(form["linear"], n, l, false) do i, j, coefficient
            emit(i, j, coefficient)
            SHA.update!(ctx, codeunits("linear $i $coefficient\n"))
        end
        visit_stored_terms(form["quadratic"], n, m, true) do i, j, coefficient
            emit(i, j, coefficient)
            SHA.update!(ctx, codeunits("quadratic $i $j $coefficient\n"))
        end
    end
    expected = entry["artifacts"]["polynomial"]
    require(transport["sha256"] == expected["sha256"] && transport["bytes"] == expected["bytes"],
        "stored model differs from immutable saved Original polynomial bytes")
    return streamed_identity(h, l, m, bytes2hex(SHA.digest!(ctx)))
end
