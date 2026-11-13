# VRPLIB.jl

An AI-written Julia port of the Python package [`vrplib`](https://github.com/PyVRP/VRPLIB)
for working with Vehicle Routing Problem (VRP) instances:

- reading VRPLIB and Solomon instances and solutions, and
- writing VRPLIB-style instances and solutions.

It has no dependencies outside Julia's standard library.

## Reading files

```julia
using VRPLIB

# Read VRPLIB formatted instances (default)
instance = read_instance("/path/to/X-n101-k25.vrp")
solution = read_solution("/path/to/X-n101-k25.sol")

# Read Solomon formatted instances
instance = read_instance("/path/to/C101.txt"; instance_format = "solomon")
solution = read_solution("/path/to/C101.sol")  # only 1 solution format
```

`instance` and `solution` are `Dict{String,Any}`s holding all parsed data:

```julia
julia> instance = read_instance("X-n101-k25.vrp");

julia> instance["node_coord"]   # 101×2 Matrix{Int64}
julia> instance["depot"]        # [1]
julia> instance["edge_weight"]  # 101×101 Matrix{Float64}

julia> keys(read_solution("X-n101-k25.sol"))
["cost", "routes"]
```

Pass `compute_edge_weights = false` to `read_instance` to skip computing the
distance matrix from node coordinates.

## Writing files

`write_instance` and `write_solution` write VRPLIB-style files. They do not
validate their input: it is up to you to write correct files.

```julia
write_instance("instance.vrp", [
    "NAME" => "instance",
    "TYPE" => "CVRP",
    "VEHICLES" => 2,
    "DIMENSION" => 1,
    "CAPACITY" => 1,
    "EDGE_WEIGHT_TYPE" => "EUC_2D",
    "NODE_COORD_SECTION" => [250 250; 500 500],
    "DEMAND_SECTION" => [1, 1],
    "DEPOT_SECTION" => [1],
])
```

```
NAME: instance
TYPE: CVRP
VEHICLES: 2
DIMENSION: 1
CAPACITY: 1
EDGE_WEIGHT_TYPE: EUC_2D
NODE_COORD_SECTION
1	250	250
2	500	500
DEMAND_SECTION
1	1
2	1
DEPOT_SECTION
1
EOF
```

Strings and numbers are written as specifications. Vectors, matrices and
vectors of vectors are written as data sections, with a 1-based index column
(except for `EDGE_WEIGHT_SECTION` and `DEPOT_SECTION`). `data` can be a
`Dict`, a vector of pairs, a `NamedTuple` or an `OrderedDict`.
Specifications are always written before sections.

```julia
write_solution("solution.sol", [[1], [2, 3], [4, 5, 6]],
               ["Cost" => 42, "Vehicle types" => [1, 2, 3]])
```

```
Route #1: 1
Route #2: 2 3
Route #3: 4 5 6
Cost: 42
Vehicle types: [1, 2, 3]
```

## Format notes

- **Specifications** are `KEY: VALUE` lines. Keys are lowercased; values are
  parsed as `Int`, `Float64` or `String`. Any key is accepted.
- **Data sections** start with a `*_SECTION` header (optionally followed by
  a colon). Each row starts with an index, which is dropped. Sections with
  one value per row become `Vector`s, sections with several become
  `Matrix`es (one row per line), and ragged sections become a `Vector` of
  `Vector`s.
- **Edge weights**: `EUC_2D` (unrounded), `FLOOR_2D`, `CEIL_2D` and `EXACT_2D`
  (×1000, rounded) are computed from `NODE_COORD_SECTION`. `EXPLICIT` weights
  are read from `LOWER_ROW` or `FULL_MATRIX` sections.
- **Solomon** instances give `name`, `vehicles`, `capacity`, `node_coord`,
  `demand`, `time_window`, `service_time` and unrounded Euclidean
  `edge_weight`.

## Differences from the Python package

- **Depot indices are 1-based.** Python `vrplib` shifts `DEPOT_SECTION`
  values to 0-based. Here they are kept as in the file, so they index
  `node_coord` rows and `edge_weight` directly.
- **Solution routes are as written in the file.** In CVRPLIB solutions the
  depot is node 0 and customers are numbered from 1, so customer `c` is
  index `c + 1` in the instance's arrays.
- Options are keyword arguments: `read_instance(path; instance_format,
  compute_edge_weights)`.
- Errors: Python's `ValueError` becomes `ArgumentError`, and files not in the
  expected format raise an `ErrorException`.
- `write_instance` always writes specifications before sections, because
  Julia's `Dict` is unordered and the reader rejects the other order.

