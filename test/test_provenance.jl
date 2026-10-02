# SPDX-License-Identifier: MPL-2.0

@testset "provenance" begin
    shape(h) = occursin(r"^sha256:[0-9a-f]{64}$", h)
    f1, f2 = pf("y ~ a + b"), pf("y ~ b + a")
    @test shape(provenance_hash(f1)) && shape(equivalence_key(f1))
    @test provenance_hash(f1) != provenance_hash(f2)          # as written: order matters
    @test equivalence_key(f1) == equivalence_key(f2)          # same model
    @test provenance_hash(pf("y~a+b")) == provenance_hash(pf("y ~ a  +  b"))  # whitespace does not
    @test provenance_hash(pf("y ~ (a) + b")) != provenance_hash(f1)            # parentheses do
    @test equivalence_key(pf("y ~ a*b")) == equivalence_key(pf("y ~ b:a + a + b"))
    @test equivalence_key(pf("y ~ a*b")) != equivalence_key(pf("y ~ a + b"))
    @test equivalence_key(pf("y ~ a")) != equivalence_key(pf("y ~ 0 + a"))
    @test equivalence_key(pf("y ~ a")) != equivalence_key(pf("~ a"))
    @test equivalence_key(canonical(f1)) == equivalence_key(f1)
    # domain separation: the two hashes never coincide on the same text
    @test provenance_hash(pf("y ~ a")) != equivalence_key(pf("y ~ a"))
    # pinned known answer, so an accidental change to the hashed bytes is caught
    @test provenance_hash(pf("y ~ group + a")) ==
          "sha256:2df9bba3208dad5fdff6c6adae34eaac89b794024393a454a80bae116b4de021"
end
