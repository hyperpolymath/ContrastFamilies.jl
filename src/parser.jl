# SPDX-License-Identifier: MPL-2.0
#
# Recursive-descent parser. Precedence, loosest first: `~`, then `+ -`, then
# `*`, then `:`. Inside `I(...)` the usual arithmetic precedence applies.
#
# This grammar is the injection boundary: every identifier must be in the
# caller's column whitelist, and the only call allowed is `I(...)`. So
# `system("x")`, `eval(...)`, `parse(...)` and the like cannot be written.

"""Deepest parenthesis nesting accepted."""
const MAX_DEPTH = 64

"""Words R reserves; they can never name a column in a formula."""
const R_RESERVED = Set(["if", "else", "repeat", "while", "function", "for", "in",
    "next", "break", "TRUE", "FALSE", "NULL", "Inf", "NaN", "NA", "NA_integer_",
    "NA_real_", "NA_character_", "NA_complex_"])

"""Parser state: the token stream, a cursor, and the column whitelist."""
mutable struct _Parser
    toks::Vector{Token}
    i::Int
    columns::Set{Symbol}
end

"""Return the current token without consuming it."""
_peek(p::_Parser) = p.toks[p.i]

"""Return the token after the current one without consuming anything."""
_peek2(p::_Parser) = p.toks[min(p.i + 1, length(p.toks))]

"""Consume and return the current token (the final `:eof` is never passed)."""
function _next!(p::_Parser)
    t = p.toks[p.i]
    t.kind == :eof || (p.i += 1)
    return t
end

"""Describe a token for an error message."""
_describe(t::Token) = t.kind == :eof ? "end of formula" : repr(t.text)

"""Consume a token of `kind`, or throw a syntax error naming `what` was expected."""
function _expect!(p::_Parser, kind::Symbol, what::AbstractString)
    t = _peek(p)
    t.kind == kind ||
        throw(FormulaError(:syntax, "expected $what, found $(_describe(t))", t.pos))
    return _next!(p)
end

"""Throw if nesting is deeper than `MAX_DEPTH`."""
function _depth_check(p::_Parser, d::Int)
    d > MAX_DEPTH &&
        throw(FormulaError(:too_deep, "formula nests deeper than $MAX_DEPTH levels", _peek(p).pos))
    return nothing
end

"""Turn an identifier token into a whitelisted column `Symbol`, or throw."""
function _column(p::_Parser, t::Token)
    name = t.text
    name == "." && throw(UnsupportedInV1("'.' (all remaining columns)", t.pos))
    (startswith(name, "..") || name in R_RESERVED) &&
        throw(FormulaError(:reserved, "$(repr(name)) is reserved in R and cannot name a column", t.pos))
    sym = Symbol(name)
    sym in p.columns ||
        throw(FormulaError(:unknown_column, "$(repr(name)) is not one of the permitted columns", t.pos))
    return sym
end

"""
    parse_formula(s; columns) -> Formula

Parse an R-style formula such as `"y ~ group * batch + I(depth^2)"`.

`columns` is the whitelist of column names the formula may mention, normally
the columns of the data it will be applied to. Every identifier, including the
response and those inside `I(...)`, must be one of them.

Supported: `~`, `+`, `-`, `*`, `:`, parentheses, the intercept markers `0` and
`1`, and `I(...)` holding `+ - * / ^`, numbers and columns. Random effects
`(1 | g)`, `.`, and `^` or `/` outside `I()` throw `UnsupportedInV1`. Anything
else throws `FormulaError`.
"""
function parse_formula(s::AbstractString; columns)
    p = _Parser(tokenize(s), 1, Set{Symbol}(Symbol(c) for c in columns))
    lhs = nothing
    if _peek(p).kind == :ident && _peek2(p).kind == :tilde
        lhs = _column(p, _next!(p))
    end
    if _peek(p).kind != :tilde
        throw(FormulaError(:missing_tilde,
            "a formula is '[response] ~ terms' and the response must be a single column", _peek(p).pos))
    end
    _next!(p)
    rhs = _sum!(p, 0)
    t = _peek(p)
    t.kind == :eof || throw(FormulaError(:syntax, "unexpected $(_describe(t))", t.pos))
    if lhs !== nothing && lhs in _rhs_columns(rhs)
        throw(FormulaError(:response_on_rhs, "the response $(repr(string(lhs))) also appears on the right-hand side", 0))
    end
    return Formula(lhs, rhs)
end

"""Parse `[-] product (('+' | '-') product)*`."""
function _sum!(p::_Parser, d::Int)
    left = if _peek(p).kind == :minus
        _next!(p)
        FNeg(_prod!(p, d))
    else
        _prod!(p, d)
    end
    while _peek(p).kind in (:plus, :minus)
        op = _next!(p).kind
        right = _prod!(p, d)
        left = op == :plus ? FPlus(left, right) : FMinus(left, right)
    end
    return left
