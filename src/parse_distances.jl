"""
    parse_distances(data, edge_weight_type; edge_weight_format=nothing,
                    node_coord=nothing, kwargs...) -> Matrix

Compute or parse the n-by-n distance matrix. `edge_weight_type` decides how:

- `EUC_2D`, `FLOOR_2D`, `CEIL_2D`, `EXACT_2D`: Euclidean distances between the
  rows of `node_coord`, respectively unrounded, floored, ceiled, or multiplied
  by 1000 and rounded.
- `EXPLICIT`: parse `data` (a vector of rows) according to
  `edge_weight_format`, which must be `LOWER_ROW` or `FULL_MATRIX`.

Throws an `ArgumentError` for unknown types/formats or missing coordinates.
"""
function parse_distances(
    data,
    edge_weight_type;
    edge_weight_format = nothing,
    node_coord = nothing,
    kwargs...,
)
    edge_weight_type = string(edge_weight_type)

    if occursin("2D", edge_weight_type)  # Euclidean distance on node coordinates
        if node_coord === nothing
            throw(ArgumentError(
                "Cannot compute Euclidean distances because node coordinates " *
                "are not provided.",
            ))
        end

        distance = pairwise_euclidean(node_coord)

        edge_weight_type == "EUC_2D" && return distance
        edge_weight_type == "FLOOR_2D" && return floor.(distance)
        edge_weight_type == "EXACT_2D" && return round.(distance .* 1000)
        edge_weight_type == "CEIL_2D" && return ceil.(distance)
    end

    if edge_weight_type == "EXPLICIT"
        edge_weight_format == "LOWER_ROW" && return from_lower_row(data)
        edge_weight_format == "FULL_MATRIX" && return from_full_matrix(data)
    end

    throw(ArgumentError("Edge weight type or format unknown."))
end

"""
    pairwise_euclidean(coords) -> Matrix{Float64}

Pairwise Euclidean distances between the rows of the n-by-d matrix `coords`.
"""
function pairwise_euclidean(coords::AbstractMatrix)
    n = size(coords, 1)
    D = zeros(Float64, n, n)
    for j in 1:n, i in (j + 1):n
        d = sqrt(sum(abs2, @views(coords[i, :] .- coords[j, :])))
        D[i, j] = D[j, i] = d
    end
    return D
end

pairwise_euclidean(coords::AbstractVector{<:AbstractVector}) =
    pairwise_euclidean(_tomatrix(coords))

pairwise_euclidean(coords::AbstractVector{<:Number}) =
    pairwise_euclidean(reshape(coords, 1, :))

"""
    from_lower_row(data) -> Matrix{Float64}

Full symmetric distance matrix from a `LOWER_ROW` edge weight section. The
values are read as one continuous stream (as specified by TSPLIB95),
regardless of how they are wrapped across lines.
"""
function from_lower_row(data)
    flat = Float64[x for x in Iterators.flatten(data)]

    # m = n * (n - 1) / 2  =>  n = (1 + sqrt(1 + 8m)) / 2
    n = (1 + isqrt(1 + 8 * length(flat))) ÷ 2

    D = zeros(Float64, n, n)
    k = 0
    for i in 2:n, j in 1:(i - 1)  # row-wise strictly lower triangle
        D[i, j] = D[j, i] = flat[k += 1]
    end
    return D
end

"""
    from_full_matrix(data) -> Matrix

Square distance matrix from a `FULL_MATRIX` edge weight section, read row by
row as one continuous stream of values.
"""
function from_full_matrix(data)
    flat = _tovector(collect(Iterators.flatten(data)))
    n = isqrt(length(flat))
    if n * n != length(flat)
        throw(ArgumentError(
            "FULL_MATRIX edge weight section with $(length(flat)) values " *
            "is not square.",
        ))
    end
    return permutedims(reshape(flat, n, n))  # values are row-major
end
