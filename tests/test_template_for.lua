local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- Iteration with For Loops: {% for/endfor %} loop parsing

-- Happy Path Tests

function tests.test_for_endfor_basic_array()
    local template = Template([[
<ul>
  {% for item in items %}
  <li>{{ item }}</li>
  {% endfor %}
</ul>
]])
    local result = template({ items = { "Apple", "Banana", "Orange" } })
    assert.equal(
        [[
<ul>
  
  <li>Apple</li>
  
  <li>Banana</li>
  
  <li>Orange</li>
  
</ul>
]],
        result
    )
end

function tests.test_for_endfor_empty_array()
    local template = Template([[
<ul>
  {% for item in items %}
  <li>{{ item }}</li>
  {% endfor %}
</ul>
]])
    local result = template({ items = {} })
    assert.equal(
        [[
<ul>
  
</ul>
]],
        result
    )
end

function tests.test_for_endfor_key_value_pairs()
    local template = Template([[
<dl>
  {% for key, value in pairs(user) %}
  <dt>{{ key }}</dt>
  <dd>{{ value }}</dd>
  {% endfor %}
</dl>
]])
    local result = template({ user = { name = "Alice", age = 30, role = "admin" } })
    -- Note: pairs() order is not guaranteed, so we check for presence of content
    assert.match("<dt>name</dt>", result)
    assert.match("<dd>Alice</dd>", result)
    assert.match("<dt>age</dt>", result)
    assert.match("<dd>30</dd>", result)
    assert.match("<dt>role</dt>", result)
    assert.match("<dd>admin</dd>", result)
end

function tests.test_for_endfor_indexed_array()
    local template = Template([[
<table>
  <tr><th>#</th><th>Item</th></tr>
  {% for index, item in ipairs(items) %}
  <tr>
    <td>{{ index }}</td>
    <td>{{ item.name }}</td>
  </tr>
  {% endfor %}
</table>
]])
    local result = template({
        items = {
            { name = "Apple" },
            { name = "Banana" },
        },
    })
    assert.equal(
        [[
<table>
  <tr><th>#</th><th>Item</th></tr>
  
  <tr>
    <td>1</td>
    <td>Apple</td>
  </tr>
  
  <tr>
    <td>2</td>
    <td>Banana</td>
  </tr>
  
</table>
]],
        result
    )
end

function tests.test_for_endfor_nested_loops()
    local template = Template([[
{% for category in categories %}
<h2>{{ category.name }}</h2>
<ul>
  {% for item in category.items %}
  <li>{{ item }}</li>
  {% endfor %}
</ul>
{% endfor %}
]])
    local result = template({
        categories = {
            { name = "Fruits", items = { "Apple", "Banana" } },
            { name = "Vegetables", items = { "Carrot", "Broccoli" } },
        },
    })
    assert.equal(
        [[

<h2>Fruits</h2>
<ul>
  
  <li>Apple</li>
  
  <li>Banana</li>
  
</ul>

<h2>Vegetables</h2>
<ul>
  
  <li>Carrot</li>
  
  <li>Broccoli</li>
  
</ul>

]],
        result
    )
end

function tests.test_for_endfor_with_expressions()
    local template = Template([[
{% for user in users %}
{% if user.active %}
<div class="user">{{ user.name }}</div>
{% endif %}
{% endfor %}
]])
    local result = template({
        users = {
            { name = "Alice", active = true },
            { name = "Bob", active = false },
            { name = "Charlie", active = true },
        },
    })
    assert.equal(
        [[


<div class="user">Alice</div>





<div class="user">Charlie</div>


]],
        result
    )
end

function tests.test_for_endfor_with_complex_expressions()
    local template = Template([[
{% for item in items %}
<p>{{ item.name }} - ${{ item.price * 1.1 }}</p>
{% endfor %}
]])
    local result = template({
        items = {
            { name = "Apple", price = 1.00 },
            { name = "Banana", price = 0.50 },
        },
    })
    assert.equal(
        [[

<p>Apple - $1.1</p>

<p>Banana - $0.55</p>

]],
        result
    )
end

function tests.test_for_endfor_variable_scope()
    local template = Template([[
{% for item in items %}
<p>Item: {{ item }}</p>
{% endfor %}
<p>Outside: {{ item or "undefined" }}</p>
]])
    local result = template({ items = { "A", "B" } })
    assert.equal(
        [[

<p>Item: A</p>

<p>Item: B</p>

<p>Outside: undefined</p>
]],
        result
    )
end

-- Error Path Tests

function tests.test_for_endfor_unclosed_block()
    local success, err = pcall(function()
        local template = Template("{% for item in items %}<p>{{ item }}</p>")
        template({ items = { "test" } })
    end)
    assert.is_false(success)
    assert.is_string(err)
    assert.match("unclosed", err:lower())
end

function tests.test_for_endfor_missing_endfor()
    local success, err = pcall(function()
        local template = Template("<p>{{ item }}</p>{% endfor %}")
        template({})
    end)
    assert.is_false(success)
    assert.is_string(err)
    assert.match("unexpected", err:lower())
end

function tests.test_for_endfor_missing_variable()
    local success, err = pcall(function()
        local template = Template("{% for in items %}{{ item }}{% endfor %}")
        template({ items = { "test" } })
    end)
    assert.is_false(success)
    assert.is_string(err)
    assert.match("expected", err:lower())
end

function tests.test_for_endfor_missing_in_keyword()
    local success, err = pcall(function()
        local template = Template("{% for item items %}{{ item }}{% endfor %}")
        template({ items = { "test" } })
    end)
    assert.is_false(success)
    assert.is_string(err)
    assert.match("expected", err:lower())
end

function tests.test_for_endfor_missing_expression()
    local success, err = pcall(function()
        local template = Template("{% for item in %}{{ item }}{% endfor %}")
        template({ items = { "test" } })
    end)
    assert.is_false(success)
    assert.is_string(err)
    assert.match("empty", err:lower())
end

function tests.test_for_endfor_empty_for_block()
    local success, err = pcall(function()
        local template = Template("{% for %}{{ item }}{% endfor %}")
        template({ items = { "test" } })
    end)
    assert.is_false(success)
    assert.is_string(err)
    assert.match("expected", err:lower())
end

function tests.test_for_endfor_nil_collection()
    local template = Template([[
{% for item in items %}
<p>{{ item }}</p>
{% endfor %}
]])
    local result = template({ items = nil })
    assert.equal(
        [[
<p></p>
]],
        result
    )
end

function tests.test_for_endfor_non_iterable()
    local success, err = pcall(function()
        local template = Template("{% for item in items %}{{ item }}{% endfor %}")
        template({ items = "not_an_array" })
    end)
    -- This should not crash, but may produce empty output
    -- Lua's generic for handles non-iterables gracefully
    assert.is_true(success)
end

return tests
