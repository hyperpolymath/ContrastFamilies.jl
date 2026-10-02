# SPDX-License-Identifier: MPL-2.0

@testset "family" begin
    f = pf("y ~ group + batch")
    g4 = contrasts(f, :group; levels = ["A", "B", "C", "D"], scheme = :pairwise)
    @testset "the spec example: 1500 taxa × 6 contrasts = 9000" begin
        fam = bh_family(f, g4; n_features = 1500)
        @test fam.m == 9000 && fam.n_features == 1500 && fam.n_contrasts == 6
        @test fam.provenance == provenance_hash(f)
        @test fam.equivalence == equivalence_key(f)
        @test fam.contrast_names[1] == "group: B - A"
        @test assert_family_size(fam, 9000) === nothing
        @test assert_family_size(fam, zeros(9000)) === nothing
        @test_throws FamilyMismatch assert_family_size(fam, 1500)   # the per-contrast mistake
        @test_throws FamilyMismatch assert_family_size(fam, zeros(6))
        @test sprint(show, fam) == "BHFamily(m = 9000 = 1500 × 6)"
    end

    @testset "m = n × Σ|C| over several factors" for n in (1, 7, 1500), k in 2:5
        b = contrasts(f, :batch; levels = ["b$i" for i in 1:k], reference = "b1")
        fam = bh_family(f, g4, b; n_features = n)
        @test fam.m == n * (6 + (k - 1))
        @test length(fam.contrast_names) == fam.n_contrasts
    end

    @testset "refusals" begin
        other = pf("y ~ group")
        go = contrasts(other, :group; levels = ["A", "B"], reference = "A")
        @test errcode(() -> bh_family(f, go; n_features = 10)) == :formula_mismatch
        # an equivalent presentation of the same model is accepted
        @test bh_family(pf("y ~ batch + group"), g4; n_features = 2).m == 12
        @test errcode(() -> bh_family(f, g4, g4; n_features = 10)) == :duplicate_factor
        @test_throws ArgumentError bh_family(f, g4; n_features = 0)
        @test_throws ArgumentError bh_family(f; n_features = 10)
        @test_throws OverflowError bh_family(f, g4; n_features = typemax(Int) ÷ 2)
    end
end
