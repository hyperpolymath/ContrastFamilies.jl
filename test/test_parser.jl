# SPDX-License-Identifier: MPL-2.0
using ContrastFamilies: FVar, FInt, FPlus, FStar, FColon, FParen, FIdentity, FNeg, FMinus

"""Return the `code` of the FormulaError thrown by `f()`, or `nothing`."""
errcode(f) = try f(); nothing catch e; e isa FormulaError ? e.code : typeof(e) end

@testset "parser" begin
    @testset "structure and precedence" begin
        f = pf("y ~ a + b*c:d")
        @test f.lhs === :y
        @test f.rhs == FPlus(FVar(:a), FStar(FVar(:b), FColon(FVar(:c), FVar(:d))))
        @test pf("~ a").lhs === nothing
        @test pf("y ~ a - b + c").rhs == FPlus(FMinus(FVar(:a), FVar(:b)), FVar(:c))
        @test pf("y ~ -1 + a").rhs == FPlus(FNeg(FInt(1)), FVar(:a))
        @test pf("y ~ (a + b):c").rhs == FColon(FParen(FPlus(FVar(:a), FVar(:b))), FVar(:c))
        @test pf("y~a+b") == pf("y ~   a +\n b")      # whitespace is not presentation
    end

    @testset "I() arithmetic" begin
        @test to_string(pf("y ~ I(depth^2)")) == "y ~ I(depth^2)"
        @test to_string(pf("y~I(-x1^2)")) == "y ~ I(-x1^2)"
        @test to_string(pf("y~I((a+b)/2*x1-1)")) == "y ~ I((a + b) / 2 * x1 - 1)"
        @test to_string(pf("y~I(a^b^2)")) == "y ~ I(a^b^2)"
        @test pf("y ~ I(a^b^2)").rhs.expr.r isa ContrastFamilies.IBin   # right-assoc
        @test errcode(() -> pf("y ~ I(log(a))")) == :function_call
        @test errcode(() -> pf("y ~ I(zzz)")) == :unknown_column
    end

    @testset "injection corpus is refused" begin
        for s in ["y ~ system(\"rm -rf /\")", "y ~ system(a)", "y ~ eval(a)",
                  "y ~ parse(a)", "y ~ get(a)", "y ~ base::system(a)",
                  "y ~ a; system(b)", "y ~ `a`", "y ~ \$a", "y ~ a | b",
                  "y ~ offset(a)", "y ~ poly(a, 2)", "y ~ log(a)"]
            @test_throws Exception pf(s)
        end
        @test errcode(() -> pf("y ~ system(a)")) == :function_call
        @test errcode(() -> pf("y ~ log(a)")) == :function_call
    end

    @testset "whitelist and reserved names" begin
        @test errcode(() -> pf("y ~ zz")) == :unknown_column
        @test errcode(() -> pf("zz ~ a")) == :unknown_column
        @test errcode(() -> parse_formula("y ~ TRUE"; columns = [:y, :TRUE])) == :reserved
        @test errcode(() -> parse_formula("y ~ ..1"; columns = [:y, Symbol("..1")])) == :reserved
        @test errcode(() -> parse_formula("y ~ function"; columns = [:y, :function])) == :reserved
        @test pf("y ~ x.3 + x_2").rhs == FPlus(FVar(Symbol("x.3")), FVar(:x_2))
        @test parse_formula("y ~ a"; columns = ["y", "a"]).lhs === :y   # strings accepted
    end

    @testset "unsupported in v1, refused not dropped" begin
        for s in ["y ~ a + (1 | batch)", "y ~ (1|batch)", "y ~ (a + 1 | batch)",
                  "y ~ .", "y ~ a + .", "y ~ (a + b)^2", "y ~ a/b", "y ~ a %in% b"]
            @test_throws Union{UnsupportedInV1,FormulaError} pf(s)
        end
        @test_throws UnsupportedInV1 pf("y ~ a + (1 | batch)")
        @test_throws UnsupportedInV1 pf("y ~ .")
        @test_throws UnsupportedInV1 pf("y ~ (a+b)^2")
        @test_throws UnsupportedInV1 pf("y ~ a/b")
    end

    @testset "malformed" begin
        @test errcode(() -> pf("y a")) == :missing_tilde
        @test errcode(() -> pf("y + a ~ b")) == :missing_tilde
        @test errcode(() -> pf("y ~")) == :syntax
        @test errcode(() -> pf("y ~ a +")) == :syntax
        @test errcode(() -> pf("y ~ (a")) == :syntax
        @test errcode(() -> pf("y ~ a)")) == :syntax
        @test errcode(() -> pf("y ~ a ~ b")) == :syntax
        @test errcode(() -> pf("y ~ 2")) == :number
        @test errcode(() -> pf("y ~ y + a")) == :response_on_rhs
        @test errcode(() -> pf("y ~ I(y^2)")) == :response_on_rhs
        @test errcode(() -> pf("y ~ " * "("^70 * "a" * ")"^70)) == :too_deep
        @test pf("y ~ " * "("^60 * "a" * ")"^60) isa Formula
    end

    @testset "round trip parse ∘ to_string" begin
        for s in ["y ~ a", "~ a + b", "y ~ a*b", "y ~ (a + b)*c - b:c", "y ~ 0 + a",
                  "y ~ -1 + a:b", "y ~ a - 1", "y ~ I(depth^2) + group*batch",
                  "y ~ ((a))", "y ~ a:b:c + I(-x1 / (2 + x_2))", "y ~ 1", "y ~ 0"]
            f = pf(s)
            @test pf(to_string(f)) == f
            @test hash(pf(to_string(f))) == hash(f)
        end
    end
end
