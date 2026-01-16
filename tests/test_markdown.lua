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

-- Test that safe inline HTML tags are preserved while unsafe ones are escaped
function tests.test_inline_html_handling()
    local content = [[
This is <em>emphasized</em> text with <strong>bold</strong> elements and <sup>superscript</sup>.

Also includes <a href="https://example.com">links</a> and <img src="test.jpg" alt="image">.
]]
    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Safe inline HTML tags should be preserved
    assert(result.html:find("<em>emphasized</em>") ~= nil, "em tag should be preserved")
    assert(result.html:find("<strong>bold</strong>") ~= nil, "strong tag should be preserved")
    assert(result.html:find("<sup>superscript</sup>") ~= nil, "sup tag should be preserved")

    -- Unsafe HTML tags should be escaped
    assert(result.html:find('&lt;a href=&quot;https://example.com&quot;&gt;links&lt;/a&gt;') ~= nil, "a tag should be escaped")
    assert(result.html:find('&lt;img src=&quot;test.jpg&quot; alt=&quot;image&quot;&gt;') ~= nil, "img tag should be escaped")

    -- Ensure no unescaped unsafe HTML
    assert(result.html:find("<a href=") == nil, "Unsafe HTML should be escaped")
    assert(result.html:find("<img") == nil, "Unsafe HTML should be escaped")
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

