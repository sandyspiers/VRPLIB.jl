"""
    read_instance(path; instance_format="vrplib", compute_edge_weights=true)

Read the instance at `path`. `instance_format` is `"vrplib"` (default) or
`"solomon"`. If `compute_edge_weights` is true, edge weights are computed
from the node coordinates when the instance has no explicit edge weights.

Returns a `Dict{String,Any}` with the instance data; see
[`parse_vrplib`](@ref) and [`parse_solomon`](@ref).
"""
function read_instance(
    path::AbstractString;
    instance_format::AbstractString = "vrplib",
    compute_edge_weights::Bool = true,
)
    if instance_format == "vrplib"
        return parse_vrplib(read(path, String); compute_edge_weights)
    elseif instance_format == "solomon"
        return parse_solomon(read(path, String); compute_edge_weights)
    end

    throw(ArgumentError("Format style $instance_format not known."))
end

"""
    read_solution(path) -> Dict{String,Any}

Read the solution at `path`. See [`parse_solution`](@ref).
"""
read_solution(path::AbstractString) = parse_solution(read(path, String))
