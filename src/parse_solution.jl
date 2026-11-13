"""
    parse_solution(text) -> Dict{String,Any}

Parse the text of a VRPLIB-style solution. Lines containing `Route` are
parsed into `"routes"`, a vector of integer vectors holding the visits
exactly as written in the file. Other lines are split at the first colon
(or, failing that, the first space) into a lowercase key and a value; lines
with neither are ignored.

Note that in CVRPLIB solution files the depot is node `0` and customers are
numbered `1:n-1`, so customer `c` corresponds to row/column `c + 1` of the
instance's 1-based `edge_weight` matrix.
"""
function parse_solution(text::AbstractString)
    solution = Dict{String,Any}("routes" => Vector{Int}[])

    for line in text2lines(text)
        if occursin("Route", line)
            visits = split(line, ':')[2]
            push!(solution["routes"], parse.(Int, split(visits)))
        elseif occursin(':', line) || occursin(' ', line)
            # Split at first colon or whitespace.
            split_at = occursin(':', line) ? ':' : ' '
            k, v = strip.(split(line, split_at; limit = 2))
            solution[lowercase(k)] = infer_type(v)
        end  # ignore lines without keyword-value pairs
    end

    return solution
end
