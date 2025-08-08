```@meta
CurrentModule = KeyedSets
```

# KeyedSets

Documentation for [KeyedSets](https://github.com/mashu/KeyedSets.jl).

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

a = KeyedSet([("AAA", "x"), ("BBB", "y")])
b = KeyedSet([("BBB", "y2"), ("CCC", "x")])

res, conf = union_with_conflicts(a, b)
length(res)       # 3
conf.name_collisions
```

```@index
```

```@autodocs
Modules = [KeyedSets]
```
