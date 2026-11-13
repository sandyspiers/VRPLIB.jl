using VRPLIB
using Test

using VRPLIB: text2lines, infer_type, parse_distances, parse_section,
              parse_specification, group_specifications_and_sections

const DATA_DIR = joinpath(@__DIR__, "data")
data(name) = joinpath(DATA_DIR, name)

const VRPLIB_FILES = ["A-n32-k5.vrp", "B-n31-k5.vrp", "CMT6.vrp", "E-n13-k4.vrp",
                      "F-n72-k4.vrp", "Golden_1.vrp", "Li_21.vrp", "ORTEC-n242-k12.vrp",
                      "P-n16-k8.vrp", "X-n101-k25.vrp"]

const SOLOMON_INSTANCE = [
    "C101",
    "VEHICLE",
    "NUMBER     CAPACITY",
    "25         200",
    "CUSTOMER",
    "CUST NO.  XCOORD.   YCOORD.  DEMAND   READY TIME  DUE DATE  SERVICE TIME",
    "0      40         50          0          0       1236          0",
    "1      45         68         10        912        967         90",
]

const SOLOMON_DIST = sqrt((40 - 45)^2 + (50 - 68)^2)

const SOLOMON_DESIRED = Dict{String,Any}(
    "name" => "C101",
    "vehicles" => 25,
    "capacity" => 200,
    "node_coord" => [40 50; 45 68],
    "demand" => [0, 10],
    "time_window" => [0 1236; 912 967],
    "service_time" => [0, 90],
    "edge_weight" => [0 SOLOMON_DIST; SOLOMON_DIST 0],
)

const VRPLIB_INSTANCE = [
    "NAME: VRPLIB",
    "EDGE_WEIGHT_TYPE: EUC_2D",
    "NODE_COORD_SECTION",
    "1  0  0",
    "2  0  1",
    "SERVICE_TIME_SECTION",
    "1  1",
    "TIME_WINDOW_SECTION",
    "1  1   2",
    "EOF",
]

# Writes `content` to a temporary file and returns its path.
function tmpfile(content = "")
    path, io = mktemp()
    write(io, content)
    close(io)
    return path
end

@testset "VRPLIB.jl" begin

@testset "parse_utils" begin
    @test text2lines("") == String[]
    @test text2lines("\n") == String[]
    @test text2lines("# test comment") == String[]
    @test text2lines("123\n#comment") == ["123"]
    @test text2lines("#\n#") == String[]
    @test text2lines(" # comment after whitespace") == String[]

    @test infer_type("3") === 3
    @test infer_type("-3") === -3
    @test infer_type("3.5") === 3.5
    @test infer_type("abc") == "abc"
    @test infer_type("") == ""
end

@testset "parse_distances" begin
    for (type, fmt) in [("2D", ""), ("EXPLICIT", ""), ("IMPLICIT", "LOWER_ROW"),
                        ("TEST", "ABCD")]
        @test_throws ArgumentError parse_distances([], type; edge_weight_format = fmt)
    end

    for type in ["EUC_2D", "FLOOR_2D", "CEIL_2D", "EXACT_2D"]
        @test_throws ArgumentError parse_distances([], type)
    end

    coords = [0 0; 1 1]
    @test parse_distances([], "EUC_2D"; node_coord = coords) ≈ [0 √2; √2 0]
    @test parse_distances([], "FLOOR_2D"; node_coord = coords) == [0 1; 1 0]
    @test parse_distances([], "CEIL_2D"; node_coord = coords) == [0 2; 2 0]
    @test parse_distances([], "EXACT_2D"; node_coord = coords) == [0 1414; 1414 0]

    desired = [0 1 2 4; 1 0 3 5; 2 3 0 6; 4 5 6 0]
    for rows in ([[1, 2, 3, 4, 5, 6]], [[1, 2, 3, 4], [5, 6]], [[1], [2, 3], [4, 5, 6]])
        @test parse_distances(rows, "EXPLICIT"; edge_weight_format = "LOWER_ROW") == desired
    end

    full = parse_distances([[0, 1, 2], [3, 0, 4], [5, 6, 0]], "EXPLICIT";
                           edge_weight_format = "FULL_MATRIX")
    @test full == [0 1 2; 3 0 4; 5 6 0]
    @test_throws ArgumentError parse_distances([[0, 1, 2]], "EXPLICIT";
                                               edge_weight_format = "FULL_MATRIX")
end

