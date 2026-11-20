const _HDF5_MIN_COMPRESS_LENGTH = 16
const _HDF5_DEFAULT_DEFLATE     = 3
const _HDF5_VECTOR_CHUNK_LENGTH = 65_536
const _HDF5_MATRIX_CHUNK_ROWS   = 64
const _COMPACT_QUBIN_ATTRIBUTE = "coordinate_storage"
const _COMPACT_QUBIN_STORAGE = "sorted-int32-qubin-v1"
const _COMPACT_QUBIN_MAX_VARIABLES = 250_000

function _qubin_format()
    if isdefined(QUBOTools, :Format)
        return Core.apply_type(getfield(QUBOTools, :Format), :qubin)()
    else
        return getfield(QUBOTools, :QUBin)()
    end
end

function _write_compressed_dataset!(
    parent::Union{HDF5.File,HDF5.Group},
    name::AbstractString,
    ::Type{T},
    data::AbstractVector{T};
    deflate::Integer = _HDF5_DEFAULT_DEFLATE,
) where {T}
    if deflate > 0 && isbitstype(T) && length(data) >= _HDF5_MIN_COMPRESS_LENGTH
        chunk_len = min(length(data), _HDF5_VECTOR_CHUNK_LENGTH)
        dset = HDF5.create_dataset(
            parent,
            name,
            HDF5.datatype(T),
            HDF5.dataspace(size(data));
            chunk   = (chunk_len,),
            shuffle = true,
            deflate = Int(deflate),
        )
        write(dset, data)
    else
        write(HDF5.create_dataset(parent, name, T, size(data)), data)
    end

    return nothing
end

function _write_compressed_dataset!(
    parent::Union{HDF5.File,HDF5.Group},
    name::AbstractString,
    ::Type{T},
    data::AbstractMatrix{T};
    deflate::Integer = _HDF5_DEFAULT_DEFLATE,
) where {T}
    if deflate > 0 &&
       isbitstype(T) &&
       length(data) >= _HDF5_MIN_COMPRESS_LENGTH &&
       size(data, 1) > 0 &&
       size(data, 2) > 0
        chunk_dims = (
            min(size(data, 1), _HDF5_MATRIX_CHUNK_ROWS),
            min(size(data, 2), _HDF5_VECTOR_CHUNK_LENGTH),
        )
        dset = HDF5.create_dataset(
            parent,
            name,
            HDF5.datatype(T),
            HDF5.dataspace(size(data));
            chunk   = chunk_dims,
            shuffle = true,
            deflate = Int(deflate),
        )
        write(dset, data)
    else
        write(HDF5.create_dataset(parent, name, T, size(data)), data)
    end

    return nothing
end

function _write_qubin_solution(
    fp::P,
    sol::QUBOTools.AbstractSolution{T,U},
) where {P<:Union{HDF5.File,HDF5.Group},T,U}
    sol_grp  = HDF5.create_group(fp, "solution")
    data_grp = HDF5.create_group(sol_grp, "data")

    if isempty(sol)
        ψ = zeros(U, 0, 0)
        λ = zeros(T, 0)
        r = zeros(Int, 0)
    else
        samples = collect(sol)
        n_vars  = length(QUBOTools.state(first(samples)))
        n_samp  = length(samples)
        ψ = Matrix{U}(undef, n_vars, n_samp)
        λ = Vector{T}(undef, n_samp)
        r = Vector{Int}(undef, n_samp)

        for (i, sample) in enumerate(samples)
            ψ[:, i] = QUBOTools.state(sample)
            λ[i]    = QUBOTools.value(sample)
            r[i]    = QUBOTools.reads(sample)
        end
    end

    _write_compressed_dataset!(data_grp, "state", U, ψ)
    _write_compressed_dataset!(data_grp, "value", T, λ)
    _write_compressed_dataset!(data_grp, "reads", Int, r)

    sol_grp["sense"]    = String(QUBOTools.sense(sol))
    sol_grp["domain"]   = String(QUBOTools.domain(sol))
    sol_grp["metadata"] = JSON.json(QUBOTools.metadata(sol))

    return nothing
end

