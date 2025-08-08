# KeyedSets

[![Stable Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://mashu.github.io/KeyedSets.jl/stable/)
[![Build Status](https://github.com/mashu/KeyedSets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/mashu/KeyedSets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/mashu/KeyedSets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/mashu/KeyedSets.jl)

Type-stable keyed collection `KeyedSet{S,N}` that stores unique sequences of type `S`
with associated names of type `N`. Set-like operations (union/intersect/setdiff)
preserve sequences while reporting conflicts, such as same sequence with different
names or same name for different sequences.

## Quick example (DNA sequences)

```julia
using KeyedSets

# Each sequence (String) is stored once, with an associated name (String)
a = KeyedSet([("ACGT", "seq1"), ("AAA", "alpha")])
b = KeyedSet([("AAA", "alpha2"), ("TTT", "beta")])

res, conf = union_with_conflicts(a, b)

# Sequences in the union
collect(sequences(res))            # => ["ACGT", "AAA", "TTT"] (order not guaranteed)

# Name kept from the left side when names differ for the same sequence
res["AAA"]                         # => "alpha"

# Conflicts detected
conf.sequence_name_mismatches      # => [("AAA", "alpha", "alpha2")]
```