@testset "parse_solomon" begin
    for name in ["C101.sol"; VRPLIB_FILES]
        @test_throws ErrorException parse_solomon(read(data(name), String))
    end

    for lines in ([""], ["NAME", "CARS"], ["NAME", "VEHICLES", "?"],
                  ["NAME", "VEHICLES", "NUMBER CAPACITY", "20 100", "wrong"],
                  ["NAME", "VEHICLES", "NUMBER CAPACITY", "20 100", "wrong",
                   "CUST NO. XCOORD. YCOORD. DEMAND"])
        @test_throws ErrorException parse_solomon(join(lines, "\n"))
    end

    for name in ["C101.txt", "C1_2_1.txt"]
        @test parse_solomon(read(data(name), String)) isa Dict
    end

    @test parse_solomon(join(SOLOMON_INSTANCE, "\n")) == SOLOMON_DESIRED

    actual = parse_solomon(join(SOLOMON_INSTANCE, "\n"); compute_edge_weights = false)
    @test !haskey(actual, "edge_weight")
end

@testset "parse_solution" begin
    @test parse_solution("") == Dict("routes" => Vector{Int}[])
    @test parse_solution("Route #1: 1 2 3\n Route #2: 5 6\n COST: 10") ==
          Dict("routes" => [[1, 2, 3], [5, 6]], "cost" => 10)
    @test parse_solution("Route #1: 1 \n Route #2: 6\n comment: VRPLIB") ==
          Dict("routes" => [[1], [6]], "comment" => "VRPLIB")
    @test parse_solution("Route #1: 1 \n Route #2: 6\n time 180.23") ==
          Dict("routes" => [[1], [6]], "time" => 180.23)
    @test parse_solution("Route #1: 1 \n Route #2: 6\n ABCDE") ==
          Dict("routes" => [[1], [6]])
end

@testset "parse_vrplib" begin
    for name in ["C101.txt", "C1_2_1.txt", "C101.sol", "NoColonSpecification.txt"]
        @test_throws ErrorException parse_vrplib(read(data(name), String))
    end

    for name in VRPLIB_FILES
        @test parse_vrplib(read(data(name), String)) isa Dict
    end

    specs = ["NAME : ORTEC-VRPTW-ASYM-00c5356f-d1-n258-k12", "COMMENT : ORTEC"]
    sections = ["EDGE_WEIGHT_SECTION", "0\t1908", "1994\t0",
                "TIME_WINDOW_SECTION", "1\t0\t41340", "2\t15600\t23100"]
    actual_specs, actual_sections =
        group_specifications_and_sections([specs; sections; "EOF"])
    @test actual_specs == specs
    @test actual_sections == [sections[1:3], sections[4:6]]

    for (line, key, value) in [("NAME : Antwerp 1", "name", "Antwerp 1"),
                               ("COMMENT:'test' ", "comment", "'test'"),
                               ("COMMENT: BKS:1", "comment", "BKS:1"),
                               ("CAPACITY: 30", "capacity", 30),
                               ("CAPACITY: 30.5", "capacity", 30.5),
                               ("name: Antwerp 1", "name", "Antwerp 1")]
        @test parse_specification(line) == (key, value)
    end

    for (lines, (name, desired)) in [
        (["SERVICE_TIME_SECTION", "1  2", "2  3", "3  100"], ("service_time", [2, 3, 100])),
        (["TIME_WINDOW_SECTION", "1  2  3", "2  1  2"], ("time_window", [2 3; 1 2])),
        (["DEMAND_SECTION", "1  1.1", "2  2.2", "3  3.3"], ("demand", [1.1, 2.2, 3.3])),
        (["DEPOT_SECTION", "1", "2", "3", "-1"], ("depot", [1, 2, 3])),  # 1-based
        (["DEPOT_SECTION", "4"], ("depot", [4])),  # no end token
        (["UNKNOWN_SECTION", "1 1", "1 -1"], ("unknown", [1, -1])),
        (["VEHICLES_ALLOWED_CLIENTS_SECTION", "1 2 3 4", "2 4 5", "3 6"],
         ("vehicles_allowed_clients", [[2, 3, 4], [4, 5], [6]])),
    ]
        actual_name, actual = parse_section(lines, Dict{String,Any}())
        @test actual_name == name
        @test actual == desired
        @test eltype(actual) == eltype(desired)
    end

    instance = join(["NAME: VRPLIB", "EDGE_WEIGHT_TYPE: EXPLICIT",
                     "EDGE_WEIGHT_FORMAT: FULL_MATRIX", "EDGE_WEIGHT_SECTION",
                     "0  1", "1  0", "SERVICE_TIME_SECTION", "1  1",
                     "TIME_WINDOW_SECTION", "1  1   2", "EOF"], "\n")
    @test parse_vrplib(instance) == Dict{String,Any}(
        "name" => "VRPLIB",
        "edge_weight_type" => "EXPLICIT",
        "edge_weight_format" => "FULL_MATRIX",
        "edge_weight" => [0 1; 1 0],
        "service_time" => [1],
        "time_window" => [1 2],
    )

    instance = join(["NAME: VRPLIB", "EDGE_WEIGHT_TYPE: FLOOR_2D",
                     "NODE_COORD_SECTION", "1  0   1", "2  1   0",
                     "SERVICE_TIME_SECTION", "1  1", "2  1",
                     "TIME_WINDOW_SECTION", "1  1   2", "2  1   2", "EOF"], "\n")
    @test parse_vrplib(instance) == Dict{String,Any}(
        "name" => "VRPLIB",
        "edge_weight_type" => "FLOOR_2D",
        "edge_weight" => [0 1; 1 0],
        "node_coord" => [0 1; 1 0],
        "service_time" => [1, 1],
        "time_window" => [1 2; 1 2],
    )
    @test !haskey(parse_vrplib(instance; compute_edge_weights = false), "edge_weight")

    # Data both as specification and section.
    @test_throws ArgumentError parse_vrplib(
        join(["SERVICE_TIME: 10", "SERVICE_TIME_SECTION", "1    20", "2    20"], "\n"))

    # Specification after a section.
    @test_throws ArgumentError parse_vrplib(
        join(["NODE_COORD_SECTION", "1  20  20", "NAME: Test",
              "EDGE_WEIGHT_TYPE: EUC_2D", "EOF"], "\n"))

    @test parse_vrplib("") == Dict{String,Any}()

    # Section names may end with a colon.
    result = parse_vrplib("""
        DIMENSION: 1
        EDGE_WEIGHT_TYPE: EXACT_2D
        NODE_COORD_SECTION:
        1 1 1
        DEMAND_SECTION :
        1 10
        DEPOT_SECTION
        1
        EOF
        """)
    @test result["dimension"] == 1
    @test result["edge_weight_type"] == "EXACT_2D"
    @test result["demand"] == [10]
    @test result["node_coord"] == [1 1]
    @test result["depot"] == [1]
