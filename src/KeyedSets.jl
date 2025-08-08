module KeyedSets

export KeyedPair, KeyedSet,
       ConflictSummary,
       sequences,
       union_with_conflicts, intersect_with_conflicts, setdiff_with_conflicts

"""
    KeyedPair{S,N}

Pair of a sequence and its human-readable name.

Fields:
- `sequence::S`
- `name::N`
"""
struct KeyedPair{S,N}
    sequence::S
    name::N
end

"""
    KeyedSet{S,N,D<:AbstractDict{S,N}}

A collection that maps a sequence (key) to a name (value). Behaves like a set of
sequences for set-like operations, while tracking names and reporting conflicts.

Internally stores `data::D`, an `AbstractDict{S,N}` mapping `sequence => name`.
"""
struct KeyedSet{S,N,D<:AbstractDict{S,N}}
    data::D
end

# Default concrete storage
const _DefaultDict{S,N} = Dict{S,N}

"""
    KeyedSet{S,N}()
    KeyedSet{S,N}(pairs)
    KeyedSet(pairs)

Construct an empty `KeyedSet{S,N}` or from an iterable of pairs.

Accepted element forms in `pairs`:
- `KeyedPair{S,N}`
- `(sequence::S, name::N)` tuple
"""
KeyedSet{S,N}() where {S,N} = KeyedSet{S,N,_DefaultDict{S,N}}(_DefaultDict{S,N}())

KeyedSet() = KeyedSet{String,String}()

function KeyedSet{S,N}(pairs) where {S,N}
    ks = KeyedSet{S,N}()
    for p in pairs
        push!(ks, p)
    end
    return ks
end

KeyedSet(pairs::AbstractVector{<:KeyedPair{S,N}}) where {S,N} = KeyedSet{S,N}(pairs)
KeyedSet(pairs::AbstractVector{<:Tuple{S,N}}) where {S,N} = KeyedSet{S,N}(pairs)
## Intentionally no constructor from AbstractDict to avoid ambiguity with
## default field-type outer constructors during precompilation.

"""
    ConflictSummary{S,N}

Summary of conflicts detected during set-like operations.

Fields:
- `duplicates::Vector{KeyedPair{S,N}}` — same sequence and name present in both sides
- `sequence_name_mismatches::Vector{Tuple{S,N,N}}` — same sequence but different names `(sequence, left_name, right_name)`
- `name_collisions::Vector{Tuple{N,S,S}}` — same name used for different sequences `(name, left_sequence, right_sequence)`
"""
struct ConflictSummary{S,N}
    duplicates::Vector{KeyedPair{S,N}}
    sequence_name_mismatches::Vector{Tuple{S,N,N}}
    name_collisions::Vector{Tuple{N,S,S}}
end

ConflictSummary{S,N}() where {S,N} = ConflictSummary{S,N}(KeyedPair{S,N}[], Tuple{S,N,N}[], Tuple{N,S,S}[])

"""
    push!(ks::KeyedSet, kp)

Insert a `KeyedPair` or `(sequence, name)` into the set. If the sequence exists
with a different name, the existing name is kept and a message is logged.
"""
function Base.push!(ks::KeyedSet{S,N}, pair::KeyedPair{S,N}) where {S,N}
    if !haskey(ks.data, pair.sequence)
        ks.data[pair.sequence] = pair.name
    else
        existing = ks.data[pair.sequence]
        if existing == pair.name
            @info "Duplicate sequence with identical name" sequence=pair.sequence name=pair.name
        else
            @info "Sequence present with different name; keeping existing name" sequence=pair.sequence existing_name=existing incoming_name=pair.name
        end
    end
    return ks
end

Base.push!(ks::KeyedSet{S,N}, tup::Tuple{S,N}) where {S,N} = push!(ks, KeyedPair{S,N}(tup[1], tup[2]))

# Basic collection interface
Base.length(ks::KeyedSet) = length(ks.data)
Base.isempty(ks::KeyedSet) = isempty(ks.data)
Base.getindex(ks::KeyedSet{S,N}, sequence::S) where {S,N} = get(ks.data, sequence) do
    throw(KeyError(sequence))
