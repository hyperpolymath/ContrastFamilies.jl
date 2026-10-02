# SPDX-License-Identifier: MPL-2.0
#
# R oracle: compare expansion and contrast counts with R itself. Opt-in, because
# it needs Rscript: set CONTRASTFAMILIES_R_ORACLE=1. When set, a missing Rscript
# is a failure, not a skip.

const ORACLE_FORMULAS = [
    "y ~ a", "y ~ a + b", "y ~ a*b", "y ~ a*b*c", "y ~ (a + b):c", "y ~ a*b - a",
    "y ~ (a + b)*c - b:c", "y ~ -a + a + b", "y ~ (a - b) + b", "y ~ a + b - b",
    "y ~ a:a", "y ~ b:a + a:b", "y ~ a:b:a", "y ~ 0 + a + 1", "y ~ a - 0",
    "y ~ 1 + a - 1", "y ~ -1 + a", "y ~ 0 + a*b", "y ~ a - a", "y ~ 1",
    "y ~ I(depth^2) + a", "y ~ I(depth^2):group", "y ~ (a + b + c)*d - a:d",
    "y ~ group*batch + I((x1 + x_2) / 2)", "~ a*b", "y ~ a*(b + c) - a:c + c:a",
]

"""Factor set of a term label, whitespace removed so R's deparse spacing does not matter."""
_factorset(lbl) = sort!([replace(f, r"\s" => "") for f in split(lbl, ":")])

if get(ENV, "CONTRASTFAMILIES_R_ORACLE", "") == "1"
    @testset "R oracle" begin
        rscript = Sys.which("Rscript")
        @test rscript !== nothing
        if rscript !== nothing
            fs = [pf(s) for s in ORACLE_FORMULAS]
            dir = mktempdir()
            inp = joinpath(dir, "formulas.txt")
            write(inp, join(to_string.(fs), "\n") * "\n")
            script = joinpath(dir, "oracle.R")
            write(script, """
                fs <- readLines("$(escape_string(inp))")
                for (s in fs) {
                  tt <- terms(as.formula(s))
                  cat(attr(tt, "intercept"), "\\t", paste(attr(tt, "term.labels"), collapse = "|"), "\\n", sep = "")
                }
                for (k in 2:8) cat("k", k, ncol(contr.treatment(k)), ncol(combn(k, 2)), "\\n")
                """)
            out = readlines(`$rscript --vanilla $script`)
            @test length(out) == length(fs) + 7
            for (i, f) in enumerate(fs)
                icpt, labels = split(out[i], '\t')
                rterms = Set(_factorset(l) for l in split(labels, '|') if !isempty(l))
                c = canonical(f)
                @testset "$(ORACLE_FORMULAS[i])" begin
                    @test (icpt == "1") == c.intercept
                    @test rterms == Set(_factorset(label(t)) for t in c.terms)
                    @test length(rterms) == length(c.terms)
                end
            end
            g = pf("y ~ group")
            for line in out[end-6:end]
                _, k, nt, np = split(line)
                k, nt, np = parse.(Int, (k, nt, np))
                lv = string.(1:k)
                @test length(contrasts(g, :group; levels = lv, reference = "1")) == nt
                @test length(contrasts(g, :group; levels = lv, scheme = :pairwise)) == np
            end
        end
    end
else
    @info "R oracle skipped; set CONTRASTFAMILIES_R_ORACLE=1 (needs Rscript) to run it"
end
