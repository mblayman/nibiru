local assert = require("luassert")
local pp = require("nibiru.pp")

local tests = {}

function tests.test_empty_table()
    local t = {}
    local expected = [[{
}
]]
    assert.equals(pp(t), expected)
end

function tests.test_various_value_types()
    local t = {
        num = 42,
        str = "hello",
        bool_true = true,
        bool_false = false,
        func = function() end
    }
    local result = pp(t)
    assert.is_truthy(result:find("num = 42"))
    assert.is_truthy(result:find("str = hello"))
    assert.is_truthy(result:find("bool_true = true"))
    assert.is_truthy(result:find("bool_false = false"))
    assert.is_truthy(result:find("func = function:"))
end

function tests.test_nested_tables()
    local t = {
        outer = {
            inner = {
                value = "deep"
            }
        }
    }
    local result = pp(t)
    assert.is_truthy(result:find("outer ="))
    assert.is_truthy(result:find("inner ="))
    assert.is_truthy(result:find("value = deep"))
end

function tests.test_circular_references()
    local t = {name = "root"}
    t.self = t
    local result = pp(t)
    assert.is_truthy(result:find("name = root"))
    assert.is_truthy(result:find("<circular reference>"))
end

function tests.test_nested_tables()
    local t = {
        outer = {
            inner = {
                value = "deep"
            }
        }
    }
    local result = pp(t)
    assert.is_truthy(result:find("outer ="))
    assert.is_truthy(result:find("inner ="))
    assert.is_truthy(result:find("value = deep"))
end

function tests.test_numeric_keys()
    local t = {"a", "b", "c"}
    local expected = [[{
    [1] = a
    [2] = b
    [3] = c
}
]]
    assert.equals(pp(t), expected)
end

function tests.test_mixed_key_types()
    local t = {}
    t["string key"] = "value"
    t[42] = "number key"
    t[true] = "boolean key"
    local result = pp(t)
    -- Since pairs order is not guaranteed, check all are present
    assert.is_truthy(result:find("42] = number key"))
    assert.is_truthy(result:find("true] = boolean key"))
    assert.is_truthy(result:find("string key"))
end

function tests.test_circular_references()
    local t = {name = "root"}
    t.self = t
    local result = pp(t)
    assert.is_truthy(result:find("name = root"))
    assert.is_truthy(result:find("<circular reference>"))
end

function tests.test_non_table_input()
    assert.equals(pp("string"), "string\n")
    assert.equals(pp(42), "42\n")
    assert.equals(pp(true), "true\n")
    assert.equals(pp(nil), "nil\n")
end

return tests