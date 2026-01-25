# Nibiru Markdown Support

Nibiru provides native Markdown parsing with YAML frontmatter support, designed for content-heavy applications like blogs, documentation sites, and static content generation. The parser accepts string input and returns structured data with parsed frontmatter, raw markdown, and rendered HTML output.

## Basic Usage

Import the markdown module and parse content strings:

```lua
local markdown = require("nibiru.markdown")

local content = [[
---
title: My Blog Post
date: 2024-01-01
author: John Doe
tags: [lua, web, tutorial]
---

# My Blog Post

This is a **markdown** post with some *formatting*.

## Code Example

&#96;&#96;&#96;lua
print("Hello, World!")
&#96;&#96;&#96;

> This is a blockquote.
]]

local result, err = markdown.parse(content)
if not result then
    error("Failed to parse markdown: " .. err)
end
```

The `parse` function returns a table with three keys on success:

- **`frontmatter`**: Table containing parsed YAML frontmatter data
- **`markdown`**: String containing the raw markdown content (without frontmatter)
- **`html`**: String containing the rendered HTML output

```lua
print(result.frontmatter.title)    -- "My Blog Post"
print(result.frontmatter.date)     -- "2024-01-01"
print(result.frontmatter.author)   -- "John Doe"
print(#result.frontmatter.tags)    -- 3

print(result.markdown)  -- Raw markdown without frontmatter
print(result.html)      -- Rendered HTML
```

## YAML Frontmatter Format

YAML frontmatter must appear at the beginning of the content, delimited by `---` markers:

```yaml
---
title: Document Title
description: A brief description
date: 2024-01-01
published: true
tags: [tag1, tag2, tag3]
author:
  name: John Doe
  email: john@example.com
---

# Document Content

Your markdown content goes here...
```

### Supported YAML Types

The parser supports primitive YAML types:

- **Strings**: `"quoted strings"` or `unquoted strings`
- **Numbers**: `42`, `3.14`
- **Booleans**: `true`, `false`
- **Arrays**: `[item1, item2, item3]` or multi-line with `- `
- **Objects**: Nested key-value structures
- **Folded Block Scalars**: Multi-line strings using `>` or `>-` (line breaks converted to spaces, with `>-` stripping trailing newlines)

```yaml
---
# Basic types
title: "My Title"
count: 42
enabled: true

# Arrays
tags: [lua, web, markdown]

# Multi-line arrays
categories:
 - Personal
 - Work

# Nested objects
author:
  name: "John Doe"
  email: "john@example.com"
  social:
    twitter: "@johndoe"
    github: "johndoe"

# Folded block scalars
description: >
  This is a multi-line description
  where line breaks are converted to spaces.

# Folded block scalars with chomp (strips trailing newline)
summary: >-
  This is a multi-line summary
  where line breaks are converted to spaces
  and trailing newlines are removed.
---
```

### Frontmatter Parsing Rules

- **Required delimiters**: Frontmatter must start and end with `---`
- **Position**: Must be the first content in the string
- **Empty frontmatter**: `---\n---\n` is valid and returns an empty table
- **Optional**: Content without frontmatter is valid and returns empty frontmatter table

```lua
-- Valid: Content with frontmatter
local result1, err1 = markdown.parse("---\ntitle: Test\n---\n# Content")
if not result1 then error("Parse failed: " .. err1) end

-- Valid: Content without frontmatter
local result2, err2 = markdown.parse("# Content without frontmatter")
if not result2 then error("Parse failed: " .. err2) end

-- Invalid: Frontmatter not at start
local result3, err3 = markdown.parse("# Content\n---\ntitle: Test\n---")
if not result3 then
    print("Expected error:", err3)  -- Will show "YAML frontmatter must appear at the beginning of the document"
end
```

## Markdown Rendering

The parser uses a full-featured Markdown renderer supporting:

### Footnotes

