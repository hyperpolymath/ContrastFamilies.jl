# SPDX-License-Identifier: MPL-2.0
using ContrastFamilies: tokenize, MAX_FORMULA_LENGTH

@testset "lexer" begin
    kinds(s) = [t.kind for t in tokenize(s)]
    @test kinds("y ~ a*b") == [:ident, :tilde, :ident, :star, :ident, :eof]
    @test kinds("I(x^2/3)") == [:ident, :lparen, :ident, :caret, :number, :slash, :number, :rparen, :eof]
    @test [t.text for t in tokenize("x.3 + .5 + 1.25 + x_2")][1:7] == ["x.3", "+", ".5", "+", "1.25", "+", "x_2"]
    @test tokenize("  a")[1].pos == 3

    @testset "closed character set: $(repr(s))" for s in [
            "y ~ \"a\"", "y ~ 'a'", "y ~ `a`", "y ~ a; b", "y ~ \$a", "y ~ a = b",
            "y ~ f(a, b)", "y ~ a %in% b", "y ~ a[1]", "y ~ a\\b", "y ~ a&b", "y ~ !a",
            "y ~ а",            # Cyrillic a (homoglyph)
            "y ~ a​",      # zero-width space
            "y ~ é", "y ~ a # comment", "y ~ a@b", "y ~ {a}"]
        @test_throws FormulaError tokenize(s)
        err = try tokenize(s); nothing catch e; e end
        @test err.code == :bad_char
    end
    @test_throws FormulaError tokenize("y ~ " * repeat("a + ", MAX_FORMULA_LENGTH))
end