function _write_model(
    fp::P,
    model::M,
    fmt::QUBOTools.AbstractFormat,
) where {P<:Union{HDF5.File,HDF5.Group},V,T,U,M<:QUBOTools.AbstractModel{V,T,U}}
    model_grp = HDF5.create_group(fp, "model")

    vars = collect(V, QUBOTools.variables(model))
    _write_compressed_dataset!(model_grp, "variables", V, vars)

    form_grp = HDF5.create_group(model_grp, "form")
    n, L, Q, α, β, s, x = QUBOTools.form(model, :sparse)

    form_grp["dimension"] = n

    lin_grp = HDF5.create_group(form_grp, "linear")
    li, lv = QUBOTools.SparseArrays.findnz(L)
    _write_compressed_dataset!(lin_grp, "i", Int, li)
    _write_compressed_dataset!(lin_grp, "v", T, lv)

    quad_grp = HDF5.create_group(form_grp, "quadratic")
    qi, qj, qv = QUBOTools.SparseArrays.findnz(Q)
    _write_compressed_dataset!(quad_grp, "i", Int, qi)
    _write_compressed_dataset!(quad_grp, "j", Int, qj)
    _write_compressed_dataset!(quad_grp, "v", T, qv)

    form_grp["scale"]  = α
    form_grp["offset"] = β
    form_grp["sense"]  = String(s)
    form_grp["domain"] = String(x)

    model_grp["metadata"] = JSON.json(QUBOTools.metadata(model))

    _write_qubin_solution(fp, QUBOTools.solution(model))

    return nothing
end

# QUBOTools' sparse forms use native Int indices. Fill them directly from the
# compact on-disk coordinates without holding all three coordinate vectors.
function _read_compact_quadratic(group, n::Int)
    i, j, v = group["i"], group["j"], group["v"]
    count = length(v)
    0 < count <= min(60_000_000, Int64(n) * (n - 1) ÷ 2) &&
        size(i) == size(j) == size(v) == (count,) &&
        eltype(i) === eltype(j) === Int32 && eltype(v) === Float64 ||
        throw(ArgumentError("invalid compact quadratic dataset layout"))
    blocksize = _HDF5_VECTOR_CHUNK_LENGTH
    counts = zeros(Int, n)
    for first in 1:blocksize:count
        block = first:min(first + blocksize - 1, count)
        for column in j[block]
            1 <= column <= n || throw(ArgumentError("invalid compact quadratic column"))
            counts[column] += 1
        end
    end
    colptr = vcat(1, cumsum(counts) .+ 1)
    next_index = copy(colptr[1:n])
    rowval = Vector{Int}(undef, count)
    nzval = Vector{Float64}(undef, count)
    for first in 1:blocksize:count
        block = first:min(first + blocksize - 1, count)
        rows, columns, values = i[block], j[block], v[block]
        for k in eachindex(values)
            row, column, value = Int(rows[k]), Int(columns[k]), values[k]
            1 <= row < column <= n && isfinite(value) && !iszero(value) ||
                throw(ArgumentError("invalid compact quadratic coefficient"))
            slot = next_index[column]
            slot < colptr[column + 1] && (slot == colptr[column] || rowval[slot - 1] < row) ||
                throw(ArgumentError("duplicate or unsorted compact quadratic coordinate"))
            rowval[slot] = row
            nzval[slot] = value
            next_index[column] += 1
        end
    end
    next_index == colptr[2:end] || throw(ArgumentError("incomplete compact quadratic columns"))
    return QUBOTools.SparseArrays.SparseMatrixCSC(n, n, colptr, rowval, nzval)
end

function _check_compact_solution(solution)
    data = solution["data"]
    state, value, reads = data["state"], data["value"], data["reads"]
    JSON.parse(read(solution["metadata"])) == Dict() &&
        read(solution["sense"]) == "min" && read(solution["domain"]) == "bool" &&
        eltype(state) === Int32 && size(state) == (0, 0) &&
        eltype(value) === Float64 && size(value) == (0,) &&
        eltype(reads) === Int32 && size(reads) == (0,) ||
        throw(ArgumentError("invalid compact empty solution layout"))
    return nothing
end

