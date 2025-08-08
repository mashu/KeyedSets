```@meta
CurrentModule = KeyedSets
```

# KeyedSets

Documentation for `KeyedSets`. The latest docs are deployed from the `main` branch as stable.

## Overview

`KeyedSets` provides a type-stable, parametric `KeyedSet{S,N}` that stores unique
sequences of type `S` with associated names of type `N`. It supports set-like
operations while collecting detailed conflict information about duplicates,
same-sequence/different-name, and same-name/different-sequence situations.

## Types

- `KeyedPair{S,N}`: container of a `sequence::S` and `name::N`.
- `KeyedSet{S,N}`: mapping of sequence to name.
- `ConflictSummary{S,N}`: captures conflicts detected during operations.

## Constructors

- `KeyedSet{S,N}()` creates an empty set.
- `KeyedSet(pairs)` constructs and infers `S` and `N` from the first element.
  Elements can be `KeyedPair{S,N}` or `(sequence::S, name::N)` tuples.

## Operations

- `union(a, b)` / `union_with_conflicts(a, b)`
- `intersect(a, b)` / `intersect_with_conflicts(a, b)`
- `setdiff(a, b)` / `setdiff_with_conflicts(a, b)`

The `_with_conflicts` variants return `(result, conflicts::ConflictSummary)`. The
`Base`-overrides return only `result` and log conflicts.

## Examples

```julia
using KeyedSets

"""
DNA example: sequences as Strings, names as Strings
"""
a = KeyedSet([("ACGT", "seq1"), ("AAA", "alpha")])
b = KeyedSet([("AAA", "alpha2"), ("TTT", "beta")])

res, conf = union_with_conflicts(a, b)
collect(sequences(res))         # => ["ACGT", "AAA", "TTT"] (order not guaranteed)
res["AAA"]                      # => "alpha" (left wins)
conf.sequence_name_mismatches   # => [("AAA", "alpha", "alpha2")]
```

```@index
```

```@autodocs
Modules = [KeyedSets]
```
