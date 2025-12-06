local assert = require("luassert")
local yaml = require("nibiru.yaml")

local tests = {}

-- Test basic string values
function tests.test_basic_string()
    local result, err = yaml.parse('---\ntitle: "My Title"\n---')
    assert.is_nil(err)
    assert.same(result, { title = "My Title" })
end

-- Test unquoted strings
function tests.test_unquoted_string()
    local result, err = yaml.parse("---\ntitle: My Title\n---")
    assert.is_nil(err)
    assert.same(result, { title = "My Title" })
end

-- Test numbers
function tests.test_numbers()
    local result, err = yaml.parse("---\ncount: 42\nprice: 19.99\n---")
    assert.is_nil(err)
    assert.same(result, { count = 42, price = 19.99 })
end

-- Test booleans
function tests.test_booleans()
    local result, err = yaml.parse("---\nenabled: true\ndisabled: false\n---")
    assert.is_nil(err)
    assert.same(result, { enabled = true, disabled = false })
end

-- Test arrays
function tests.test_simple_array()
    local result, err = yaml.parse("---\ntags: [lua, web, markdown]\n---")
    assert.is_nil(err)
    assert.same(result, { tags = { "lua", "web", "markdown" } })
end

-- Test nested objects
function tests.test_nested_object()
    local result, err =
        yaml.parse('---\nauthor:\n  name: "John Doe"\n  email: "john@example.com"\n---')
    assert.is_nil(err)
    assert.same(result, {
        author = {
            name = "John Doe",
            email = "john@example.com",
        },
    })
end

-- Test complex nested structure
function tests.test_complex_structure()
    local result, err = yaml.parse(
        '---\ntitle: "My Blog Post"\ndate: "2024-01-01"\npublished: true\ntags: [lua, web, tutorial]\nauthor:\n  name: "John Doe"\n  email: "john@example.com"\n  social:\n    twitter: "@johndoe"\n    github: "johndoe"\n---'
    )
    assert.is_nil(err)
    local expected = {
        title = "My Blog Post",
        date = "2024-01-01",
        published = true,
        tags = { "lua", "web", "tutorial" },
        author = {
            name = "John Doe",
            email = "john@example.com",
            social = {
                twitter = "@johndoe",
                github = "johndoe",
            },
        },
    }

    assert.same(expected, result)
end

-- Test empty frontmatter
function tests.test_empty_frontmatter()
    local result, err = yaml.parse("---\n---")
    assert.is_nil(err)
    assert.same(result, {})
end

-- Test missing closing delimiter
function tests.test_missing_closing_delimiter()
    local result, err = yaml.parse("---\ntitle: Test\n")
    assert.is_nil(result)
    assert.match(err, "missing closing")
end

-- Test invalid YAML syntax
function tests.test_invalid_yaml_syntax()
    local result, err = yaml.parse("---\ntitle\n---")
    assert.is_nil(result)
    assert.match(err, "parsing error")
end

-- Test bad indentation
function tests.test_bad_indentation()
    local result, err =
        yaml.parse("---\nauthor:\n  name: John\n    email: john@example.com\n---")
    assert.is_nil(result)
    assert.match(err, "parsing error")
end

-- Test no frontmatter delimiters
function tests.test_no_delimiters()
    local result, err = yaml.parse("title: Test")
    assert.is_nil(result)
    assert.match(err, "parsing error")
end

-- Test invalid input type
function tests.test_invalid_input_type()
    local result, err = yaml.parse(123)
    assert.is_nil(result)
    assert.match(err, "expected string")
end

return tests

