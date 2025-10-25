local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- A basic expression value renders.
function tests.test_expression_value()
    local template = Template("a test {{ expression_value }}")
    local context = { expression_value = "value" }

    local output = template(context)

    assert.equal("a test value", output)
end

return tests
