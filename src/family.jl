# SPDX-License-Identifier: MPL-2.0
#
# The Benjamini–Hochberg family: every (feature, contrast) pair is one test, so
# m = n_features × n_contrasts. A `BHFamily` computes m itself and carries how it
# was derived, so a caller cannot hand a correction a smaller m by accident.
# Using too small an m is anti-conservative, never conservative.

"""
    BHFamily

The family of tests a Benjamini–Hochberg correction must be applied over.
Fields: `n_features`, `n_contrasts`, `m` (their product), the formula's
`provenance` hash and `equivalence` key, and the `contrast_names` in order.
Build one with `bh_family`; the constructor checks `m` itself.
"""
struct BHFamily
    n_features::Int
    n_contrasts::Int
    m::Int
    provenance::String
    equivalence::String
    contrast_names::Vector{String}
    function BHFamily(n_features::Integer, names::Vector{String},
                      provenance::String, equivalence::String)
        n_features >= 1 || throw(ArgumentError("n_features must be at least 1; got $n_features"))
        isempty(names) && throw(ArgumentError("a family needs at least one contrast"))
        nc = length(names)
        return new(Int(n_features), nc, Base.checked_mul(Int(n_features), nc),
                   provenance, equivalence, names)
    end
end

"""
    bh_family(f, sets::ContrastSet...; n_features) -> BHFamily

The BH family for testing every contrast in `sets` on each of `n_features`
features (taxa, genes, …) under formula `f`. Every set must come from a formula
with `f`'s equivalence key, and no factor may appear twice.

    m = n_features × Σ length(set)
"""
function bh_family(f::Formula, sets::ContrastSet...; n_features::Integer)
    isempty(sets) && throw(ArgumentError("bh_family needs at least one ContrastSet"))
    key = equivalence_key(f)
    seen = Set{Symbol}()
    names = String[]
    for s in sets
        s.equivalence == key || throw(FormulaError(:formula_mismatch,
            "contrasts for $(repr(string(s.factor))) were derived from a different formula", 0))
        s.factor in seen && throw(FormulaError(:duplicate_factor,
            "factor $(repr(string(s.factor))) appears in more than one ContrastSet", 0))
        push!(seen, s.factor)
        append!(names, (string(s.factor, ": ", c.name) for c in s.contrasts))
    end
    return BHFamily(n_features, names, provenance_hash(f), key)
end

"""
    assert_family_size(fam, n::Integer)
    assert_family_size(fam, pvalues::AbstractVector)

Throw `FamilyMismatch` unless `n` (or the number of p-values) equals `fam.m`.
Returns `nothing` on success.
"""
function assert_family_size(fam::BHFamily, n::Integer)
    n == fam.m || throw(FamilyMismatch(fam.m, Int(n)))
    return nothing
end
assert_family_size(fam::BHFamily, p::AbstractVector) = assert_family_size(fam, length(p))

"""Show a family by its size and derivation."""
Base.show(io::IO, b::BHFamily) =
    print(io, "BHFamily(m = ", b.m, " = ", b.n_features, " × ", b.n_contrasts, ")")
