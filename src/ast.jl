# SPDX-License-Identifier: MPL-2.0
#
# The as-written syntax tree. Parentheses are kept as nodes, so the tree records
# how the formula was written (up to whitespace); `canonical` forgets that.

"""Supertype of every node on the right-hand side of an as-written formula."""
abstract type FNode end

"""Supertype of every node inside an `I(...)` arithmetic expression."""
abstract type INode end

"""A column reference (already checked against the whitelist)."""
struct FVar <: FNode
    name::Symbol
end

"""The intercept markers `0` and `1`."""
struct FInt <: FNode
    value::Int
end

"""`I(expr)`: arithmetic on columns, treated as one factor."""
struct FIdentity <: FNode
    expr::INode
end

"""`l + r`"""
struct FPlus <: FNode
    l::FNode
    r::FNode
end

"""`l - r`"""
struct FMinus <: FNode
    l::FNode
    r::FNode
end

"""Leading unary minus, as in `-1 + a`."""
struct FNeg <: FNode
    x::FNode
end

"""`l * r` (crossing: `l + r + l:r`)."""
struct FStar <: FNode
    l::FNode
    r::FNode
end

"""`l:r` (interaction)."""
struct FColon <: FNode
    l::FNode
    r::FNode
end

"""`( x )`"""
struct FParen <: FNode
    x::FNode
end

"""A numeric literal inside `I(...)`, kept as written."""
struct INum <: INode
    text::String
end

"""A column reference inside `I(...)`."""
struct IVar <: INode
    name::Symbol
end

"""A binary arithmetic operation (`+ - * / ^`) inside `I(...)`."""
struct IBin <: INode
    op::Char
    l::INode
    r::INode
end

"""Unary minus inside `I(...)`."""
struct INeg <: INode
    x::INode
end

"""Parentheses inside `I(...)`."""
struct IParen <: INode
    x::INode
end

"""
    Formula(lhs, rhs)

An as-written formula: an optional response column and a right-hand-side tree.
Two `Formula`s are equal exactly when they were written the same way, ignoring
whitespace. That presentation is what `provenance_hash` identifies.
"""
struct Formula
    lhs::Union{Nothing,Symbol}
    rhs::FNode
end

"""Structural equality, field by field, on syntax-tree nodes of the same type."""
Base.:(==)(a::T, b::T) where {T<:Union{FNode,INode,Formula}} =
    all(getfield(a, i) == getfield(b, i) for i in 1:fieldcount(T))

"""Structural hash consistent with `==` on syntax-tree nodes."""
Base.hash(a::T, h::UInt) where {T<:Union{FNode,INode,Formula}} =
    foldl((acc, i) -> hash(getfield(a, i), acc), 1:fieldcount(T); init = hash(T, h))

"""
    to_string(f) -> String

Render a formula, node, or canonical formula in a normalised spelling: single
spaces around `~ + - *` (and `/` in `I()`), none around `:` and `^`. Parsing the
result with the same columns gives back an equal tree.
"""
to_string(f::Formula) =
    (f.lhs === nothing ? "~ " : string(f.lhs, " ~ ")) * to_string(f.rhs)

to_string(n::FVar) = string(n.name)
to_string(n::FInt) = string(n.value)
to_string(n::FIdentity) = "I(" * to_string(n.expr) * ")"
to_string(n::FPlus) = to_string(n.l) * " + " * to_string(n.r)
to_string(n::FMinus) = to_string(n.l) * " - " * to_string(n.r)
to_string(n::FNeg) = "-" * to_string(n.x)
to_string(n::FStar) = to_string(n.l) * " * " * to_string(n.r)
to_string(n::FColon) = to_string(n.l) * ":" * to_string(n.r)
to_string(n::FParen) = "(" * to_string(n.x) * ")"

to_string(n::INum) = n.text
to_string(n::IVar) = string(n.name)
to_string(n::IBin) = n.op == '^' ? to_string(n.l) * "^" * to_string(n.r) :
                                   to_string(n.l) * " " * n.op * " " * to_string(n.r)
to_string(n::INeg) = "-" * to_string(n.x)
to_string(n::IParen) = "(" * to_string(n.x) * ")"

"""Show a `Formula` as its normalised spelling."""
Base.show(io::IO, f::Formula) = print(io, "Formula(\"", to_string(f), "\")")
