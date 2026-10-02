# SPDX-License-Identifier: MPL-2.0
#
# The derivation report: a plain, human-readable record of how a formula became
# a family of tests. Markdown for people, JSON for machines. No external format
# or identifier service is involved.

"""
    derivation_report(f, sets::ContrastSet...; n_features = nothing, format = :markdown) -> String

Describe how `f` was read: the formula as written and in canonical form, both
hashes, intercept, expanded terms, each factor's contrasts and, when
`n_features` is given, the BH family size with its arithmetic
(e.g. `1500 × 6 = 9000`). `format` is `:markdown` or `:json`.
"""
function derivation_report(f::Formula, sets::ContrastSet...;
                           n_features::Union{Nothing,Integer} = nothing,
                           format::Symbol = :markdown)
    c = canonical(f)
    fam = n_features === nothing || isempty(sets) ? nothing :
          bh_family(f, sets...; n_features = n_features)
    if format === :markdown
        return _report_markdown(f, c, sets, fam)
    elseif format === :json
        return _report_json(f, c, sets, fam)
    end
    throw(ArgumentError("unknown report format $(repr(format)); use :markdown or :json"))
end

"""Escape characters that Markdown would interpret, for level and factor names."""
_md(s::AbstractString) = replace(s, r"([\\`*_{}\[\]()#+\-.!|<>~])" => s"\\\1")

"""Build the Markdown report."""
function _report_markdown(f, c, sets, fam)
    io = IOBuffer()
    println(io, "# Formula derivation report\n")
    println(io, "| | |\n|---|---|")
    println(io, "| As written | `", to_string(f), "` |")
    println(io, "| Canonical | `", to_string(c), "` |")
    println(io, "| Provenance hash | `", provenance_hash(f), "` |")
    println(io, "| Equivalence key | `", equivalence_key(c), "` |")
    println(io, "| Intercept | ", c.intercept ? "yes" : "no", " |\n")
    println(io, "## Expanded terms\n")
    isempty(c.terms) && println(io, "_(none)_")
    for t in c.terms
        println(io, "- `", label(t), "` (degree ", degree(t), ")")
    end
    for s in sets
        println(io, "\n## Contrasts for `", s.factor, "`\n")
        println(io, "Scheme: ", s.scheme,
                s.reference === nothing ? "" : ", reference level " * _md(s.reference),
                ". Levels: ", join(_md.(s.levels), ", "), ". Count: ", length(s), ".\n")
        for ct in s.contrasts
            println(io, "- ", _md(ct.name), " — weights `[", join(ct.weights, ", "), "]`")
        end
    end
    if fam !== nothing
        println(io, "\n## Benjamini–Hochberg family\n")
        println(io, "m = n_features × n_contrasts = ", fam.n_features, " × ",
                fam.n_contrasts, " = ", fam.m)
    end
    return String(take!(io))
end

"""Build the JSON report."""
function _report_json(f, c, sets, fam)
    obj = (
        as_written = to_string(f),
        canonical = to_string(c),
        provenance_hash = provenance_hash(f),
        equivalence_key = equivalence_key(c),
        intercept = c.intercept,
        terms = [label(t) for t in c.terms],
        contrasts = [(factor = s.factor, scheme = s.scheme, reference = s.reference,
                      levels = s.levels,
                      contrasts = [(name = ct.name, weights = ct.weights) for ct in s.contrasts])
                     for s in sets],
        family = fam === nothing ? nothing :
                 (n_features = fam.n_features, n_contrasts = fam.n_contrasts, m = fam.m),
    )
    io = IOBuffer()
    _json(io, obj)
    return String(take!(io))
end

"""Write `s` as a JSON string literal, escaping quotes, backslashes and control characters."""
function _json(io::IO, s::AbstractString)
    print(io, '"')
    for ch in s
        if ch == '"'
            print(io, "\\\"")
        elseif ch == '\\'
            print(io, "\\\\")
        elseif ch == '\n'
            print(io, "\\n")
        elseif ch == '\r'
            print(io, "\\r")
        elseif ch == '\t'
            print(io, "\\t")
        elseif ch < ' '
            print(io, "\\u", string(UInt16(ch); base = 16, pad = 4))
        else
            print(io, ch)
        end
    end
    print(io, '"')
end
_json(io::IO, x::Symbol) = _json(io, string(x))
_json(io::IO, x::Bool) = print(io, x ? "true" : "false")
_json(io::IO, x::Integer) = print(io, x)
_json(io::IO, ::Nothing) = print(io, "null")

"""Write a vector or tuple as a JSON array."""
function _json(io::IO, v::Union{AbstractVector,Tuple})
    print(io, '[')
    for (i, x) in enumerate(v)
        i > 1 && print(io, ',')
        _json(io, x)
    end
    print(io, ']')
end

"""Write a NamedTuple as a JSON object, keys in declaration order."""
function _json(io::IO, nt::NamedTuple)
    print(io, '{')
    for (i, k) in enumerate(keys(nt))
        i > 1 && print(io, ',')
        _json(io, string(k))
        print(io, ':')
        _json(io, nt[k])
    end
    print(io, '}')
end