-- Test that HTML tags in code spans are escaped while safe inline HTML works in regular text
function tests.test_html_in_code_vs_inline()
    local content = [[D3 uses SVG (Scalable Vector Graphics) to draw its shapes. It's possible to
create a new `<svg>` tag on the fly, but I added <sup>superscript</sup> to the HTML
source code.]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- HTML tags in code spans should be escaped
    assert(string.find(result.html, '&lt;svg&gt;', 1, true) ~= nil, "svg tag should be escaped in code span")
    assert(result.html:find('<svg>') == nil, "svg tag should not be preserved unescaped")

    -- Safe inline HTML should work in regular text
    assert(result.html:find('<sup>superscript</sup>') ~= nil, "sup tag should be preserved in regular text")

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

-- Test lazy blockquotes (continuation lines without > marker)
function tests.test_lazy_blockquotes()
    local content = [[
> Why then does this sentiment
about deep understanding
of software abstractions
**as a requirement**
gain such traction?
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should be a single blockquote containing all lines
    assert(result.html:find("<blockquote>") ~= nil, "Should contain blockquote tag")
    assert(result.html:find("</blockquote>") ~= nil, "Should contain closing blockquote tag")

    -- Count blockquote tags - should be exactly one opening and one closing
    local open_count = 0
    for _ in result.html:gmatch("<blockquote>") do
        open_count = open_count + 1
    end
    local close_count = 0
    for _ in result.html:gmatch("</blockquote>") do
        close_count = close_count + 1
    end
    assert(open_count == 1, string.format("Expected 1 opening blockquote tag, but found %d", open_count))
    assert(close_count == 1, string.format("Expected 1 closing blockquote tag, but found %d", close_count))

    -- Should have one paragraph inside the blockquote, none outside
    local para_count = 0
    for _ in result.html:gmatch("<p>") do
        para_count = para_count + 1
    end
    assert(para_count == 1, string.format("Expected 1 paragraph inside blockquote, but found %d", para_count))

    -- The blockquote content should contain all the text
    assert(result.html:find("Why then does this sentiment") ~= nil, "First line should be in blockquote")
    assert(result.html:find("about deep understanding") ~= nil, "Continuation line should be in blockquote")
    assert(result.html:find("of software abstractions") ~= nil, "Another continuation line should be in blockquote")
    assert(result.html:find("as a requirement") ~= nil, "Line with bold should be in blockquote")
    assert(result.html:find("gain such traction") ~= nil, "Last line should be in blockquote")

    -- Bold formatting should be preserved inside blockquote
    assert(result.html:find("<strong>as a requirement</strong>") ~= nil, "Bold formatting should work inside lazy blockquote")
end

-- Test that raw HTML tags like <sup> are preserved and not escaped
function tests.test_raw_html_tags_preserved()
    local content = "oscillating at 650 x 10<sup>12</sup> Hz"

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- The sup tag should be preserved as raw HTML (unescaped)
    assert(result.html:find("<sup>12</sup>", 1, true) ~= nil,
           "sup tag should be preserved as raw HTML")

    -- Ensure no escaped HTML entities in the sup tag
    assert(result.html:find("&lt;sup&gt;") == nil,
           "sup tag should not be HTML-escaped")
    assert(result.html:find("&lt;/sup&gt;") == nil,
           "closing sup tag should not be HTML-escaped")

    -- Test other common raw HTML tags
    local content2 = "This is <sub>subscript</sub> and <kbd>Ctrl+C</kbd> text."
    local result2, err2 = markdown.parse(content2)
    assert.is_nil(err2)
    assert(result2.html:find("<sub>subscript</sub>", 1, true) ~= nil,
           "sub tag should be preserved")
    assert(result2.html:find("<kbd>Ctrl+C</kbd>", 1, true) ~= nil,
           "kbd tag should be preserved")
end

-- Test blockquote bug: empty blockquote continuation lines should not create separate blockquotes
function tests.test_blockquote_empty_continuation_bug()
    local content = [[
> **waffle**: verb - EQUIVOCATE, VACILLATE
>
> [Merriam-Webster](https://www.merriam-webster.com/dictionary/waffle)
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain blockquote tags
    assert(result.html:find("<blockquote>") ~= nil, "Should contain blockquote opening tag")
    assert(result.html:find("</blockquote>") ~= nil, "Should contain blockquote closing tag")

    -- Count blockquote tags - should be exactly one opening and one closing
    local open_count = 0
    for _ in result.html:gmatch("<blockquote>") do
        open_count = open_count + 1
    end
    local close_count = 0
    for _ in result.html:gmatch("</blockquote>") do
        close_count = close_count + 1
    end
    assert(open_count == 1, string.format("Expected 1 opening blockquote tag, but found %d", open_count))
    assert(close_count == 1, string.format("Expected 1 closing blockquote tag, but found %d", close_count))

    -- All content should be inside the single blockquote
    assert(result.html:find("waffle") ~= nil, "First line content should be in blockquote")
    assert(result.html:find("Merriam") ~= nil, "Link should be in blockquote")
    assert(result.html:find("href=") ~= nil, "Link should be in blockquote")
end

-- Test blockquote with bold text (demonstrates the reported bug)
function tests.test_blockquote_bold_text_bug()
    local content = [[
> **What happens when a project
adopts a tool that *automatically*
sets the code style?**
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain blockquote tags
    assert(result.html:find("<blockquote>") ~= nil, "Should contain blockquote opening tag")
    assert(result.html:find("</blockquote>") ~= nil, "Should contain blockquote closing tag")

    -- Should contain one paragraph inside blockquote
    assert(result.html:find("<blockquote><p>") ~= nil, "Should have blockquote with paragraph")
    assert(result.html:find("</p></blockquote>") ~= nil, "Should close paragraph and blockquote")

    -- The entire content should be wrapped in bold tags
    assert(result.html:find("<strong>What happens when a project") ~= nil, "Should start with strong tag")
    local code_style_pos = result.html:find("sets the code style?")
    local strong_close_pos = result.html:find("</strong>")
    assert(code_style_pos ~= nil and strong_close_pos ~= nil and strong_close_pos > code_style_pos, "Should end with closing strong tag")

    -- Italic should be preserved inside bold
    assert(result.html:find("<em>automatically</em>") ~= nil, "Italic should be preserved inside bold")

    -- Should NOT have italic tags around the entire content (the bug)
    assert(result.html:find("<em>What happens when a project") == nil, "Should not have italic at start")
    assert(result.html:find("sets the code style?</em>") == nil, "Should not have italic at end")

    -- Should NOT have stray asterisks in the output
    assert(result.html:find("*<em>") == nil, "Should not have stray asterisks")
    local em_end_pos = result.html:find("</em>")
    if em_end_pos then
        local next_char = string.sub(result.html, em_end_pos + 1, em_end_pos + 1)
        assert(next_char ~= "*", "Should not have asterisk after </em>")
    end
end

-- Test aside blockquotes (new feature: > [!ASIDE] renders as <aside>)
function tests.test_aside_blockquotes()
    local content = [[
> [!ASIDE]
> This is an aside note.
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain aside tags instead of blockquote
    assert(result.html:find("<aside>") ~= nil, "Should contain aside opening tag")
    assert(result.html:find("</aside>") ~= nil, "Should contain aside closing tag")

    -- Should NOT contain blockquote tags
    assert(result.html:find("<blockquote>") == nil, "Should not contain blockquote opening tag")
    assert(result.html:find("</blockquote>") == nil, "Should not contain blockquote closing tag")

    -- Should contain the aside content
    assert(result.html:find("This is an aside note") ~= nil, "Should contain the aside content")
end

-- Test multi-line aside blockquotes
function tests.test_multiline_aside_blockquotes()
    local content = [[
> [!ASIDE]
> This is the first line of the aside.
> This is the second line.
>
> This is a continuation paragraph in the aside.
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain aside tags
    assert(result.html:find("<aside>") ~= nil, "Should contain aside opening tag")
    assert(result.html:find("</aside>") ~= nil, "Should contain aside closing tag")

    -- Should NOT contain blockquote tags
    assert(result.html:find("<blockquote>") == nil, "Should not contain blockquote opening tag")

    -- Should contain all the aside content
    assert(result.html:find("This is the first line of the aside") ~= nil, "Should contain first line")
    assert(result.html:find("This is the second line") ~= nil, "Should contain second line")
    assert(result.html:find("This is a continuation paragraph in the aside") ~= nil, "Should contain continuation paragraph")
end

-- Test aside blockquotes with content on the same line
function tests.test_aside_single_line()
    local content = "> [!ASIDE] This is an aside note on the same line."

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain aside tags instead of blockquote
    assert(result.html:find("<aside>") ~= nil, "Should contain aside opening tag")
    assert(result.html:find("</aside>") ~= nil, "Should contain aside closing tag")

    -- Should NOT contain blockquote tags
    assert(result.html:find("<blockquote>") == nil, "Should not contain blockquote opening tag")
    assert(result.html:find("</blockquote>") == nil, "Should not contain blockquote closing tag")

    -- Should contain the aside content
    assert(result.html:find("This is an aside note on the same line") ~= nil, "Should contain the aside content")
end

-- Test code block within ordered list item (reproduces the reported bug)
function tests.test_code_block_in_ordered_list()
    local content = [[
1. Start with a virtual environment.

    ```bash
    $ python3 -m venv venv && source venv/bin/activate
    ```
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain an ordered list
    assert(result.html:find("<ol>") ~= nil, "Should contain ordered list opening tag")
    assert(result.html:find("</ol>") ~= nil, "Should contain ordered list closing tag")

    -- Should contain exactly one list item
    local li_count = 0
    for _ in result.html:gmatch("<li>") do
        li_count = li_count + 1
    end
    assert(li_count == 1, string.format("Expected 1 list item, but found %d", li_count))

    -- The code block should be inside the list item, not a separate element
    -- Check that <pre><code> appears after <li> and before </li>
    local li_start = result.html:find("<li>")
    local pre_start = result.html:find("<pre><code")
    local li_end = result.html:find("</li>")
    assert(li_start ~= nil and pre_start ~= nil and li_end ~= nil, "Should find li and pre tags")
    assert(li_start < pre_start and pre_start < li_end, "Code block should be inside list item")

    -- Should NOT have the code block as a separate element after the list
    -- Check that there are no <pre><code> tags after </ol>
    local ol_end = result.html:find("</ol>")
    local pre_after_list = result.html:find("<pre><code", ol_end)
    assert(pre_after_list == nil, "Should not have code block after the list")

    -- The list item should contain both the text and the code block
    assert(result.html:find("Start with a virtual environment") ~= nil, "List item should contain the text")
    assert(result.html:find("python3") ~= nil, "List item should contain the code block content")
end

-- Test code block within unordered list item
function tests.test_code_block_in_unordered_list()
    local content = [[
* Start with a virtual environment.

    ```bash
    $ python3 -m venv venv && source venv/bin/activate
    ```
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain an unordered list
    assert(result.html:find("<ul>") ~= nil, "Should contain unordered list opening tag")
    assert(result.html:find("</ul>") ~= nil, "Should contain unordered list closing tag")

    -- Should contain exactly one list item
    local li_count = 0
    for _ in result.html:gmatch("<li>") do
        li_count = li_count + 1
    end
    assert(li_count == 1, string.format("Expected 1 list item, but found %d", li_count))

    -- The code block should be inside the list item, not a separate element
    -- Check that <pre><code> appears after <li> and before </li>
    local li_start = result.html:find("<li>")
    local pre_start = result.html:find("<pre><code")
    local li_end = result.html:find("</li>")
    assert(li_start ~= nil and pre_start ~= nil and li_end ~= nil, "Should find li and pre tags")
    assert(li_start < pre_start and pre_start < li_end, "Code block should be inside list item")

    -- Should NOT have the code block as a separate element after the list
    local ul_end = result.html:find("</ul>")
    local pre_after_list = result.html:find("<pre><code", ul_end)
    assert(pre_after_list == nil, "Should not have code block after the list")

    -- The list item should contain both the text and the code block
    assert(result.html:find("Start with a virtual environment") ~= nil, "List item should contain the text")
    assert(result.html:find("python3") ~= nil, "List item should contain the code block content")
end

-- Test that regular blockquotes still work alongside asides
function tests.test_mixed_aside_and_blockquote()
    local content = [[
> [!ASIDE]
> This is an aside.

> This is a regular blockquote.

> [!ASIDE]
> Another aside.
]]

    local result, err = markdown.parse(content)
    assert.is_nil(err)
    assert.is_string(result.html)

    -- Should contain aside tags
    local aside_open_count = 0
    for _ in result.html:gmatch("<aside>") do
        aside_open_count = aside_open_count + 1
    end
    assert(aside_open_count == 2, string.format("Expected 2 aside opening tags, but found %d", aside_open_count))

    -- Should contain blockquote tags
    assert(result.html:find("<blockquote>") ~= nil, "Should contain blockquote opening tag")

    -- Content should be in correct tags
    assert(result.html:find("This is an aside") ~= nil, "Should contain aside content")
    assert(result.html:find("This is a regular blockquote") ~= nil, "Should contain blockquote content")
    assert(result.html:find("Another aside") ~= nil, "Should contain second aside content")
end

return tests

