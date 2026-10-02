# SPDX-License-Identifier: MPL-2.0

"""
    FormulaError(code, msg, pos)

A formula, or a request derived from one, was rejected: it is malformed, names
a column outside the whitelist, or uses a construct the grammar refuses
(function calls, strings, `;`, …). `pos` is the 1-based character position in
the formula, or 0 when no single position applies.
"""
struct FormulaError <: Exception
    code::Symbol
    msg::String
    pos::Int
end

"""
    UnsupportedInV1(feature, pos)

The formula is valid R but uses a construct deliberately out of scope for v1,
such as random effects `(1 | batch)`. It is refused, never silently dropped.
"""
struct UnsupportedInV1 <: Exception
    feature::String
    pos::Int
end

"""
    FamilyMismatch(expected, got)

The number of p-values handed to a correction differs from the family size.
"""
struct FamilyMismatch <: Exception
    expected::Int
    got::Int
end

"""Print a `FormulaError` with its code, position and message."""
function Base.showerror(io::IO, e::FormulaError)
    print(io, "FormulaError(", e.code, ")")
    e.pos > 0 && print(io, " at position ", e.pos)
    print(io, ": ", e.msg)
end

"""Print an `UnsupportedInV1` naming the refused feature."""
function Base.showerror(io::IO, e::UnsupportedInV1)
    print(io, "UnsupportedInV1")
    e.pos > 0 && print(io, " at position ", e.pos)
    print(io, ": ", e.feature, " is not supported in v1")
end

"""Print a `FamilyMismatch` with both sizes."""
function Base.showerror(io::IO, e::FamilyMismatch)
    print(io, "FamilyMismatch: the family has ", e.expected, " tests but ",
          e.got, " p-values were supplied")
end
