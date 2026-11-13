"""
    text2lines(text) -> Vector{String}

Split `text` into non-empty, stripped lines, dropping comment lines (lines
that start with `#` after stripping).
"""
function text2lines(text::AbstractString)
    lines = String[]
    for line in eachline(IOBuffer(text))
        stripped = strip(line)
        if !isempty(stripped) && !startswith(stripped, '#')
            push!(lines, String(stripped))
        end
    end
    return lines
end

"""
    infer_type(s) -> Union{Int,Float64,String}

Parse `s` as an `Int` if possible, otherwise as a `Float64`, otherwise return
it unchanged as a `String`.
"""
function infer_type(s::AbstractString)
    i = tryparse(Int, s)
    i === nothing || return i
    f = tryparse(Float64, s)
    f === nothing || return f
    return String(s)
end

# Element type that all of `xs` can be converted to: numeric promotion for
# numbers (Int + Float64 -> Float64), `Any` if strings and numbers are mixed.
_eltype(xs) = isempty(xs) ? Any : mapreduce(typeof, promote_type, xs)

_tovector(xs) = convert(Vector{_eltype(xs)}, collect(xs))

# Builds an n-by-m matrix from n rows of equal length m.
function _tomatrix(rows)
    n = length(rows)
    m = n == 0 ? 0 : length(first(rows))
    T = _eltype(Iterators.flatten(rows))
    M = Matrix{T}(undef, n, m)
    for (i, row) in enumerate(rows), (j, x) in enumerate(row)
        M[i, j] = x
    end
    return M
end
