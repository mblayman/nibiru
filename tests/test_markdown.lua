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
    assert(result.html:find("<h1>Hello World</h1>") ~= nil)
    assert(result.html:find("<strong>bold</strong>") ~= nil)
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
            email = "john@example.com",
        },
    })

    -- Check markdown content (should not include frontmatter)
    assert(result.markdown:find("^# My Blog Post") ~= nil)
    assert(result.html:find("<h1>My Blog Post</h1>") ~= nil)
    assert(result.html:find("<strong>markdown</strong>") ~= nil)
    assert(result.html:find("<em>formatting</em>") ~= nil)
    assert(result.html:find("<pre><code") ~= nil)
    assert(result.html:find("<blockquote>") ~= nil)
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
    assert(result.markdown:find("^# Content") ~= nil)
    assert(result.html:find("<h1>Content</h1>") ~= nil)
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
    assert(result.html:find("<h1>Header 1</h1>") ~= nil)
    assert(result.html:find("<h2>Header 2</h2>") ~= nil)
    assert(result.html:find("<strong>Bold text</strong>") ~= nil)
    assert(result.html:find("<em>italic text</em>") ~= nil)
    assert(result.html:find("<ol>") ~= nil)
    assert(result.html:find("<ul>") ~= nil)
    assert(result.html:find("<a href=") ~= nil)
    assert(result.html:find("<img") ~= nil)
    assert(result.html:find("<table>") ~= nil)
end

-- Test inline code
function tests.test_inline_code()
    local content = "Use `print()` function in Lua."
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert(result.html:find("<code>print%(%)</code>") ~= nil)
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
    assert(result.html:find("<pre><code") ~= nil)
    assert(result.html:find("function hello") ~= nil)
end

-- Test strikethrough
function tests.test_strikethrough()
    local content = "This is ~~deleted~~ text."
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert(result.html:find("<del>deleted</del>") ~= nil)
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
    assert(result.html:find("<hr>") ~= nil)
end

-- ERROR TESTS --

-- Test invalid input type
function tests.test_invalid_input_type()
    local result, err = markdown.parse(123)
    assert.is_nil(result)
    assert(err:find("expected string") ~= nil)
end

-- Test nil input
function tests.test_nil_input()
    local result, err = markdown.parse(nil)
    assert.is_nil(result)
    assert(err:find("expected string") ~= nil)
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
    assert(err:find("missing closing") ~= nil)
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
    assert(string.find(err, "invalid YAML syntax", 1, true) ~= nil)
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
    assert(string.find(err, "YAML frontmatter must appear at the beginning of the document", 1, true) ~= nil)
end

return tests

