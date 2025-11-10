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
        {type = "KEYWORD", value = "true"},
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

-- Test basic component tokenization
function tests.test_component_basic()
    local tokens = Tokenizer.tokenize("<Button>")
    assert.same(tokens, {
        {type = "COMPONENT_START"},
        {type = "COMPONENT_NAME", value = "Button"},
        {type = "COMPONENT_OPEN"}
    })
end

-- Test self-closing component
function tests.test_component_self_closing()
    local tokens = Tokenizer.tokenize("<Button/>")
    assert.same(tokens, {
        {type = "COMPONENT_START"},
        {type = "COMPONENT_NAME", value = "Button"},
        {type = "COMPONENT_SELF_CLOSE"}
    })
end

-- Test component with attributes
function tests.test_component_with_attributes()
    local tokens = Tokenizer.tokenize('<Button text="Click me" disabled/>')
    assert.same(tokens, {
        {type = "COMPONENT_START"},
        {type = "COMPONENT_NAME", value = "Button"},
        {type = "COMPONENT_ATTRS", value = {
            text = {type = "string", value = "Click me"}
        }, malformed = {}},
        {type = "COMPONENT_SELF_CLOSE"}
    })
end

-- Test component closing tag
function tests.test_component_close()
    local tokens = Tokenizer.tokenize("</Button>")
    assert.same(tokens, {
        {type = "COMPONENT_CLOSE"},
        {type = "COMPONENT_NAME", value = "Button"}
    })
end

-- Test component with mixed content
function tests.test_component_mixed_content()
    local tokens = Tokenizer.tokenize('Hello <Button text="Click"/> World')
    assert.same(tokens, {
        {type = "TEXT", value = "Hello "},
        {type = "COMPONENT_START"},
        {type = "COMPONENT_NAME", value = "Button"},
        {type = "COMPONENT_ATTRS", value = {
            text = {type = "string", value = "Click"}
        }, malformed = {}},
        {type = "COMPONENT_SELF_CLOSE"},
        {type = "TEXT", value = " World"}
    })
end

-- Test component with unquoted attribute containing invalid characters
function tests.test_component_malformed_attribute()
    -- Current behavior: the > in the attribute value terminates the component tag
    -- This results in malformed parsing that should be detected as an error
    local tokens = Tokenizer.tokenize('<Button text=Save">Save</Button>')
    assert.equal(#tokens, 7)
    assert.equal(tokens[1].type, "COMPONENT_START")
    assert.equal(tokens[2].type, "COMPONENT_NAME")
    assert.equal(tokens[2].value, "Button")
    assert.equal(tokens[3].type, "COMPONENT_ATTRS")
    assert.equal(tokens[4].type, "COMPONENT_OPEN")
    assert.equal(tokens[5].type, "TEXT")
    assert.equal(tokens[6].type, "COMPONENT_CLOSE")
    assert.equal(tokens[7].type, "COMPONENT_NAME")
end

-- Test attribute validation for unquoted attributes
function tests.test_attribute_validation()
    -- Test valid unquoted attribute
    local tokens = Tokenizer.tokenize('<Button text=validValue/>')
    assert.equal(tokens[3].type, "COMPONENT_ATTRS")
    local attrs = tokens[3].value
    assert.is_not_nil(attrs.text)
    assert.equal(attrs.text.type, "expression")
    assert.equal(attrs.text.value, "validValue")
    assert.is_nil(attrs.text.malformed)
    assert.is_nil(tokens[3].malformed.text)

    -- Test malformed unquoted attribute with quote character
    tokens = Tokenizer.tokenize('<Button text=invalid"quote/>')
    assert.equal(tokens[3].type, "COMPONENT_ATTRS")
    attrs = tokens[3].value
    assert.is_not_nil(attrs.text)
    assert.equal(attrs.text.type, "expression")
    assert.equal(attrs.text.value, 'invalid"quote')
    assert.is_true(attrs.text.malformed)
    assert.equal(tokens[3].malformed.text, "malformed attribute: contains invalid character")
end

return tests