end
Base.haskey(ks::KeyedSet{S,N}, sequence::S) where {S,N} = haskey(ks.data, sequence)

# Iterate over KeyedPair for convenience
function Base.iterate(ks::KeyedSet{S,N}) where {S,N}
    it = iterate(ks.data)
    it === nothing && return nothing
    (kv, state) = it
    return (KeyedPair{S,N}(kv[1], kv[2]), state)
end
function Base.iterate(ks::KeyedSet{S,N}, state) where {S,N}
    it = iterate(ks.data, state)
    it === nothing && return nothing
    (kv, next_state) = it
    return (KeyedPair{S,N}(kv[1], kv[2]), next_state)
end

Base.eltype(::Type{KeyedSet{S,N}}) where {S,N} = KeyedPair{S,N}
Base.collect(ks::KeyedSet{S,N}) where {S,N} = [(seq, name) for (seq, name) in ks.data]

"""
    sequences(ks)

Return an iterator over sequences contained in the set.
"""
sequences(ks::KeyedSet) = keys(ks.data)

"""
    names(ks)

Return an iterator over names stored in the set.
"""
names(ks::KeyedSet) = values(ks.data)

# Standard keys/values forwarders for collection compatibility
Base.keys(ks::KeyedSet) = keys(ks.data)
Base.values(ks::KeyedSet) = values(ks.data)

"""
    Base.empty(ks::KeyedSet)

Return a new empty `KeyedSet` with the same type parameters and backing storage
type as `ks`.
"""
Base.empty(ks::KeyedSet{S,N,D}) where {S,N,D<:AbstractDict{S,N}} =
    KeyedSet{S,N,D}(empty(ks.data))

"""
    Base.:(==)(a::KeyedSet, b::KeyedSet)

Equality is based on the set of sequences only (names are ignored).
This implementation avoids temporary set allocation.
"""
Base.:(==)(a::KeyedSet{S,N}, b::KeyedSet{S,N}) where {S,N} =
    length(a) == length(b) && all(haskey(b.data, s) for s in keys(a.data))

"""
    _name_to_sequences(ks)

Build a mapping from name to the set of sequences using that name.
"""
function _name_to_sequences(ks::KeyedSet{S,N}) where {S,N}
    inv = Dict{N, Vector{S}}()
    for (seq, nm) in ks.data
        push!(get!(inv, nm, S[]), seq)
    end
    return inv
end

"""
    union_with_conflicts(left::KeyedSet, right::KeyedSet) -> (result, conflicts)

Union by sequences. If a sequence exists on both sides with different names, the
name from `left` is kept. Conflicts are returned in `ConflictSummary`.
"""
function union_with_conflicts(left::KeyedSet{S,N}, right::KeyedSet{S,N}) where {S,N}
    result = KeyedSet{S,N}()
    sizehint!(result.data, length(left.data) + length(right.data))
    conflicts = ConflictSummary{S,N}()
    sizehint!(conflicts.duplicates, min(length(left.data), length(right.data)))
    sizehint!(conflicts.sequence_name_mismatches, min(length(left.data), length(right.data)))

    # start with left
    for (seq, nm) in left.data
        result.data[seq] = nm
    end

    # merge right
    for (seq, rn) in right.data
        if haskey(result.data, seq)
            ln = result.data[seq]
            if ln == rn
                push!(conflicts.duplicates, KeyedPair{S,N}(seq, ln))
            else
                push!(conflicts.sequence_name_mismatches, (seq, ln, rn))
                # keep left name (already present)
            end
        else
            result.data[seq] = rn
        end
    end

    # detect same-name-different-sequence collisions across the inputs
    inv_left = _name_to_sequences(left)
    inv_right = _name_to_sequences(right)
    common_names = intersect(keys(inv_left), keys(inv_right))
    for nm in common_names
        for ls in inv_left[nm]
            for rs in inv_right[nm]
                if ls != rs
                    push!(conflicts.name_collisions, (nm, ls, rs))
                end
            end
        end
    end

    return result, conflicts
end

