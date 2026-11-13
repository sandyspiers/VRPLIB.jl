"""
    write_instance(path, data)

Write a VRP instance to `path` in VRPLIB format. `data` is any collection of
`key => value` pairs (a `Dict`, an `OrderedDict`, a vector of pairs, ...):

- If `value` is a string or number, it is a specification, written as
  `"{key}: {value}"`.
- Otherwise it is a data section: a vector (one value per row), a matrix
  (one line per row), or a vector of vectors (possibly ragged). It is
  written as the header `key` followed by its rows, each prefixed with its
  1-based index. `EDGE_WEIGHT_SECTION` and `DEPOT_SECTION` rows get no index.

Specifications are written before sections (both in their given order), as
the VRPLIB format requires; the file ends with `EOF`. The data is not
validated, so pass the section keys exactly as they should appear in the
file, e.g. `"NODE_COORD_SECTION"`.
"""
function write_instance(path::AbstractString, data)
    specs = [k => v for (k, v) in _keyvalues(data) if _is_specification(v)]
    sections = [k => v for (k, v) in _keyvalues(data) if !_is_specification(v)]

    open(path, "w") do io
        for (key, value) in specs
            println(io, key, ": ", value)
        end

        for (key, value) in sections
            println(io, _format_section(string(key), value))
        end

        println(io, "EOF")
    end

    return nothing
end

# Iterate key => value pairs of dicts, vectors of pairs and named tuples alike.
_keyvalues(data) = data
_keyvalues(data::NamedTuple) = pairs(data)

_is_specification(value) = value isa Union{AbstractString,Number,Symbol}

function _format_section(name::AbstractString, data)
    section = String[name]
    include_idx = name ∉ ("EDGE_WEIGHT_SECTION", "DEPOT_SECTION")
    prefix(idx) = include_idx ? "$idx\t" : ""

    rows = data isa AbstractMatrix ? eachrow(data) : data

    for (idx, row) in enumerate(rows)
        # Scalars are one-element rows: one-dimensional data is a column.
        text = row isa Union{AbstractVector,Tuple} ? join(row, '\t') : string(row)
        push!(section, prefix(idx) * text)
    end

    return join(section, '\n')
end

"""
    write_solution(path, routes, data=nothing)

Write a VRP solution to `path` following the VRPLIB convention. Each route
in `routes` is written as `"Route #{idx}: {visits...}"`. Each `key => value`
pair in the optional `data` is written as `"{key}: {value}"` afterwards.

Throws an `ArgumentError` if any route is empty.
"""
function write_solution(path::AbstractString, routes, data = nothing)
    any(isempty, routes) && throw(ArgumentError("Empty route in solution."))

    open(path, "w") do io
        for (idx, route) in enumerate(routes)
            println(io, join(["Route #$idx:"; string.(route)], ' '))
        end

        if data !== nothing
            for (key, value) in _keyvalues(data)
                println(io, key, ": ", _format_value(value))
            end
        end
    end

    return nothing
end

# Format values as Python's `str` would, so files match the Python package.
_format_value(value) = string(value)
_format_value(value::AbstractVector) = "[" * join(_format_value.(value), ", ") * "]"
_format_value(value::Tuple) = "(" * join(_format_value.(value), ", ") * ")"
