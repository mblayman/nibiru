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

-- Test multi-line list items (bug: continuation lines treated as separate paragraphs)
function tests.test_multiline_list_items()
    local content = [[
* Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod
  tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
  quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
  consequat.
* Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore
  eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident,
  sunt in culpa qui officia deserunt mollit anim id est laborum.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Expected: Two list items in a single unordered list
    -- The continuation lines should be part of the list items, not separate paragraphs
    local expected_pattern = "<ul>.-<li>.-</li>.-<li>.-</li>.-</ul>"
    assert(result.html:match(expected_pattern) ~= nil, "Should contain a single ul with two li elements")

    -- Should not contain paragraph tags between list items
    -- This would indicate the bug where continuation lines become separate paragraphs
    local paragraphs_between_lists = result.html:match("<ul>.-</ul>.-<p>.-</p>.-<ul>")
    assert(paragraphs_between_lists == nil, "Should not have paragraphs between list items - continuation lines should stay in list items")

    -- Count list items - should be exactly 2
    local li_count = 0
    for _ in result.html:gmatch("<li>") do
        li_count = li_count + 1
    end
    assert(li_count == 2, string.format("Expected 2 list items, but found %d", li_count))

    -- Count ul tags - should be exactly 1 (single list)
    local ul_count = 0
    for _ in result.html:gmatch("<ul>") do
        ul_count = ul_count + 1
    end
    assert(ul_count == 1, string.format("Expected 1 unordered list, but found %d", ul_count))
end

-- Test multi-line ordered list items (similar to unordered test)
function tests.test_multiline_ordered_list_items()
    local content = [[
1. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod
   tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
   quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
   consequat.
2. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore
   eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident,
   sunt in culpa qui officia deserunt mollit anim id est laborum.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Expected: Two list items in a single ordered list
    -- The continuation lines should be part of the list items, not separate paragraphs
    local expected_pattern = "<ol>.-<li>.-</li>.-<li>.-</li>.-</ol>"
    assert(result.html:match(expected_pattern) ~= nil, "Should contain a single ol with two li elements")

    -- Should not contain paragraph tags between list items
    -- This would indicate the bug where continuation lines become separate paragraphs
    local paragraphs_between_lists = result.html:match("<ol>.-</ol>.-<p>.-</p>.-<ol>")
    assert(paragraphs_between_lists == nil, "Should not have paragraphs between list items - continuation lines should stay in list items")

    -- Count list items - should be exactly 2
    local li_count = 0
    for _ in result.html:gmatch("<li>") do
        li_count = li_count + 1
    end
    assert(li_count == 2, string.format("Expected 2 list items, but found %d", li_count))

    -- Count ol tags - should be exactly 1 (single list)
    local ol_count = 0
    for _ in result.html:gmatch("<ol>") do
        ol_count = ol_count + 1
    end
    assert(ol_count == 1, string.format("Expected 1 ordered list, but found %d", ol_count))
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