function _read_qubin_model(group)
    model = group["model"]
    form = model["form"]
    attributes = HDF5.attrs(form)
    if !haskey(attributes, _COMPACT_QUBIN_ATTRIBUTE)
        return QUBOTools.read_model(group, _qubin_format())
    end
    attributes[_COMPACT_QUBIN_ATTRIBUTE] == _COMPACT_QUBIN_STORAGE ||
        throw(ArgumentError("unsupported compact QUBin coordinate layout"))
    dimension = read(form["dimension"])
    stored_labels = model["variables"]
    dimension isa Int32 && 0 < dimension <= _COMPACT_QUBIN_MAX_VARIABLES &&
        eltype(stored_labels) === Int32 && size(stored_labels) == (dimension,) &&
        read(stored_labels) == collect(Int32(1):dimension) || throw(ArgumentError("invalid compact variable labels"))
    n = Int(dimension)
    linear = form["linear"]
    indices, values = linear["i"], linear["v"]
    eltype(indices) === Int32 && eltype(values) === Float64 &&
        size(indices) == size(values) == (length(values),) && 0 < length(values) <= n ||
        throw(ArgumentError("invalid compact linear dataset layout"))
    linear_indices, linear_values = read(indices), read(values)
    all(i -> 1 <= i <= n, linear_indices) && allunique(linear_indices) && issorted(linear_indices) &&
        all(value -> isfinite(value) && !iszero(value), linear_values) ||
        throw(ArgumentError("invalid compact linear coefficients"))
    L = QUBOTools.SparseLinearForm(QUBOTools.SparseArrays.sparsevec(Int.(linear_indices), linear_values, n))
    Q = QUBOTools.SparseQuadraticForm(_read_compact_quadratic(form["quadratic"], n))
    scale = read(form["scale"])
    offset = read(form["offset"])
    sense = QUBOTools.sense(read(form["sense"]))
    domain = QUBOTools.domain(read(form["domain"]))
    stored_form = QUBOTools.Form{Float64}(n, L, Q, scale, offset; sense, domain)
    variables = QUBOTools.VariableMap{Int}(collect(1:n))
    metadata = Dict{String,Any}(JSON.parse(read(model["metadata"])))
    _check_compact_solution(group["solution"])
    solution = QUBOTools.SampleSet{Float64,Int}()
    return QUBOTools.Model{Int,Float64,Int}(variables, stored_form; metadata, solution)
end

function _copy_hdf5_object_compressed!(
    dst_parent::Union{HDF5.File,HDF5.Group},
    src_parent::Union{HDF5.File,HDF5.Group};
    deflate::Integer = _HDF5_DEFAULT_DEFLATE,
)
    for attr_name in keys(HDF5.attrs(src_parent))
        HDF5.attrs(dst_parent)[attr_name] = HDF5.read_attribute(src_parent, attr_name)
    end

    for name in keys(src_parent)
        obj = src_parent[name]
        if obj isa HDF5.Group
            grp = HDF5.create_group(dst_parent, name)
            _copy_hdf5_object_compressed!(grp, obj; deflate)
        elseif obj isa HDF5.Dataset
            data = read(obj)
            if data isa AbstractVector && isbitstype(eltype(data))
                _write_compressed_dataset!(dst_parent, name, eltype(data), data; deflate)
            elseif data isa AbstractMatrix && isbitstype(eltype(data))
                _write_compressed_dataset!(dst_parent, name, eltype(data), data; deflate)
            else
                dst_parent[name] = data
            end
            dset_out = dst_parent[name]
            for attr_name in keys(HDF5.attrs(obj))
                HDF5.attrs(dset_out)[attr_name] = HDF5.read_attribute(obj, attr_name)
            end
        end
    end

    return nothing
end

function repack_archive!(
    src_path::AbstractString,
    dst_path::AbstractString = src_path;
    deflate::Integer = _HDF5_DEFAULT_DEFLATE,
)
    in_place = abspath(src_path) == abspath(dst_path)
    target_path = in_place ? "$(dst_path).repack.tmp" : dst_path
    rm(target_path; force = true)

    try
        HDF5.h5open(src_path, "r") do f_in
            HDF5.h5open(target_path, "w") do f_out
                _copy_hdf5_object_compressed!(f_out, f_in; deflate)
            end
        end
        if in_place
            mv(target_path, dst_path; force = true)
        end
    catch
        in_place && rm(target_path; force = true)
        rethrow()
    end

    return dst_path
end
