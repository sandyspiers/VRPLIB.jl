"""
    VRPLIB

Read and write Vehicle Routing Problem (VRP) instances and solutions in the
VRPLIB and Solomon formats. A Julia port of the Python package
[`vrplib`](https://github.com/PyVRP/VRPLIB).

Main entry points: [`read_instance`](@ref), [`read_solution`](@ref),
[`write_instance`](@ref) and [`write_solution`](@ref). The lower-level
parsers [`parse_vrplib`](@ref), [`parse_solomon`](@ref) and
[`parse_solution`](@ref) work directly on text.
"""
module VRPLIB

export read_instance, read_solution, write_instance, write_solution
export parse_vrplib, parse_solomon, parse_solution

include("parse_utils.jl")
include("parse_distances.jl")
include("parse_vrplib.jl")
include("parse_solomon.jl")
include("parse_solution.jl")
include("read.jl")
include("write.jl")

end # module VRPLIB
