"""
    parse_solomon(text; compute_edge_weights=true) -> Dict{String,Any}

Parse the text of a Solomon VRPTW instance. The result contains `"name"`,
`"vehicles"`, `"capacity"`, `"node_coord"` (n-by-2), `"demand"`,
`"time_window"` (n-by-2), `"service_time"` and, if `compute_edge_weights`
is true, the unrounded Euclidean `"edge_weight"` matrix.
"""
function parse_solomon(text::AbstractString; compute_edge_weights::Bool = true)
    lines = text2lines(text)

    is_valid_solomon_instance(lines)

    instance = Dict{String,Any}("name" => lines[1])
    instance["vehicles"], instance["capacity"] = parse.(Int, split(lines[4]))

    data = _tomatrix([parse.(Int, split(line)) for line in @view lines[7:end]])

    instance["node_coord"] = data[:, 2:3]
    instance["demand"] = data[:, 4]
    instance["time_window"] = data[:, 5:6]
    instance["service_time"] = data[:, 7]

    if compute_edge_weights
        instance["edge_weight"] = pairwise_euclidean(instance["node_coord"])
    end

    return instance
end

"""
    is_valid_solomon_instance(lines)

Throw an error if `lines` do not follow the Solomon format requirements.
"""
function is_valid_solomon_instance(lines::AbstractVector{<:AbstractString})
    # Header names are separated on whitespace because the spacing of some
    # Solomon instances is off.
    headers = ("CUST", "NO.", "XCOORD.", "YCOORD.", "DEMAND", "READY", "DUE",
               "DATE", "SERVICE", "TIME")

    valid =
        length(lines) >= 6 &&
        !isempty(lines[1]) &&
        occursin("VEHICLE", lines[2]) &&
        occursin("NUMBER", lines[3]) &&
        occursin("CAPACITY", lines[3]) &&
        length(split(lines[4])) == 2 &&
        all(s -> tryparse(Int, s) !== nothing, split(lines[4])) &&
        occursin("CUSTOMER", lines[5]) &&
        all(h -> occursin(h, lines[6]), headers)

    valid || error("Instance does not conform to the Solomon format.")
    return nothing
end
