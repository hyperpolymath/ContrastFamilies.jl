# SPDX-License-Identifier: MPL-2.0
"""
    ContrastFamilies

Parse R-style model formulas against a column whitelist, derive the contrasts
that are actually tested, and size the Benjamini–Hochberg family those tests
form — with a provenance hash for the formula as written and an equivalence
key for its canonical form.

Statistics are out of scope: this package says *which* tests form the family
and *how many* there are. Fitting models and computing p-values stays with the
caller (in MetaManifold, R via RCall).
"""
module ContrastFamilies

using SHA: sha256

export FormulaError, UnsupportedInV1, FamilyMismatch,
       Formula, parse_formula, to_string,
       ModelTerm, label, degree, expand_terms, CanonicalFormula, canonical,
       provenance_hash, equivalence_key,
       Contrast, ContrastSet, contrasts,
       BHFamily, bh_family, assert_family_size,
       derivation_report

include("errors.jl")
include("lexer.jl")
include("ast.jl")
include("parser.jl")
include("canonical.jl")
include("provenance.jl")
include("contrasts.jl")
include("family.jl")
include("report.jl")

end # module