end

"""Parse `interaction ('*' interaction)*`."""
function _prod!(p::_Parser, d::Int)
    left = _inter!(p, d)
    while _peek(p).kind == :star
        _next!(p)
        left = FStar(left, _inter!(p, d))
    end
    return left
end

"""Parse `atom (':' atom)*`, refusing `^` and `/` outside `I()`."""
function _inter!(p::_Parser, d::Int)
    left = _atom!(p, d)
    while true
        t = _peek(p)
        if t.kind == :colon
            _next!(p)
            left = FColon(left, _atom!(p, d))
        elseif t.kind in (:caret, :slash)
            throw(UnsupportedInV1("'$(t.text)' outside I(...)", t.pos))
        else
            return left
        end
    end
end

"""Parse a column, `0`/`1`, `I(...)`, or a parenthesised sum."""
function _atom!(p::_Parser, d::Int)
    _depth_check(p, d)
    t = _next!(p)
    if t.kind == :ident
        if _peek(p).kind == :lparen
            t.text == "I" || throw(FormulaError(:function_call,
                "function calls are not allowed (only I(...)); found $(repr(t.text))", t.pos))
            _next!(p)
            e = _isum!(p, d + 1)
            _expect!(p, :rparen, "')' closing I(...)")
            return FIdentity(e)
        end
        return FVar(_column(p, t))
    elseif t.kind == :number
        t.text in ("0", "1") || throw(FormulaError(:number,
            "the number $(t.text) is only allowed inside I(...)", t.pos))
        return FInt(parse(Int, t.text))
    elseif t.kind == :lparen
        inner = _sum!(p, d + 1)
        _peek(p).kind == :bar && throw(UnsupportedInV1("random effects '( … | … )'", t.pos))
        _expect!(p, :rparen, "')'")
        return FParen(inner)
    else
        throw(FormulaError(:syntax, "unexpected $(_describe(t))", t.pos))
    end
end

"""Parse an `I()` sum: `product (('+' | '-') product)*`."""
function _isum!(p::_Parser, d::Int)
    left = _iprod!(p, d)
    while _peek(p).kind in (:plus, :minus)
        op = _next!(p).text[1]
        left = IBin(op, left, _iprod!(p, d))
    end
    return left
end

"""Parse an `I()` product: `unary (('*' | '/') unary)*`."""
function _iprod!(p::_Parser, d::Int)
    left = _iunary!(p, d)
    while _peek(p).kind in (:star, :slash)
        op = _next!(p).text[1]
        left = IBin(op, left, _iunary!(p, d))
    end
    return left
end

"""Parse `I()` unary minus, which binds looser than `^` (as in R: `-2^2 == -4`)."""
function _iunary!(p::_Parser, d::Int)
    if _peek(p).kind == :minus
        _depth_check(p, d)
        _next!(p)
        return INeg(_iunary!(p, d + 1))
    end
    return _ipow!(p, d)
end

"""Parse `I()` powers, right-associative: `a^b^c == a^(b^c)`."""
function _ipow!(p::_Parser, d::Int)
    base = _iatom!(p, d)
    if _peek(p).kind == :caret
        _next!(p)
        return IBin('^', base, _iunary!(p, d + 1))
    end
    return base
end

"""Parse an `I()` atom: a number, a column, or a parenthesised expression."""
function _iatom!(p::_Parser, d::Int)
    _depth_check(p, d)
    t = _next!(p)
    t.kind == :number && return INum(t.text)
    if t.kind == :ident
        _peek(p).kind == :lparen && throw(FormulaError(:function_call,
            "function calls are not allowed inside I(...); found $(repr(t.text))", t.pos))
        return IVar(_column(p, t))
    end
    if t.kind == :lparen
        e = _isum!(p, d + 1)
        _expect!(p, :rparen, "')'")
        return IParen(e)
    end
    throw(FormulaError(:syntax, "unexpected $(_describe(t)) inside I(...)", t.pos))
end

"""Collect every column named anywhere on a right-hand side."""
_rhs_columns(n::FNode) = _collect_columns!(Set{Symbol}(), n)

"""Add the columns under node `n` to `acc` and return `acc`."""
function _collect_columns!(acc::Set{Symbol}, n)
    if n isa FVar || n isa IVar
        push!(acc, n.name)
    elseif !(n isa FInt || n isa INum)
        for i in 1:fieldcount(typeof(n))
            f = getfield(n, i)
            (f isa FNode || f isa INode) && _collect_columns!(acc, f)
        end
    end
    return acc
end
