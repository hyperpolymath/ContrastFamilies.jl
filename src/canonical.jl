# SPDX-License-Identifier: MPL-2.0
#
# Term expansion and canonical form. Expansion follows R's `terms()`: `+` and
# `-` apply left to right, so `-a + a` keeps `a`, and the last intercept marker
# wins (`0 + a + 1` has an intercept). Checked against R 4.5.0.

"""
    ModelTerm(factors)

One model term: the set of factors it multiplies, stored sorted and without
duplicates. So `a:b`, `b:a` and `a:b:a` are the same term, as in R. A factor
is a column name or an `I(...)` expression in normalised spelling.
"""
struct ModelTerm
    factors::Vector{String}
    ModelTerm(fs) = new(sort!(unique!(String[string(f) for f in fs])))
end

"""Two terms are equal when they have the same factor set."""
Base.:(==)(a::ModelTerm, b::ModelTerm) = a.factors == b.factors

"""Hash consistent with `==` on `ModelTerm`."""
Base.hash(a::ModelTerm, h::UInt) = hash(a.factors, hash(:ModelTerm, h))

"""Show a term by its label."""
Base.show(io::IO, t::ModelTerm) = print(io, "ModelTerm(\"", label(t), "\")")

"""The term's label in R spelling: its factors joined by `:`."""
label(t::ModelTerm) = join(t.factors, ":")

"""The term's interaction order: 1 for a main effect, 2 for `a:b`, and so on."""
degree(t::ModelTerm) = length(t.factors)

"""Append the terms of `b` not already in `a`, keeping first-appearance order."""
_union(a::Vector{ModelTerm}, b::Vector{ModelTerm}) = unique!(vcat(a, b))

"""Every pairwise product of terms from `a` and `b`, deduplicated."""
_cross(a::Vector{ModelTerm}, b::Vector{ModelTerm}) =
    unique!([ModelTerm(vcat(x.factors, y.factors)) for x in a for y in b])

"""
    _termset(node) -> Vector{ModelTerm}

The terms a parenthesised or interaction sub-expression generates, in order of
first appearance. Intercept markers and unary minus are refused here: they only
mean something at the top level.
"""
_termset(n::FVar) = [ModelTerm([string(n.name)])]
_termset(n::FIdentity) = [ModelTerm([to_string(n)])]
_termset(n::FParen) = _termset(n.x)
_termset(n::FPlus) = _union(_termset(n.l), _termset(n.r))
_termset(n::FMinus) = setdiff(_termset(n.l), _termset(n.r))
_termset(n::FColon) = _cross(_termset(n.l), _termset(n.r))
function _termset(n::FStar)
    a, b = _termset(n.l), _termset(n.r)
    return _union(_union(a, b), _cross(a, b))
end
_termset(n::FInt) = throw(UnsupportedInV1(
    "intercept marker '$(n.value)' inside parentheses or an interaction", 0))
_termset(n::FNeg) = throw(UnsupportedInV1(
    "unary '-' inside parentheses or an interaction", 0))

"""Flatten the top-level sum into `(sign, summand)` pairs, left to right."""
_summands(n::FPlus, s::Int) = vcat(_summands(n.l, s), _summands(n.r, s))
_summands(n::FMinus, s::Int) = vcat(_summands(n.l, s), _summands(n.r, -s))
_summands(n::FNeg, s::Int) = _summands(n.x, -s)
_summands(n::FNode, s::Int) = Tuple{Int,FNode}[(s, n)]

"""
    expand_terms(f) -> (intercept::Bool, terms::Vector{ModelTerm})

Expand a formula's right-hand side into an intercept flag and its model terms,
in order of first appearance. `a*b` becomes `a + b + a:b`, `(a + b):c` becomes
`a:c + b:c`, and `+`/`-` apply left to right as in R's `terms()`.
"""
function expand_terms(f::Formula)
    intercept = true
    terms = ModelTerm[]
    for (sign, node) in _summands(f.rhs, 1)
        if node isa FInt
            intercept = node.value == 1 ? sign > 0 : sign < 0
        else
            ts = _termset(node)
            terms = sign > 0 ? _union(terms, ts) : setdiff(terms, ts)
        end
    end
    return (intercept = intercept, terms = terms)
end

"""
    CanonicalFormula(lhs, intercept, terms)

The representative of a formula's equivalence class: response, intercept flag,
and the expanded terms sorted by degree, then by factor names. Formulas that
R's `terms()` treats as the same model have equal canonical forms.
"""
struct CanonicalFormula
    lhs::Union{Nothing,Symbol}
    intercept::Bool
    terms::Vector{ModelTerm}
end

"""Canonical formulas are equal when response, intercept and terms all agree."""
Base.:(==)(a::CanonicalFormula, b::CanonicalFormula) =
    a.lhs == b.lhs && a.intercept == b.intercept && a.terms == b.terms

"""Hash consistent with `==` on `CanonicalFormula`."""
Base.hash(a::CanonicalFormula, h::UInt) =
    hash(a.terms, hash(a.intercept, hash(a.lhs, hash(:CanonicalFormula, h))))

"""Show a canonical formula by its spelling."""
Base.show(io::IO, c::CanonicalFormula) = print(io, "CanonicalFormula(\"", to_string(c), "\")")

"""Sort key for terms: degree first, then the factor names."""
_termkey(t::ModelTerm) = (degree(t), t.factors)

"""
    canonical(f) -> CanonicalFormula

The canonical form of a formula. It is idempotent:
`canonical(canonical(f)) == canonical(f)`.
"""
function canonical(f::Formula)
    e = expand_terms(f)
    return CanonicalFormula(f.lhs, e.intercept, sort(e.terms; by = _termkey))
end
canonical(c::CanonicalFormula) =
    CanonicalFormula(c.lhs, c.intercept, sort(unique(c.terms); by = _termkey))

"""
Render a canonical formula, e.g. `y ~ a + b + a:b`. Without an intercept it
starts with `0 + `; an empty model is `~ 1` or `~ 0`.
"""
function to_string(c::CanonicalFormula)
    head = c.lhs === nothing ? "~ " : string(c.lhs, " ~ ")
    labels = label.(c.terms)
    body = if isempty(labels)
        c.intercept ? "1" : "0"
    else
        (c.intercept ? "" : "0 + ") * join(labels, " + ")
    end
    return head * body
end