end

@testset "read_instance" begin
    path = tmpfile("test")
    for fmt in ["CVRPLIB", "LKH", "VRP"]
        @test_throws ArgumentError read_instance(path; instance_format = fmt)
    end

    path = tmpfile(join(VRPLIB_INSTANCE, "\n"))
    @test read_instance(path) == Dict{String,Any}(
        "name" => "VRPLIB",
        "edge_weight_type" => "EUC_2D",
        "node_coord" => [0 0; 0 1],
        "service_time" => [1],
        "time_window" => [1 2],
        "edge_weight" => [0 1; 1 0],
    )
    @test !haskey(read_instance(path; compute_edge_weights = false), "edge_weight")

    path = tmpfile(join(SOLOMON_INSTANCE, "\n"))
    @test read_instance(path; instance_format = "solomon") == SOLOMON_DESIRED
    @test !haskey(read_instance(path; instance_format = "solomon",
                                compute_edge_weights = false), "edge_weight")

    # E-n13-k4 has EXPLICIT LOWER_ROW edge weights and a known optimum of 247.
    instance = read_instance(data("E-n13-k4.vrp"))
    W = instance["edge_weight"]
    @test size(W) == (13, 13)
    @test instance["depot"] == [1]

    # Routes as in the solution file: depot is 0, customers 1..12, so node
    # `c` is matrix index `c + 1`.
    solution = read_solution(data("E-n13-k4.sol"))
    cost = sum(solution["routes"]) do route
        tour = [0; route; 0] .+ 1
        sum(W[tour[i], tour[i + 1]] for i in 1:(length(tour) - 1))
    end
    @test cost == 247 == solution["cost"]
end

@testset "read_solution" begin
    path = tmpfile(join(["Route 1 : 1 2", "Route 2 : 3 4", "Route 3 : 5",
                         "Cost : 100", "Time : 123.45", "Name : test.sol",
                         "Comment : Test."], "\n"))
    @test read_solution(path) == Dict{String,Any}(
        "routes" => [[1, 2], [3, 4], [5]],
        "cost" => 100,
        "time" => 123.45,
        "name" => "test.sol",
        "comment" => "Test.",
    )
end

