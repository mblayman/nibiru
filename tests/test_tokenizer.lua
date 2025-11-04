local assert = require("luassert")
local Tokenizer = require("nibiru.tokenizer")

local tests = {}

-- Test TEXT token
function tests.test_text_only()
    local tokens = Tokenizer.tokenize("hello world")
    assert.equal(#tokens, 1)
    assert.equal(tokens[1].type, "TEXT")
    assert.equal(tokens[1].value, "hello world")
end

-- Test EXPR_START and EXPR_END with identifier
function tests.test_expression_identifier()
    local tokens = Tokenizer.tokenize("{{ name }}")
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "IDENTIFIER", value = "name"},
        {type = "EXPR_END"}
    })
end

-- Test STMT_START and STMT_END with keywords
function tests.test_statement_if()
    local tokens = Tokenizer.tokenize("{% if true %}")
    assert.same(tokens, {
        {type = "STMT_START"},
        {type = "IDENTIFIER", value = "if"},
        {type = "IDENTIFIER", value = "true"},
        {type = "STMT_END"}
    })
end

-- Test LITERAL string
function tests.test_literal_string()
    local tokens = Tokenizer.tokenize('{{ "hello world" }}')
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "LITERAL", value = "hello world"},
        {type = "EXPR_END"}
    })
end

-- Test LITERAL number
function tests.test_literal_number()
    local tokens = Tokenizer.tokenize("{{ 123.45 }}")
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "LITERAL", value = 123.45},
        {type = "EXPR_END"}
    })
end

-- Test OPERATOR
function tests.test_operator()
    local tokens = Tokenizer.tokenize("{{ a + b }}")
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "IDENTIFIER", value = "a"},
        {type = "OPERATOR", value = "+"},
        {type = "IDENTIFIER", value = "b"},
        {type = "EXPR_END"}
    })
end

-- Test PUNCTUATION
function tests.test_punctuation()
    local tokens = Tokenizer.tokenize("{{ func(a, b) }}")
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "IDENTIFIER", value = "func"},
        {type = "PUNCTUATION", value = "("},
        {type = "IDENTIFIER", value = "a"},
        {type = "PUNCTUATION", value = ","},
        {type = "IDENTIFIER", value = "b"},
        {type = "PUNCTUATION", value = ")"},
        {type = "EXPR_END"}
    })
end

-- Test mixed TEXT, EXPR, STMT
function tests.test_mixed()
    local tokens = Tokenizer.tokenize("Hello {{name}}, {% if admin %} welcome {% endif %}")
    assert.same(tokens, {
        {type = "TEXT", value = "Hello "},
        {type = "EXPR_START"},
        {type = "IDENTIFIER", value = "name"},
        {type = "EXPR_END"},
        {type = "TEXT", value = ", "},
        {type = "STMT_START"},
        {type = "IDENTIFIER", value = "if"},
        {type = "IDENTIFIER", value = "admin"},
        {type = "STMT_END"},
        {type = "TEXT", value = " welcome "},
        {type = "STMT_START"},
        {type = "IDENTIFIER", value = "endif"},
        {type = "STMT_END"}
    })
end

-- Test empty template
function tests.test_empty()
    local tokens = Tokenizer.tokenize("")
    assert.same(tokens, {})
end

-- Test whitespace in expression
function tests.test_whitespace_in_expr()
    local tokens = Tokenizer.tokenize("{{ a   +  b }}")
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "IDENTIFIER", value = "a"},
        {type = "OPERATOR", value = "+"},
        {type = "IDENTIFIER", value = "b"},
        {type = "EXPR_END"}
    })
end

-- Test unclosed expression
function tests.test_unclosed_expression()
    assert.has_error(function() Tokenizer.tokenize("{{ unclosed") end)
end

-- Test unclosed statement
function tests.test_unclosed_statement()
    assert.has_error(function() Tokenizer.tokenize("{% unclosed") end)
end

-- Test compound operators
function tests.test_compound_operator()
    local tokens = Tokenizer.tokenize("{{ a == b }}")
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "IDENTIFIER", value = "a"},
        {type = "OPERATOR", value = "=="},
        {type = "IDENTIFIER", value = "b"},
        {type = "EXPR_END"}
    })
end

-- Test escaped string
function tests.test_escaped_string()
    local tokens = Tokenizer.tokenize('{{ "hello \\"world\\"" }}')
    assert.same(tokens, {
        {type = "EXPR_START"},
        {type = "LITERAL", value = 'hello \\"world\\"'},
        {type = "EXPR_END"}
    })
end

return tests