<!-- SPDX-License-Identifier: MPL-2.0 -->
# ContrastFamilies.jl

Parse an R-style model formula against a column whitelist. Derive the contrasts that are actually tested. Size the Benjamini–Hochberg family those tests form, so that a correction cannot be run over the wrong *m*.

```julia
using ContrastFamilies

f  = parse_formula("abundance ~ group + batch"; columns = names(df))
g  = contrasts(f, :group; levels = ["A", "B", "C", "D"], scheme = :pairwise)  # 6 contrasts
fam = bh_family(f, g; n_features = 1500)        # BHFamily(m = 9000 = 1500 × 6)
assert_family_size(fam, pvalues)                # throws FamilyMismatch unless length == 9000
print(derivation_report(f, g; n_features = 1500))
```

The package does no statistics. It says *which* tests form the family and *how many* there are. Fitting the models and computing the p-values stays with the caller.

## What it provides

| Function | Purpose |
|---|---|
| `parse_formula(s; columns)` | Parse `~ + - * : ( ) 0 1 I(...)`. Every identifier must be in `columns`. |
| `to_string(f)` | Normalised spelling. Parsing it again gives an equal tree. |
| `expand_terms`, `canonical` | Term expansion as in R's `terms()`: `+`/`-` apply left to right, and the last intercept marker wins. The canonical form sorts terms by degree, then by name. |
| `provenance_hash(f)` | SHA-256 of the formula **as written**, with whitespace ignored. `y ~ a + b` and `y ~ b + a` differ. |
| `equivalence_key(f)` | SHA-256 of the canonical form. It is equal for every presentation of the same model. |
| `contrasts(f, factor; levels, scheme, reference)` | `:treatment` gives k − 1 contrasts against an **explicit** reference. `:pairwise` gives k(k − 1)/2. |
| `bh_family(f, sets...; n_features)` | m = n_features × Σ\|contrasts\|, computed and overflow-checked internally. |
| `assert_family_size(fam, p)` | Refuses a p-value vector of any other length. |
| `derivation_report(f, sets...; n_features, format)` | A Markdown or JSON record of the whole derivation. |

## The injection boundary

The parser is the boundary. Nothing that leaves this package as R code is a user string. It is `to_string` of a tree whose identifiers all come from the caller's `columns` whitelist.

- The lexer accepts a closed character set. Quotes, backticks, `;`, `$`, `=`, `,`, `%`, brackets and every non-ASCII character are rejected, and that includes homoglyphs and zero-width characters.
- The only function call the grammar has is `I(...)`, and inside it only arithmetic is allowed. `system(...)`, `eval(...)`, `parse(...)` and `log(...)` cannot be written.
- R reserved words and `..N` are refused even if they appear in `columns`.

This is enforced by construction and checked by the test suite's injection corpus. It is **not** a formal proof about the Julia code. The planned whitelist-closure theorem holds for the Agda model of the grammar only.

## Deliberately out of scope in v1

These constructs are refused with `UnsupportedInV1`, never silently dropped:
- random effects `(1 | batch)`;
- `.` for "all remaining columns";
- `^` and `/` outside `I()`;
- `%in%`.

The package proves nothing about the BH *procedure* itself. Its non-negativity (R-BH-1) and step-down envelope (R-BH-2) belong to the statistics layer that consumes a `BHFamily`.

## Verification

- `julia --project -e 'using Pkg; Pkg.test()'` runs the unit tests.
- `CONTRASTFAMILIES_R_ORACLE=1` also compares 26 formulas against R's `terms()`, and the contrast counts against `contr.treatment` and `combn` for k = 2..8. CI runs both.
- Machine-checked proofs (Agda) of the counting and canonical-form lemmas are planned. They are not yet in this repository.

## Licence

MPL-2.0. See `LICENSE`.