"""
    intersect_with_conflicts(left::KeyedSet, right::KeyedSet)

Intersection by sequences. If names differ, the name from `left` is used.
Conflicts are returned in `ConflictSummary`.
"""
function intersect_with_conflicts(left::KeyedSet{S,N}, right::KeyedSet{S,N}) where {S,N}
    result = KeyedSet{S,N}()
    sizehint!(result.data, min(length(left.data), length(right.data)))
    conflicts = ConflictSummary{S,N}()
    sizehint!(conflicts.duplicates, min(length(left.data), length(right.data)))
    sizehint!(conflicts.sequence_name_mismatches, min(length(left.data), length(right.data)))

    for (seq, ln) in left.data
        if haskey(right.data, seq)
            rn = right.data[seq]
            if ln == rn
                result.data[seq] = ln
                push!(conflicts.duplicates, KeyedPair{S,N}(seq, ln))
            else
                result.data[seq] = ln
                push!(conflicts.sequence_name_mismatches, (seq, ln, rn))
            end
        end
    end

    # detect same-name-different-sequence in the intersection scope is not
    # applicable because intersection is by identical sequences only
    inv_left = _name_to_sequences(left)
    inv_right = _name_to_sequences(right)
    common_names = intersect(keys(inv_left), keys(inv_right))
    for nm in common_names
        for ls in inv_left[nm]
            for rs in inv_right[nm]
                if ls != rs
                    push!(conflicts.name_collisions, (nm, ls, rs))
                end
            end
        end
    end

    return result, conflicts
end

"""
    setdiff_with_conflicts(left::KeyedSet, right::KeyedSet)

Set difference by sequences: elements in `left` not in `right`. When a name from
`left` exists in `right` but for a different sequence, a name collision is
reported.
"""
function setdiff_with_conflicts(left::KeyedSet{S,N}, right::KeyedSet{S,N}) where {S,N}
    result = KeyedSet{S,N}()
    sizehint!(result.data, length(left.data))
    conflicts = ConflictSummary{S,N}()
    sizehint!(conflicts.duplicates, min(length(left.data), length(right.data)))
    sizehint!(conflicts.sequence_name_mismatches, min(length(left.data), length(right.data)))

    inv_right = _name_to_sequences(right)

    for (seq, ln) in left.data
        if !haskey(right.data, seq)
            result.data[seq] = ln
            if haskey(inv_right, ln)
                for rs in inv_right[ln]
                    if rs != seq
                        push!(conflicts.name_collisions, (ln, seq, rs))
                    end
                end
            end
        else
            rn = right.data[seq]
            if ln == rn
                push!(conflicts.duplicates, KeyedPair{S,N}(seq, ln))
            else
                push!(conflicts.sequence_name_mismatches, (seq, ln, rn))
            end
        end
    end

    return result, conflicts
end

# Base set-like overrides that return only the result and log conflicts
function Base.union(a::KeyedSet{S,N}, b::KeyedSet{S,N}) where {S,N}
    res, conf = union_with_conflicts(a, b)
    _log_conflicts(conf)
    return res
end

function Base.intersect(a::KeyedSet{S,N}, b::KeyedSet{S,N}) where {S,N}
    res, conf = intersect_with_conflicts(a, b)
    _log_conflicts(conf)
    return res
end

function Base.setdiff(a::KeyedSet{S,N}, b::KeyedSet{S,N}) where {S,N}
    res, conf = setdiff_with_conflicts(a, b)
    _log_conflicts(conf)
    return res
end

function _log_conflicts(conf::ConflictSummary)
    for kp in conf.duplicates
        @info "Duplicate sequence with identical name present on both sides" sequence=kp.sequence name=kp.name
    end
    for (seq, ln, rn) in conf.sequence_name_mismatches
        @info "Same sequence has different names" sequence=seq left_name=ln right_name=rn
    end
    for (nm, ls, rs) in conf.name_collisions
        @info "Same name assigned to different sequences across inputs" name=nm left_sequence=ls right_sequence=rs
    end
    return nothing
end

function Base.show(io::IO, ks::KeyedSet{S,N}) where {S,N}
    print(io, "KeyedSet{$S,$N}(size=", length(ks), ")")
end

end # module
