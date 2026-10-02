# SPDX-License-Identifier: MPL-2.0
using ContrastFamilies
using Test

const COLS = [:y, :a, :b, :c, :d, :group, :batch, :depth, :x1, :x_2, Symbol("x.3")]

"""Parse `s` against the shared test column whitelist."""
pf(s) = parse_formula(s; columns = COLS)

@testset "ContrastFamilies" begin
    include("test_lexer.jl")
    include("test_parser.jl")
    include("test_canonical.jl")
    include("test_provenance.jl")
    include("test_contrasts.jl")
    include("test_family.jl")
    include("test_report.jl")
    include("test_r_oracle.jl")
end
