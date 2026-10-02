# SPDX-License-Identifier: MPL-2.0
#
# Two hashes, deliberately different:
#
# * `provenance_hash`: the formula *as written* (up to whitespace). `y ~ a + b`
#   and `y ~ b + a` get different hashes. This is the identity that goes into
#   config and result hashes, because it records what the analyst wrote.
# * `equivalence_key`: the *canonical* form. Formulas that R treats as the same
#   model share it. It answers "is this the same model?".
#
# In echo-types terms, the as-written formula is a presentation-dependent echo
# over its canonical base: many presentations, one canonical point.
#
# No claim is made that distinct presentations get distinct provenance hashes.
# That depends on SHA-256 collision resistance and is computational, not proved.

const _PROVENANCE_TAG = "contrastfamilies/formula-as-written/v1\n"
const _EQUIVALENCE_TAG = "contrastfamilies/formula-canonical/v1\n"

"""Hex SHA-256 of `s` with a `sha256:` prefix."""
_sha(s::AbstractString) = "sha256:" * bytes2hex(sha256(s))

"""
    provenance_hash(f::Formula) -> String

SHA-256 of the formula as written, ignoring whitespace (the `to_string`
spelling, under a domain-separation tag). Term order and parentheses matter.
"""
provenance_hash(f::Formula) = _sha(_PROVENANCE_TAG * to_string(f))

"""
    equivalence_key(f) -> String

SHA-256 of the canonical form (under its own tag). Equal for every formula with
the same canonical form, e.g. `y ~ a*b` and `y ~ b + a + b:a`.
"""
equivalence_key(f::Formula) = equivalence_key(canonical(f))
equivalence_key(c::CanonicalFormula) = _sha(_EQUIVALENCE_TAG * to_string(canonical(c)))
