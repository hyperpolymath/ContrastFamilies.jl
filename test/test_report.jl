# SPDX-License-Identifier: MPL-2.0

@testset "report" begin
    f = pf("y ~ group*batch")
    g = contrasts(f, :group; levels = ["ctl", "a_b", "x*y"], reference = "ctl")
    md = derivation_report(f, g; n_features = 1500)
    @test occursin("`y ~ group * batch`", md)
    @test occursin("`y ~ batch + group + batch:group`", md)
    @test occursin(provenance_hash(f), md) && occursin(equivalence_key(f), md)
    @test occursin("1500 × 2 = 3000", md)
    @test occursin("a\\_b \\- ctl", md)          # level names are Markdown-escaped
    @test occursin("x\\*y", md)
    @test !occursin("Benjamini", derivation_report(f, g))   # no n_features, no family

    js = derivation_report(f, g; n_features = 1500, format = :json)
    @test startswith(js, "{\"as_written\":\"y ~ group * batch\"")
    @test occursin("\"family\":{\"n_features\":1500,\"n_contrasts\":2,\"m\":3000}", js)
    @test occursin("\"reference\":\"ctl\"", js)
    @test occursin("\"family\":null", derivation_report(f; format = :json))
    @test occursin("\"intercept\":true", js)

    q = contrasts(f, :group; levels = ["say \"hi\"", "back\\slash", "tab\there"], reference = "say \"hi\"")
    jq = derivation_report(f, q; format = :json)
    @test occursin("say \\\"hi\\\"", jq) && occursin("back\\\\slash", jq) && occursin("tab\\there", jq)
    @test_throws ArgumentError derivation_report(f; format = :yaml)
end