@testset "write_instance" begin
    path = tmpfile()

    for (key, value, desired) in [("name", "Instance", "name: Instance"),
                                  ("DIMENSION", 100, "DIMENSION: 100"),
                                  ("VEHICLES", -10, "VEHICLES: -10"),
                                  ("CAPACITY", 10.5, "CAPACITY: 10.5"),
                                  ("EMPTY", "", "EMPTY: ")]
        write_instance(path, Dict(key => value))
        @test read(path, String) == "$desired\nEOF\n"
    end

    for (key, value, desired) in [
        ("X_SECTION", [0, 10], ["X_SECTION", "1\t0", "2\t10"]),
        ("X_SECTION", Real[0, 10.5], ["X_SECTION", "1\t0", "2\t10.5"]),
        ("X_SECTION", [], ["X_SECTION"]),
        ("Y_SECTION", [0 0; 1 1], ["Y_SECTION", "1\t0\t0", "2\t1\t1"]),
        ("Y_SECTION", [[0, 0], [1, 1]], ["Y_SECTION", "1\t0\t0", "2\t1\t1"]),
        ("Y_SECTION", [[]], ["Y_SECTION", "1\t"]),
        ("DATA_SECTION", [[1], [3, 4]], ["DATA_SECTION", "1\t1", "2\t3\t4"]),
    ]
        write_instance(path, Dict(key => value))
        @test read(path, String) == join([desired; "EOF"; ""], "\n")
    end

    write_instance(path, Dict("DEPOT_SECTION" => [1, 2]))
    @test read(path, String) == "DEPOT_SECTION\n1\n2\nEOF\n"

    write_instance(path, Dict("EDGE_WEIGHT_SECTION" => [1 1 2; 1 0 3; 1 3 0]))
    @test read(path, String) == "EDGE_WEIGHT_SECTION\n1\t1\t2\n1\t0\t3\n1\t3\t0\nEOF\n"

    instance = [
        "NAME" => "C101",
        "TYPE" => "VRPTW",
        "DIMENSION" => 4,
        "CAPACITY" => 200,
        "NODE_COORD_SECTION" => [40 50; 45 68; 45 70; 42 66],
        "DEMAND_SECTION" => [0, 10, 30, 10],
        "DEPOT_SECTION" => [1],
    ]
    desired = join(["NAME: C101", "TYPE: VRPTW", "DIMENSION: 4", "CAPACITY: 200",
                    "NODE_COORD_SECTION", "1\t40\t50", "2\t45\t68", "3\t45\t70",
                    "4\t42\t66", "DEMAND_SECTION", "1\t0", "2\t10", "3\t30", "4\t10",
                    "DEPOT_SECTION", "1", "EOF", ""], "\n")

    write_instance(path, instance)
    @test read(path, String) == desired

    # Specifications are written before sections whatever the input order.
    write_instance(path, reverse(instance))
    @test startswith(read(path, String), "CAPACITY: 200\nDIMENSION: 4\nTYPE: VRPTW\nNAME: C101\nDEPOT_SECTION")

    # Round trip.
    write_instance(path, [instance; "EDGE_WEIGHT_TYPE" => "EUC_2D"])
    roundtrip = read_instance(path)
    @test roundtrip["node_coord"] == [40 50; 45 68; 45 70; 42 66]
    @test roundtrip["demand"] == [0, 10, 30, 10]
    @test roundtrip["depot"] == [1]
    @test roundtrip["edge_weight"][1, 2] ≈ sqrt(5^2 + 18^2)
end

@testset "write_solution" begin
    path = tmpfile()

    write_solution(path, [[1, 2]])
    @test read(path, String) == "Route #1: 1 2\n"

    write_solution(path, [[1, 2], [42, 9]])
    @test read(path, String) == "Route #1: 1 2\nRoute #2: 42 9\n"

    @test_throws ArgumentError write_solution(path, [Int[]])
    @test_throws ArgumentError write_solution(path, [[1], Int[]])

    for (data, desired) in [(Dict("Cost" => 100), "Cost: 100"),
                            (Dict("Time" => 123.45), "Time: 123.45"),
                            (Dict("Distance" => -1), "Distance: -1"),
                            (Dict("name" => "test.sol"), "name: test.sol"),
                            (Dict("Vehicle types" => [1, 2, 3]), "Vehicle types: [1, 2, 3]"),
                            (Dict("Vehicle types" => (1, 3)), "Vehicle types: (1, 3)")]
        write_solution(path, [[1]], data)
        @test read(path, String) == "Route #1: 1\n$desired\n"
    end

    write_solution(path, [[1, 2], [3, 4], [5]],
                   ["Cost" => 100, "Time" => 123.45, "name" => "test.sol"])
    @test read(path, String) ==
          "Route #1: 1 2\nRoute #2: 3 4\nRoute #3: 5\nCost: 100\nTime: 123.45\nname: test.sol\n"

    # Round trip.
    write_solution(path, [[1, 2], [3]], (; cost = 42.5))
    @test read_solution(path) == Dict{String,Any}("routes" => [[1, 2], [3]], "cost" => 42.5)
end

@testset "all bundled instances and solutions" begin
    for name in VRPLIB_FILES
        instance = read_instance(data(name))
        n = instance["dimension"]
        @test size(instance["edge_weight"]) == (n, n)
        @test all(1 .<= instance["depot"] .<= n)
        @test haskey(read_solution(data(replace(name, ".vrp" => ".sol"))), "routes")
    end

    for name in ["C101.txt", "C1_2_1.txt"]
        instance = read_instance(data(name); instance_format = "solomon")
        n = size(instance["node_coord"], 1)
        @test size(instance["edge_weight"]) == (n, n)
    end
end

end  # VRPLIB.jl
