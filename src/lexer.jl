# SPDX-License-Identifier: MPL-2.0
#
# Lexer. The token set is closed: anything that is not one of these kinds is
# rejected here, so quotes, backticks, `;`, `$`, `=`, `,`, `%`, `[` and every
# non-ASCII character (including homoglyphs) never reach the parser.

"""
    Token(kind, text, pos)

One lexical token. `kind` is one of `:ident :number :tilde :plus :minus :star
:colon :slash :caret :lparen :rparen :bar :eof`; `pos` is a character index.
"""
struct Token
    kind::Symbol
    text::String
    pos::Int
end

"""Longest formula accepted, in characters."""
const MAX_FORMULA_LENGTH = 4096

const _PUNCT = Dict('~' => :tilde, '+' => :plus, '-' => :minus, '*' => :star,
                    ':' => :colon, '/' => :slash, '^' => :caret,
                    '(' => :lparen, ')' => :rparen, '|' => :bar)

"""Return true when `c` is an ASCII digit."""
_isdigit(c::Char) = '0' <= c <= '9'

"""Return true when `c` may start an identifier (ASCII letter or `.`)."""
_ident_start(c::Char) = ('a' <= c <= 'z') || ('A' <= c <= 'Z') || c == '.'

"""Return true when `c` may continue an identifier."""
_ident_char(c::Char) = _ident_start(c) || _isdigit(c) || c == '_'

"""
    tokenize(s) -> Vector{Token}

Split a formula into tokens from the closed set, ending with an `:eof` token.
Any other character is a `FormulaError(:bad_char)`.
"""
function tokenize(s::AbstractString)
    chars = collect(s)
    n = length(chars)
    n > MAX_FORMULA_LENGTH &&
        throw(FormulaError(:too_long, "formula exceeds $MAX_FORMULA_LENGTH characters", 0))
    toks = Token[]
    i = 1
    while i <= n
        c = chars[i]
        if c in (' ', '\t', '\n', '\r')
            i += 1
        elseif haskey(_PUNCT, c)
            push!(toks, Token(_PUNCT[c], string(c), i))
            i += 1
        elseif _isdigit(c) || (c == '.' && i < n && _isdigit(chars[i + 1]))
            j = i
            while j <= n && _isdigit(chars[j]); j += 1; end
            if j <= n && chars[j] == '.'
                j += 1
                while j <= n && _isdigit(chars[j]); j += 1; end
            end
            push!(toks, Token(:number, String(chars[i:j-1]), i))
            i = j
        elseif _ident_start(c)
            j = i
            while j <= n && _ident_char(chars[j]); j += 1; end
            push!(toks, Token(:ident, String(chars[i:j-1]), i))
            i = j
        else
            throw(FormulaError(:bad_char, "character $(repr(c)) is not allowed in a formula", i))
        end
    end
    push!(toks, Token(:eof, "", n + 1))
    return toks
end
