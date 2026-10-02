# SPDX-License-Identifier: MPL-2.0

"""Canonical spelling of formula `s`."""
cs(s) = to_string(canonical(pf(s)))

@testset "canonical" begin
    @testset "expansion matches R terms() (R 4.5.0)" begin
        @test cs("y ~ a*b") == "y ~ a + b + a:b"
        @test cs("y ~ a*b*c") == "y ~ a + b + c + a:b + a:c + b:c + a:b:c"
        @test cs("y ~ (a + b):c") == "y ~ a:c + b:c"
        @test cs("y ~ a*b - a") == "y ~ b + a:b"
        @test cs("y ~ (a + b)*c - b:c") == "y ~ a + b + c + a:c"
        @test cs("y ~ -a + a + b") == "y ~ a + b"            # left to right
        @test cs("y ~ (a - b) + b") == "y ~ a + b"
        @test cs("y ~ a + b - b") == "y ~ a"
        @test cs("y ~ a:a") == "y ~ a"
        @test cs("y ~ b:a + a:b") == "y ~ a:b"
        @test cs("y ~ a:b:a") == "y ~ a:b"
        @test cs("y ~ 0 + a + 1") == "y ~ a"                 # last marker wins
        @test cs("y ~ a - 0") == "y ~ a"
        @test cs("y ~ 1 + a - 1") == "y ~ 0 + a"
        @test cs("y ~ -1 + a") == "y ~ 0 + a"
        @test cs("y ~ 0") == "y ~ 0"
        @test cs("y ~ 1") == "y ~ 1"
        @test cs("y ~ a - a") == "y ~ 1"
        @test cs("y ~ I(depth^2):a") == "y ~ I(depth^2):a"
    end

    @testset "intercept markers are top level only" begin
        @test_throws UnsupportedInV1 canonical(pf("y ~ (a + 0)"))
        @test_throws UnsupportedInV1 canonical(pf("y ~ a:(-b)"))
    end

    @testset "invariance under presentation" begin
        groups = [["y ~ a*b", "y ~ b*a", "y ~ a + b + a:b", "y ~ b:a + b + a"],
                  ["y ~ a + b + c", "y ~ c + b + a", "y ~ (c + a) + b", "y ~ ((a)) + c + b"],
                  ["y ~ 0 + a", "y ~ a - 1", "y ~ -1 + a", "y ~ a + 0"]]
        for g in groups
            cf = [canonical(pf(s)) for s in g]
            @test all(==(cf[1]), cf)
            @test allequal(hash.(cf))
        end
    end

    @testset "idempotent and round-trips" begin
        for s in ["y ~ a*b*c - a:b", "~ b + a", "y ~ 0 + group*batch", "y ~ 1",
                  "y ~ I(x1^2) + x.3:x_2"]
            c = canonical(pf(s))
            @test canonical(c) == c
            @test canonical(pf(to_string(c))) == c
        end
    end

    @testset "ModelTerm" begin
        @test ModelTerm(["b", "a", "b"]) == ModelTerm(["a", "b"])
        @test label(ModelTerm(["b", "a"])) == "a:b"
        @test degree(ModelTerm(["c", "a", "b"])) == 3
        e = expand_terms(pf("y ~ b*a"))
        @test e.intercept
        @test label.(e.terms) == ["b", "a", "a:b"]            # first-appearance order
    end
end
