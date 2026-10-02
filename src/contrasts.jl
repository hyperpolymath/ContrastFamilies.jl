# SPDX-License-Identifier: MPL-2.0
#
# Contrasts: the explicit comparisons tested for one categorical factor. Each
# contrast is a named weight vector over the factor's levels (weights sum to 0).
# Reference levels are always explicit, never inferred from data order.

"""
    Contrast(factor, name, weights)

One tested comparison on `factor`, e.g. `"treated - control"` with weights
`[-1, 1, 0]` over the factor's levels.
"""
struct Contrast
    factor::Symbol
    name::String
    weights::Vector{Int}
end

"""Contrasts are equal when factor, name and weights all agree."""
Base.:(==)(a::Contrast, b::Contrast) =
    a.factor == b.factor && a.name == b.name && a.weights == b.weights

"""Hash consistent with `==` on `Contrast`."""
Base.hash(a::Contrast, h::UInt) = hash(a.weights, hash(a.name, hash(a.factor, h)))

"""
    ContrastSet

The contrasts derived for one factor of one formula: the levels, the scheme
(`:treatment` or `:pairwise`), the reference level (treatment only), the
contrasts, and the `equivalence_key` of the formula they were derived from.
"""
struct ContrastSet
    factor::Symbol
    levels::Vector{String}
    scheme::Symbol
    reference::Union{Nothing,String}
    contrasts::Vector{Contrast}
    equivalence::String
end

"""Number of contrasts in the set."""
Base.length(s::ContrastSet) = length(s.contrasts)

"""
    contrasts(f, factor; levels, scheme = :treatment, reference = nothing) -> ContrastSet

Derive the contrasts tested for `factor`, which must be a main-effect term of
`f`'s canonical form.

* `:treatment` compares every other level with `reference`, which is required:
  k − 1 contrasts named `"level - reference"`.
* `:pairwise` compares every pair `levels[i] < levels[j]` (by position):
  k(k − 1)/2 contrasts named `"levels[j] - levels[i]"`. No reference is taken.

`levels` must hold at least two distinct names.
"""
function contrasts(f::Formula, factor; levels, scheme::Symbol = :treatment,
                   reference = nothing)
    fac = Symbol(factor)
    c = canonical(f)
    ModelTerm([string(fac)]) in c.terms || throw(FormulaError(:not_a_main_effect,
        "$(repr(string(fac))) is not a main-effect term of $(repr(to_string(c)))", 0))
    lv = String[string(l) for l in levels]
    length(lv) >= 2 || throw(FormulaError(:levels,
        "a factor needs at least two levels to have contrasts; got $(length(lv))", 0))
    allunique(lv) || throw(FormulaError(:levels, "levels must be distinct", 0))
    k = length(lv)
    cs = Contrast[]
    if scheme === :treatment
        reference === nothing && throw(FormulaError(:reference,
            "the :treatment scheme needs an explicit reference level", 0))
        ref = string(reference)
        r = findfirst(==(ref), lv)
        r === nothing && throw(FormulaError(:reference,
            "reference $(repr(ref)) is not one of the levels", 0))
        for j in 1:k
            j == r && continue
            w = zeros(Int, k); w[j] = 1; w[r] = -1
            push!(cs, Contrast(fac, lv[j] * " - " * ref, w))
        end
        refout = ref
    elseif scheme === :pairwise
        reference === nothing || throw(FormulaError(:reference,
            "the :pairwise scheme takes no reference level", 0))
        for i in 1:k-1, j in i+1:k
            w = zeros(Int, k); w[j] = 1; w[i] = -1
            push!(cs, Contrast(fac, lv[j] * " - " * lv[i], w))
        end
        refout = nothing
    else
        throw(FormulaError(:scheme, "unknown contrast scheme $(repr(scheme)); use :treatment or :pairwise", 0))
    end
    return ContrastSet(fac, lv, scheme, refout, cs, equivalence_key(c))
end
