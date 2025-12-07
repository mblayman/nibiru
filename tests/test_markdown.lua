local assert = require("luassert")
local markdown = require("nibiru.markdown")

local tests = {}

-- Test basic markdown without frontmatter
function tests.test_basic_markdown()
    local content = "# Hello World\n\nThis is a **bold** test."
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_table(result)
    assert.same(result.frontmatter, {})
    assert.equals(result.markdown, content)
    assert.is_string(result.html)
    assert.match(result.html, "<h1>Hello World</h1>")
    assert.match(result.html, "<strong>bold</strong>")
end

-- Test markdown with YAML frontmatter
function tests.test_markdown_with_frontmatter()
    local content = [[
---
title: "My Blog Post"
date: "2024-01-01"
published: true
tags: [lua, web, tutorial]
author:
  name: "John Doe"
  email: "john@example.com"
---

# My Blog Post

This is a **markdown** post with some *formatting*.

## Code Example

```lua
print("Hello, World!")
```

> This is a blockquote.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_table(result)

    -- Check frontmatter
    assert.same(result.frontmatter, {
        title = "My Blog Post",
        date = "2024-01-01",
        published = true,
        tags = { "lua", "web", "tutorial" },
        author = {
            name = "John Doe",
            email = "john@example.com"
        }
    })

    -- Check markdown content (should not include frontmatter)
    assert.match(result.markdown, "^# My Blog Post")
    assert.is_string(result.html)
    assert.match(result.html, "<h1>My Blog Post</h1>")
    assert.match(result.html, "<strong>markdown</strong>")
    assert.match(result.html, "<em>formatting</em>")
    assert.match(result.html, "<pre><code")
    assert.match(result.html, "<blockquote>")
end

-- Test empty frontmatter
function tests.test_empty_frontmatter()
    local content = [[
---

# Content
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.same(result.frontmatter, {})
    assert.match(result.markdown, "^# Content")
    assert.match(result.html, "<h1>Content</h1>")
end

-- Test frontmatter only
function tests.test_frontmatter_only()
    local content = [[
---
title: "Test"
value: 42
---
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.same(result.frontmatter, { title = "Test", value = 42 })
    assert.equals(result.markdown, "")
    assert.equals(result.html, "")
end

-- Test complex markdown features
function tests.test_complex_markdown()
    local content = [[
# Header 1
## Header 2

**Bold text** and *italic text*.

1. First item
2. Second item

- Bullet 1
- Bullet 2
  - Nested bullet

[Link](https://example.com)
![Image](test.jpg)

| Table | Header |
|-------|--------|
| Cell  | Data   |
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)
    assert.match(result.html, "<h1>Header 1</h1>")
    assert.match(result.html, "<h2>Header 2</h2>")
    assert.match(result.html, "<strong>Bold text</strong>")
    assert.match(result.html, "<em>italic text</em>")
    assert.match(result.html, "<ol>")
    assert.match(result.html, "<ul>")
    assert.match(result.html, "<a href=")
    assert.match(result.html, "<img")
    assert.match(result.html, "<table>")
end

-- Test inline code
function tests.test_inline_code()
    local content = "Use `print()` function in Lua."
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.match(result.html, "<code>print%(%)</code>")
end

-- Test code block with language
function tests.test_code_block()
    local content = [[
```lua
function hello()
    print("Hello, World!")
end
```
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.match(result.html, "<pre><code")
    assert.match(result.html, "function hello")
end

-- Test strikethrough
function tests.test_strikethrough()
    local content = "This is ~~deleted~~ text."
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.match(result.html, "<del>deleted</del>")
end

-- Test horizontal rule
function tests.test_horizontal_rule()
    local content = [[
Before

---

After
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.match(result.html, "<hr>")
end

-- ERROR TESTS --

-- Test invalid input type
function tests.test_invalid_input_type()
    local result, err = markdown.parse(123)
    assert.is_nil(result)
    assert.match(err, "expected string")
end

-- Test nil input
function tests.test_nil_input()
    local result, err = markdown.parse(nil)
    assert.is_nil(result)
    assert.match(err, "expected string")
end

-- Test malformed YAML frontmatter - missing closing delimiter
function tests.test_malformed_frontmatter_missing_closing()
    local content = [[
---
title: Test
# Content
]]
    local result, err = markdown.parse(content)
    assert.is_nil(result)
    assert.match(err, "missing closing")
end

-- Test malformed YAML frontmatter - invalid syntax
function tests.test_malformed_frontmatter_invalid_syntax()
    local content = [[
---
title
---
# Content
]]
    local result, err = markdown.parse(content)
    assert.is_nil(result)
    assert.match(err, "parsing error")
end

-- Test frontmatter not at start
function tests.test_frontmatter_not_at_start()
    local content = [[
# Content first
---
title: Test
---
]]
    local result, err = markdown.parse(content)
    assert.is_nil(result)
    assert.match(err, "parsing error")
end

-- Test bad YAML indentation
function tests.test_bad_yaml_indentation()
    local content = [[
---
author:
  name: John
    email: john@example.com
---
# Content
]]
    local result, err = markdown.parse(content)
    assert.is_nil(result)
    assert.match(err, "parsing error")
end

return tests