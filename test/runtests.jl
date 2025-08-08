using KeyedSets
using Test

@testset "KeyedPair and KeyedSet basics" begin
    kp = KeyedPair("ACGT", "seq1")
    @test kp.sequence == "ACGT"
    @test kp.name == "seq1"

    ks = KeyedSet{String,String}()
    push!(ks, kp)
    @test length(ks) == 1
    @test ks["ACGT"] == "seq1"
    @test haskey(ks, "ACGT")
    @test !isempty(ks)
    @test_throws KeyError ks["TTTT"]

    # duplicate identical
    push!(ks, ("ACGT", "seq1"))
    @test length(ks) == 1

    # duplicate with different name keeps first
    push!(ks, ("ACGT", "alt"))
    @test ks["ACGT"] == "seq1"
end

@testset "Union with conflicts" begin
    a = KeyedSet([("AAA", "x"), ("BBB", "y")])
    b = KeyedSet([("BBB", "y"), ("CCC", "z"), ("AAA", "x2")])

    res, conf = union_with_conflicts(a, b)
    @test Set(sequences(res)) == Set(["AAA","BBB","CCC"]) 
    @test res["AAA"] == "x" # left preferred

    # conflicts
    @test any(kp -> kp.sequence == "BBB" && kp.name == "y", conf.duplicates)
    @test any(t -> t[1] == "AAA" && t[2] == "x" && t[3] == "x2", conf.sequence_name_mismatches)
end

@testset "Intersection with conflicts" begin
    a = KeyedSet([("AAA", "x"), ("BBB", "y")])
    b = KeyedSet([("BBB", "y2"), ("AAA", "x")])

    res, conf = intersect_with_conflicts(a, b)
    @test Set(sequences(res)) == Set(["AAA","BBB"]) 
    @test res["AAA"] == "x"
    @test res["BBB"] == "y" # left chosen

    @test any(kp -> kp.sequence == "AAA" && kp.name == "x", conf.duplicates)
    @test any(t -> t[1] == "BBB" && t[2] == "y" && t[3] == "y2", conf.sequence_name_mismatches)
end

@testset "Setdiff with conflicts and name collisions" begin
    a = KeyedSet([("AAA", "x"), ("BBB", "y"), ("DDD", "n")])
    b = KeyedSet([("BBB", "y2"), ("CCC", "x"), ("EEE", "n")])

    res, conf = setdiff_with_conflicts(a, b)
    @test Set(sequences(res)) == Set(["AAA", "DDD"]) 
    @test res["AAA"] == "x"
    @test res["DDD"] == "n"

    # sequence AAA name x collides with name used by sequence CCC in right
    @test any(t -> t[1] == "x" && t[2] == "AAA" && t[3] == "CCC", conf.name_collisions)
    # sequence DDD name n collides with EEE in right
    @test any(t -> t[1] == "n" && t[2] == "DDD" && t[3] == "EEE", conf.name_collisions)
    # BBB present in both with different name -> mismatch not included in result
    @test any(t -> t[1] == "BBB" && t[2] == "y" && t[3] == "y2", conf.sequence_name_mismatches)
end

@testset "Type parameters and inference" begin
    ks = KeyedSet([(1, :a), (2, :b)])
    _is_Int_Sym(::KeyedSet{Int,Symbol}) = true
    _is_Int_Sym(::KeyedSet) = false
    @test _is_Int_Sym(ks)
    push!(ks, (2, :b))
    @test length(ks) == 2
end

@testset "names, keys, values, collect, iteration" begin
    ks = KeyedSet([("A","n1"), ("B","n2")])
    @test Set(KeyedSets.names(ks)) == Set(["n1","n2"]) # module-qualified to avoid Base.names
    @test Set(collect(values(ks))) == Set(["n1","n2"]) # Base.values forwarder
    @test Set(collect(keys(ks))) == Set(["A","B"]) # Base.keys forwarder
    @test Set(collect(sequences(ks))) == Set(["A","B"]) # helper
    # iteration yields KeyedPair
    pairs = [(kp.sequence, kp.name) for kp in ks]
    @test Set(pairs) == Set([("A","n1"), ("B","n2")])
    # collect returns tuples
    @test Set(collect(ks)) == Set([("A","n1"), ("B","n2")])
end

@testset "equality ignores names" begin
    a = KeyedSet([("X","n1"), ("Y","n2")])
    b = KeyedSet([("Y","m2"), ("X","m1")])
    c = KeyedSet([("X","n1"), ("Z","n3")])
    @test a == b
    @test !(a == c)
end

@testset "Base set operations (wrappers) and empty" begin
    a = KeyedSet([("AAA","x"), ("BBB","y")])
    b = KeyedSet([("BBB","y2"), ("CCC","x")])
    # union wrapper
    ur = union(a, b)
    @test Set(sequences(ur)) == Set(["AAA","BBB","CCC"]) 
    # intersect wrapper
    ir = intersect(a, b)
    @test Set(sequences(ir)) == Set(["BBB"]) 
    # setdiff wrapper
    dr = setdiff(a, b)
    @test Set(sequences(dr)) == Set(["AAA"]) 
    # empty
    e = empty(a)
    @test isempty(e)
    _same_params(::KeyedSet{String,String}) = true
    _same_params(::KeyedSet) = false
    @test _same_params(e)
end

@testset "show formatting" begin
    ks = KeyedSet([("AAA","x")])
    s = sprint(show, ks)
    @test occursin("KeyedSet{", s)
    @test occursin("size=1", s)
end
