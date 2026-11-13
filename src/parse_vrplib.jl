"""
    parse_vrplib(text; compute_edge_weights=true) -> Dict{String,Any}

Parse the text of a VRPLIB instance. An instance consists of two parts:

1. Specifications: single lines of the form `<KEY>: <VALUE>`.
2. Data sections: a `<KEY>_SECTION` header followed by rows of values.

Each specification is stored under its lowercase keyword, with the value
parsed as `Int`, `Float64` or `String`. Each data section is stored under its
lowercase name without the `_SECTION` suffix. Section rows have their leading
index column removed and become a `Matrix` (one row per line), a `Vector` if
there is a single value per line, or a `Vector` of `Vector`s if the rows have
different lengths.

Special cases:
- `DEPOT_SECTION` is a vector of depot indices with the `-1` terminator
  removed. Indices stay **1-based**, as in the file (the Python package
  shifts them to 0-based).
- `EDGE_WEIGHT_SECTION` is parsed into a full distance matrix; see
  [`parse_distances`](@ref).

If no `EDGE_WEIGHT_SECTION` is present and `compute_edge_weights` is true,
the `"edge_weight"` matrix is computed from the node coordinates.
"""
function parse_vrplib(text::AbstractString; compute_edge_weights::Bool = true)
    instance = Dict{String,Any}()
    specs, sections = group_specifications_and_sections(text2lines(text))

    for spec in specs
        key, value = parse_specification(spec)
        instance[key] = value
    end

    for section in sections
        name, data = parse_section(section, instance)

        if haskey(instance, name)
            throw(ArgumentError(
                "$(uppercase(name)) is used both as specification and section.",
            ))
        end

        instance[name] = data
    end

    if !isempty(instance) && compute_edge_weights && !haskey(instance, "edge_weight")
        # Compute edge weights if there was no explicit edge weight section.
        instance["edge_weight"] = _parse_distances(Any[], instance)
    end

    return instance
end

# Calls `parse_distances` with the instance's specifications as keywords.
function _parse_distances(data, instance::AbstractDict)
    if !haskey(instance, "edge_weight_type")
        throw(ArgumentError(
            "Cannot compute edge weights: EDGE_WEIGHT_TYPE is not specified.",
        ))
    end

    return parse_distances(
        data,
        instance["edge_weight_type"];
        edge_weight_format = get(instance, "edge_weight_format", nothing),
        node_coord = get(instance, "node_coord", nothing),
        comment = get(instance, "comment", nothing),
    )
end

"""
    group_specifications_and_sections(lines) -> (specs, sections)

Group instance lines into specification lines and section blocks. Each
section block is a vector of lines starting with the `*_SECTION` header.
"""
function group_specifications_and_sections(lines::AbstractVector{<:AbstractString})
    specs = String[]
    sections = Vector{Vector{String}}()

    end_section = 0
    for (idx, line) in enumerate(lines)
        occursin("EOF", line) && break
        idx <= end_section && continue  # skip lines of the current section

        if occursin("_SECTION", line)
            start = idx
            end_section = start

            for next_line in @view lines[(start + 1):end]
                if occursin(':', next_line) && !occursin("_SECTION", next_line)
                    throw(ArgumentError("Specification presented after section."))
                end

                # The current section ends when a next section or an EOF
                # token is found.
                if occursin("_SECTION", next_line) || occursin("EOF", next_line)
                    break
                end

                end_section += 1
            end

            push!(sections, lines[start:end_section])
        elseif occursin(':', line)
            push!(specs, line)
        else
            error("Instance does not conform to the VRPLIB format.")
        end
    end

    return specs, sections
end

"""
    parse_specification(line) -> (key, value)

Parse a specification line as a keyword-value pair, split at the first
colon. The keyword is lowercased; the value goes through `infer_type`.
"""
function parse_specification(line::AbstractString)
    k, v = strip.(split(line, r"\s*:\s*"; limit = 2))
    return lowercase(k), infer_type(v)
end

"""
    parse_section(lines, instance) -> (name, data)

Parse the lines of a data section. `instance` holds the specifications parsed
so far, which are needed to interpret the edge weight section.
"""
function parse_section(lines::AbstractVector{<:AbstractString}, instance::AbstractDict)
    # Some section names include colons, so we strip those as well.
    header = strip(c -> c == ' ' || c == ':', first(lines))
    name = lowercase(chopsuffix(header, "_SECTION"))
    rows = [Any[infer_type(n) for n in split(line)] for line in @view lines[2:end]]

    if name == "edge_weight"
        # Edge weights involve extra processing.
        data = _parse_distances(rows, instance)
    elseif name == "depot"
        # Remove -1 end token. Depot indices are kept 1-based.
        data = _tovector(filter(!=(-1), collect(Iterators.flatten(rows))))
    elseif isempty(rows)
        data = Float64[]
    elseif any(row -> length(row) != length(first(rows)), rows)
        # Ragged rows: keep as a vector of vectors, without the index column.
        data = [_tovector(row[2:end]) for row in rows]
    else
        data = _tomatrix([row[2:end] for row in rows])

        if size(data, 2) == 1
            # Squeeze sections that contain only one value per line.
            data = vec(data)
        end
    end

    return String(name), data
end
