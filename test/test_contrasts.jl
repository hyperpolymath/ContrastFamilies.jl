# SPDX-License-Identifier: MPL-2.0

@testset "contrasts" begin
    f = pf("y ~ group + batch")
    @testset "counts k-1 and k(k-1)/2, k = 2..8" for k in 2:8
        lv = ["L$i" for i in 1:k]
        t = contrasts(f, :group; levels = lv, reference = "L1")
        p = contrasts(f, :group; levels = lv, scheme = :pairwise)
        @test length(t) == k - 1
        @test 2 * length(p) == k * (k - 1)
        for c in vcat(t.contrasts, p.contrasts)
            @test sum(c.weights) == 0
            @test count(==(1), c.weights) == 1 && count(==(-1), c.weights) == 1
        end
        @test allunique([c.weights for c in p.contrasts])
    end

    t = contrasts(f, :group; levels = ["ctl", "lo", "hi"], reference = "ctl")
    @test [c.name for c in t.contrasts] == ["lo - ctl", "hi - ctl"]
    @test t.contrasts[2].weights == [-1, 0, 1]
    @test t.reference == "ctl" && t.scheme === :treatment
    t2 = contrasts(f, :group; levels = ["ctl", "lo", "hi"], reference = "lo")
    @test [c.name for c in t2.contrasts] == ["ctl - lo", "hi - lo"]

    p = contrasts(f, "group"; levels = ["A", "B", "C"], scheme = :pairwise)
    @test [c.name for c in p.contrasts] == ["B - A", "C - A", "C - B"]
    @test p.reference === nothing
    @test p.equivalence == equivalence_key(f)

    @testset "refusals" begin
        @test errcode(() -> contrasts(f, :group; levels = ["A", "B"])) == :reference
        @test errcode(() -> contrasts(f, :group; levels = ["A", "B"], reference = "Z")) == :reference
        @test errcode(() -> contrasts(f, :group; levels = ["A", "B"], scheme = :pairwise, reference = "A")) == :reference
        @test errcode(() -> contrasts(f, :group; levels = ["A"], reference = "A")) == :levels
        @test errcode(() -> contrasts(f, :group; levels = ["A", "A"], reference = "A")) == :levels
        @test errcode(() -> contrasts(f, :group; levels = ["A", "B"], scheme = :helmert)) == :scheme
        @test errcode(() -> contrasts(f, :depth; levels = ["A", "B"], reference = "A")) == :not_a_main_effect
        g = pf("y ~ group:batch")
        @test errcode(() -> contrasts(g, :group; levels = ["A", "B"], reference = "A")) == :not_a_main_effect
        @test errcode(() -> contrasts(pf("y ~ group*batch - group"), :group;
                                      levels = ["A", "B"], reference = "A")) == :not_a_main_effect
    end
end
