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

-- Test that inline HTML tags are escaped
function tests.test_inline_html_escaped()
    local content = [[
This is <em>emphasized</em> text with <strong>bold</strong> elements.

Also includes <a href="https://example.com">links</a> and <img src="test.jpg" alt="image">.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- HTML tags in regular text should be escaped
    assert(result.html:find("&lt;em&gt;emphasized&lt;/em&gt;") ~= nil, "em tag should be escaped")
    assert(result.html:find("&lt;strong&gt;bold&lt;/strong&gt;") ~= nil, "strong tag should be escaped")
    assert(result.html:find('&lt;a href=&quot;https://example.com&quot;&gt;links&lt;/a&gt;') ~= nil, "a tag should be escaped")
    assert(result.html:find('&lt;img src=&quot;test.jpg&quot; alt=&quot;image&quot;&gt;') ~= nil, "img tag should be escaped")

    -- Ensure no unescaped HTML
    assert(result.html:find("<em>") == nil, "HTML should be escaped")
    assert(result.html:find("<strong>") == nil, "HTML should be escaped")
end

-- Test HTML blocks (type 1: pre, script, style, textarea)
function tests.test_html_blocks_type1()
    local content = [[
Before

<pre>
This is <b>preformatted</b> text
with HTML tags that should remain unescaped.
</pre>

After
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Pre block should be preserved with internal HTML unescaped
    assert(result.html:find("<pre>") ~= nil, "pre tag should be preserved")
    assert(result.html:find("<b>preformatted</b>") ~= nil, "HTML inside pre should be unescaped")
    assert(result.html:find("</pre>") ~= nil, "closing pre tag should be preserved")
end

-- Test HTML comments
function tests.test_html_comments()
    local content = [[
This is visible text.

<!-- This is a comment that should be preserved -->

More visible text.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Comment should be preserved
    assert(result.html:find("This is a comment that should be preserved", 1, true) ~= nil, "HTML comment should be preserved")
end

-- Test processing instructions
function tests.test_processing_instructions()
    local content = [[
Content before.

<?xml version="1.0" encoding="UTF-8"?>

Content after.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Processing instruction should be preserved
    assert(result.html:find('version="1.0" encoding="UTF-8"', 1, true) ~= nil, "XML processing instruction should be preserved")
end

-- Test CDATA sections
function tests.test_cdata_sections()
    local content = [=[
Before CDATA.

<![CDATA[
This is <b>CDATA</b> content with <em>HTML</em> tags
that should remain unescaped.
]]>

After CDATA.
]=]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- CDATA section should be preserved
    assert(string.find(result.html, "<![CDATA[", 1, true) ~= nil, "CDATA start should be preserved")
    assert(result.html:find("<b>CDATA</b>") ~= nil, "HTML inside CDATA should be unescaped")
    assert(string.find(result.html, "]]>", 1, true) ~= nil, "CDATA end should be preserved")
end

-- Test declarations
function tests.test_declarations()
    local content = [[
Before declaration.

<!DOCTYPE html>

After declaration.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Declaration should be preserved
    assert(result.html:find("<!DOCTYPE html>") ~= nil, "DOCTYPE declaration should be preserved")
end

-- Test block-level HTML tags (type 6)
function tests.test_block_level_html()
    local content = [[
Before div.

<div class="container">
  <p>This is a paragraph inside HTML.</p>
  <ul>
    <li>Item 1</li>
    <li>Item 2</li>
  </ul>
</div>

After div.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Block-level HTML should be preserved
    assert(result.html:find('<div class="container">') ~= nil, "div tag should be preserved")
    assert(result.html:find('<p>This is a paragraph inside HTML.</p>') ~= nil, "p tag inside HTML should be preserved")
    assert(result.html:find('<ul>') ~= nil, "ul tag inside HTML should be preserved")
    assert(result.html:find('<li>Item 1</li>') ~= nil, "li tags inside HTML should be preserved")
    assert(result.html:find('</div>') ~= nil, "closing div tag should be preserved")
end

-- Test that HTML tags in paragraphs are escaped
function tests.test_html_tags_in_paragraph_escaped()
    local content = [[D3 uses SVG (Scalable Vector Graphics) to draw its shapes. It's possible to
create a new `<svg>` tag on the fly, but I added the following to the HTML
source code.]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- HTML tags in code spans should be escaped
    assert(string.find(result.html, '&lt;svg&gt;', 1, true) ~= nil, "svg tag should be escaped in code span")
    assert(result.html:find('<svg>') == nil, "svg tag should not be preserved unescaped")

    -- Regular markdown should still work
    assert(result.html:find('<p>') ~= nil, "Should be wrapped in paragraph tags")
    assert(result.html:find('<code>') ~= nil, "Should have code span for backticked content")
end

-- Test mixed HTML and Markdown
function tests.test_mixed_html_markdown()
    local content = [=[
# Markdown Header

<div class="content">
  <h2>HTML Header</h2>
  <p>This is HTML paragraph with <em>emphasis</em>.</p>
</div>

## Another Markdown Header

* Markdown list item with <code>inline code</code>.
* Another item with <strong>bold HTML</strong>.

<script>
  console.log("This is JavaScript");
</script>
]=]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Markdown should be processed
    assert(result.html:find("<h1>Markdown Header</h1>") ~= nil, "Markdown h1 should be processed")
    assert(result.html:find("<h2>Another Markdown Header</h2>") ~= nil, "Markdown h2 should be processed")
    assert(result.html:find("<em>emphasis</em>") ~= nil, "Markdown emphasis should be processed")
    assert(result.html:find("<ul>") ~= nil, "Markdown list should be processed")
    assert(result.html:find("<li>") ~= nil, "Markdown list items should be processed")

    -- HTML should be preserved
    assert(result.html:find('<div class="content">') ~= nil, "HTML div should be preserved")
    assert(result.html:find('<h2>HTML Header</h2>') ~= nil, "HTML h2 should be preserved")
    assert(result.html:find('<script>') ~= nil, "HTML script tag should be preserved")
    assert(string.find(result.html, 'console.log("This is JavaScript");', 1, true) ~= nil, "JavaScript content should be preserved")
    assert(result.html:find('</script>') ~= nil, "Closing script tag should be preserved")
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

-- Test HTML anchor tag followed by header (demonstrates reported parsing bug)
function tests.test_html_anchor_with_header()
    local content = [[<a id='marking'></a>
## Marking strings]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- The anchor tag should be preserved as raw HTML (unescaped)
    assert(result.html:find("<a id='marking'></a>", 1, true) ~= nil,
           "Anchor tag should be preserved as raw HTML")

    -- The header should be parsed as H2
    assert(result.html:find("<h2>Marking strings</h2>", 1, true) ~= nil,
           "Header should be parsed to H2 tag")

    -- Ensure no escaped HTML entities in the anchor tag
    assert(result.html:find("&lt;a") == nil,
           "Anchor tag should not be HTML-escaped")
    assert(result.html:find("&gt;") == nil,
           "Anchor tag should not contain escaped angle brackets")
end

return tests