See the [Footnotes](#footnotes) section below for detailed documentation.

### Headers

```markdown
# H1 Header
## H2 Header
### H3 Header
#### H4 Header
##### H5 Header
###### H6 Header
```

### Text Formatting
```markdown
**bold text**
*italic text*
_italic text_
`inline code`
~~strikethrough~~
```

### Lists

```markdown
1. Ordered list item 1
2. Ordered list item 2

- Unordered list item
- Another item
  - Nested item
```

### Links and Images

```markdown
[Link text](https://example.com)
![Alt text](image.jpg)
```

### Code Blocks

```markdown
&#96;&#96;&#96;lua
function hello()
    print("Hello, World!")
end
&#96;&#96;&#96;
```

### Blockquotes

```markdown
> This is a blockquote
> with multiple lines
```

#### Aside Blockquotes

Nibiru supports a special aside blockquote syntax inspired by GitHub Markdown. Blockquotes that start with `[!ASIDE]` are rendered as semantic `<aside>` HTML elements instead of `<blockquote>` elements.

```markdown
> [!ASIDE]
> This is an aside note that will be rendered
> as an `<aside>` HTML element.

> [!ASIDE] You can also write aside content on the same line.
```

**Rendered HTML:**
```html
<aside>
<p>This is an aside note that will be rendered as an <code>&lt;aside&gt;</code> HTML element.</p>
</aside>

<aside>
<p>You can also write aside content on the same line.</p>
</aside>
```

Aside blockquotes are useful for:
- Side notes and annotations
- Supplementary information
- Highlighted content that differs from regular quotations
- Content that should be visually distinct from standard blockquotes

The `[!ASIDE]` marker is not included in the rendered output.

### Tables

```markdown
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |
```

### Footnotes

Nibiru supports footnotes using a syntax similar to GitHub Flavored Markdown and Hugo. Footnotes allow you to add references and additional content that appears at the bottom of the document.

#### Footnote References

Create a footnote reference in your text using square brackets with a caret:

```markdown
This is a sentence with a footnote.[^1]
```

The footnote reference will be rendered as a superscript link:

```html
<sup id="fnref:1"><a href="#fn:1" class="footnote-ref" role="doc-noteref">1</a></sup>
```

#### Footnote Definitions

Define footnote content anywhere in the document (typically at the bottom) using the same label:

```markdown
[^1]: This is the footnote content.
```

Footnote definitions are not displayed where they appear in the markdown - they are collected and rendered at the bottom of the document.

#### Complete Example

```markdown
## Document Title

This is the main content with a footnote reference.[^1]

Later in the document, you can add another reference to the same footnote.[^1]

And here's a second footnote.[^2]

[^1]: This is the first footnote. It can contain **bold** and *italic* text,
as well as [links](https://example.com).

[^2]: This is the second footnote with multiple paragraphs.

This paragraph is still part of the second footnote.

Footnotes can span multiple lines and paragraphs.
```

**Rendered HTML:**
```html
<h2>Document Title</h2>

<p>This is the main content with a footnote reference.<sup id="fnref:1"><a href="#fn:1" class="footnote-ref" role="doc-noteref">1</a></sup></p>

<p>Later in the document, you can add another reference to the same footnote.<sup id="fnref:1"><a href="#fn:1" class="footnote-ref" role="doc-noteref">1</a></sup></p>

<p>And here's a second footnote.<sup id="fnref:2"><a href="#fn:2" class="footnote-ref" role="doc-noteref">2</a></sup></p>

<div class="footnotes" role="doc-endnotes">
<hr>
<ol>
<li id="fn:1">
<p>This is the first footnote. It can contain <strong>bold</strong> and <em>italic</em> text, as well as <a href="https://example.com">links</a>.&#160;<a href="#fnref:1" class="footnote-backref" role="doc-backlink">&#8617;&#xfe0e;</a></p>
</li>
<li id="fn:2">
<p>This is the second footnote with multiple paragraphs.</p>
<p>This paragraph is still part of the second footnote.</p>
<p>Footnotes can span multiple lines and paragraphs.&#160;<a href="#fnref:2" class="footnote-backref" role="doc-backlink">&#8617;&#xfe0e;</a></p>
</li>
</ol>
</div>
```

#### Footnote Features

- **Multiple references**: The same footnote can be referenced multiple times
- **Any label**: Labels can be numbers (`[^1]`), letters (`[^note]`), or alphanumeric (`[^note1]`)
- **Rich content**: Footnotes can contain any markdown formatting (bold, italic, links, lists, etc.)
- **Multi-paragraph**: Footnotes can span multiple paragraphs separated by blank lines
- **Order independence**: Footnote definitions can appear anywhere in the document - they will always be rendered at the end in the order they are first referenced
- **Optional definitions**: Footnote references without definitions will still render (but won't link to anything)
- **Optional references**: Footnote definitions without references will still appear at the bottom

#### Footnote Labels

Footnote labels can contain letters, numbers, and underscores. Common patterns:

```markdown
[^1]      -- Numeric labels
[^note]   -- Text labels
[^ref_1]  -- Alphanumeric with underscores
```

#### Footnote Content

Footnote content supports all standard markdown features:

```markdown
[^1]: This footnote contains:
- A list item
- Another item

And **bold text**, *italic text*, and [links](url).

It can span multiple paragraphs.
```

#### Hugo Compatibility

Nibiru's footnote implementation produces HTML output compatible with Hugo's footnote rendering, making it easy to migrate content or maintain consistency across different static site generators.

## Error Handling

The parser returns `nil, error_message` for parsing failures, allowing applications to handle errors gracefully:

### Frontmatter Errors

- **Missing closing delimiter**: `"missing closing"`
- **Invalid YAML syntax**: `"invalid YAML syntax at line X: 'problematic_line'. Expected key-value pairs in format 'key: value'"`
- **Missing opening delimiter**: `"YAML frontmatter must start with '---'"`
- **Frontmatter not at start**: `"YAML frontmatter must appear at the beginning of the document"`

```lua
local result, err = markdown.parse("---\ntitle: Test\n")  -- Missing closing ---
if not result then
    print("Error:", err)  -- "missing closing"
end

local result, err = markdown.parse("---\ntitle\n---\n")   -- Invalid YAML
if not result then
    print("Error:", err)  -- "invalid YAML syntax at line 1: 'title'. Expected key-value pairs in format 'key: value'"
end

local result, err = markdown.parse("title: Test\n")     -- Missing opening ---
if not result then
    print("Error:", err)  -- "YAML frontmatter must start with '---'"
end

local result, err = markdown.parse("# Header\n---\ntitle: Test\n---\n")  -- Frontmatter not at start
if not result then
    print("Error:", err)  -- "YAML frontmatter must appear at the beginning of the document"
end
```

### Markdown Errors

- **Invalid syntax**: Parser attempts to recover gracefully
- **Unclosed elements**: May result in unexpected HTML output

## Performance Considerations

- **Compilation**: Markdown parsing is performed at runtime
- **Caching**: Consider caching parsed results for frequently accessed content
- **Large content**: Parser handles large documents efficiently
- **Memory usage**: Parsed results include both markdown and HTML representations

## Security Notes

- **Input validation**: Always validate frontmatter data before use
- **HTML output**: Markdown rendering produces safe HTML (no script injection)
- **File access**: Parser operates on strings only (file I/O handled externally)

## API Reference

### `markdown.parse(content)`

Parses a markdown string with optional YAML frontmatter.

**Parameters:**
- `content` (string): Markdown content with optional YAML frontmatter

**Returns:** Two values
- **Success**: Table with:
  - `frontmatter` (table): Parsed YAML frontmatter data
  - `markdown` (string): Raw markdown content without frontmatter
  - `html` (string): Rendered HTML output
- **Error**: `nil, error_message` for parsing failures

**Error Cases:**
- Malformed YAML frontmatter: `"invalid key-value pair syntax"`, `"missing closing"`, `"YAML frontmatter must start with '---'"`
- Invalid input types: `"expected string"`
- Frontmatter position errors: `"YAML frontmatter must appear at the beginning of the document"`

### Frontmatter Table Structure

The `frontmatter` table preserves YAML structure:

```lua
{
    title = "My Title",
    date = "2024-01-01",
    published = true,
    tags = {"lua", "web"},
    author = {
        name = "John Doe",
        email = "john@example.com"
    }
}
```

### Type Coercion

YAML values are converted to Lua types:

- YAML `true`/`false` → Lua `true`/`false`
- YAML numbers → Lua numbers
- YAML strings → Lua strings
- YAML arrays → Lua tables with numeric indices
- YAML objects → Lua tables with string keys</content>
