local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- Control Flow: {% if/endif %} conditional rendering

-- Happy Path Tests

function tests.test_if_endif_basic_true()
    local template = Template("{% if show %}Hello World{% endif %}")
    local result = template({ show = true })
    assert.equal("Hello World", result)
end

function tests.test_if_endif_basic_false()
    local template = Template("{% if show %}Hello World{% endif %}")
    local result = template({ show = false })
    assert.equal("", result)
end

function tests.test_if_endif_with_falsey_values()
    local template = Template("{% if value %}Truthy{% endif %}")
    -- Test various falsey values
    assert.equal("", template({ value = false }))
    assert.equal("", template({ value = nil }))
    assert.equal("", template({ value = 0 }))
    assert.equal("", template({ value = "" }))
    assert.equal("", template({ value = {} })) -- empty tables are falsy
end

function tests.test_if_endif_with_truthy_values()
    local template = Template("{% if value %}Truthy{% endif %}")
    -- Test various truthy values
    assert.equal("Truthy", template({ value = true }))
    assert.equal("Truthy", template({ value = 1 }))
    assert.equal("Truthy", template({ value = "hello" }))
    -- Note: empty tables {} are considered falsy in this template language
end

function tests.test_if_endif_with_expression()
    local template = Template('{% if user.name == "Alice" %}Welcome Alice{% endif %}')
    local result = template({ user = { name = "Alice" } })
    assert.equal("Welcome Alice", result)
end

function tests.test_if_endif_with_property_access()
    local template =
        Template("{% if user.profile.settings.enabled %}Enabled{% endif %}")
    local result = template({
        user = {
            profile = {
                settings = { enabled = true },
            },
        },
    })
    assert.equal("Enabled", result)
end

function tests.test_if_endif_complex_condition()
    local template =
        Template("{% if count > 0 and visible %}Items: {{count}}{% endif %}")
    local result = template({ count = 5, visible = true })
    assert.equal("Items: 5", result)
end

function tests.test_if_endif_with_default_values()
    local template =
        Template('{% if user.name or "Guest" == "Alice" %}Hello Alice{% endif %}')
    local result = template({ user = { name = "Alice" } })
    assert.equal("Hello Alice", result)
end

function tests.test_if_endif_with_arithmetic()
    local template = Template("{% if x + y > 10 %}Sum is big{% endif %}")
    assert.equal("Sum is big", template({ x = 7, y = 4 }))
    assert.equal("", template({ x = 3, y = 2 }))
end

function tests.test_if_endif_with_string_concatenation()
    local template =
        Template('{% if greeting .. name == "HelloWorld" %}Match{% endif %}')
    assert.equal("Match", template({ greeting = "Hello", name = "World" }))
    assert.equal("", template({ greeting = "Hi", name = "World" }))
end

function tests.test_if_endif_multiple_conditions_in_template()
    local template = Template([[
{% if admin %}
<p>Admin panel</p>
{% endif %}
{% if user %}
<p>Welcome {{user.name}}</p>
{% endif %}
{% if show_footer %}
<footer>Copyright 2024</footer>
{% endif %}
]])
    local result = template({
        admin = true,
        user = { name = "Alice" },
        show_footer = false,
    })
    assert.equal(
        [[

<p>Admin panel</p>


<p>Welcome Alice</p>


]],
        result
    )
end

function tests.test_if_endif_with_html_content()
    local template = Template([[
<div>
  <h1>Title</h1>
  {% if featured %}
  <div class="featured">
    <img src="featured.jpg" alt="Featured"/>
    <p>This is featured content</p>
  </div>
  {% endif %}
  <p>Regular content</p>
</div>
]])
    local result = template({ featured = true })
    assert.equal(
        [[
<div>
  <h1>Title</h1>
  
  <div class="featured">
    <img src="featured.jpg" alt="Featured"/>
    <p>This is featured content</p>
  </div>
  
  <p>Regular content</p>
</div>
]],
        result
    )
end

function tests.test_if_endif_nested()
    local template = Template([[
{% if outer %}
Outer content
  {% if inner %}
  Inner content
  {% endif %}
More outer content
{% endif %}
]])
    local result = template({ outer = true, inner = true })
    assert.equal(
        [[

Outer content
  
  Inner content
  
More outer content

]],
        result
    )
end

function tests.test_if_endif_nested_outer_false()
    local template = Template([[
{% if outer %}
Outer content
  {% if inner %}
  Inner content
  {% endif %}
{% endif %}
]])
    local result = template({ outer = false, inner = true })
    assert.equal("\n", result)
end

function tests.test_if_endif_nested_inner_false()
    local template = Template([[
{% if outer %}
Outer content
  {% if inner %}
  Inner content
  {% endif %}
More outer content
{% endif %}
]])
    local result = template({ outer = true, inner = false })
    assert.equal(
        [[

Outer content
  
More outer content

]],
        result
    )
end

-- Error Path Tests

function tests.test_if_endif_unclosed_block()
    local success, err = pcall(function()
        local template = Template("{% if condition %}Content")
        template({})
    end)
    assert.is_false(success)
    assert.match("unclosed", err:lower())
end

function tests.test_if_endif_missing_if()
    local success, err = pcall(function()
        local template = Template("Content{% endif %}")
        template({})
    end)
    assert.is_false(success)
    assert.match("unexpected", err:lower())
end

function tests.test_if_endif_empty_condition()
    local success, err = pcall(function()
        local template = Template("{% if %}Content{% endif %}")
        template({})
    end)
    assert.is_false(success)
    assert.match("condition", err:lower())
end

function tests.test_if_endif_invalid_syntax_in_condition()
    local success, err = pcall(function()
        local template = Template("{% if user.name == %}Content{% endif %}")
        template({ user = { name = "test" } })
    end)
    assert.is_false(success)
    assert.match("invalid", err:lower())
end

function tests.test_if_endif_malformed_condition()
    local success, err = pcall(function()
        local template = Template('{% if user.name == "test" and %}Content{% endif %}')
        template({ user = { name = "test" } })
    end)
    assert.is_false(success)
    assert.match("invalid syntax", err:lower())
end

return tests

