--- @module nibiru.markdown
--- Markdown parser with YAML frontmatter support
--- Implements a recursive descent parser supporting standard markdown features:
--- - Headers (# ## ###)
--- - Bold and italic text (**bold**, *italic*)
--- - Lists (ordered and unordered)
--- - Code blocks and inline code
--- - Links and images
--- - Tables
--- - Blockquotes
--- - Horizontal rules
--- - YAML frontmatter parsing

local yaml = require("nibiru.yaml")

--- @class markdown
--- Markdown parser module with YAML frontmatter support
local markdown = {}

--- Parse markdown content with optional YAML frontmatter
--- @param input string The markdown string to parse (may include YAML frontmatter)
--- @return table|nil result Table with frontmatter, markdown, and html fields, or nil on error
--- @return string|nil error Error message if parsing failed
--- @usage
--- local result = markdown.parse("# Hello\n\nWorld")
--- print(result.html) -- "<h1>Hello</h1>\n<p>World</p>"
--- print(result.frontmatter.title) -- Parsed YAML data
--- @usage
--- local result = markdown.parse("# Hello\n\nWorld")
--- print(result.html) -- "<h1>Hello</h1>\n<p>World</p>"
function markdown.parse(input)
    if type(input) ~= "string" then
        return nil, "expected string"
    end

    local frontmatter = {}
    local markdown_content = input

    -- Check for frontmatter not at start
    local lines = {}
    for line in input:gmatch("[^\n]*") do
        table.insert(lines, line)
    end
    for i = 2, #lines do
        if lines[i] == "---" then
            -- Check next line for YAML
            local next_line = lines[i + 1] or ""
            if next_line:match("^%s*[^%s:]+%s*:") then
                return nil, "YAML frontmatter must appear at the beginning of the document"
            end
        end
    end

    -- Parse frontmatter if present
    if input:sub(1, 4) == "---\n" then
        -- Check if there's a closing --- on its own line
        local has_closing = false
        local closing_start
        local pos = 5
        while pos <= #input do
            local line_end = input:find("\n", pos) or #input + 1
            local line = input:sub(pos, line_end - 1)
            if line == "---" then
                has_closing = true
                closing_start = pos
                break
            end
            pos = line_end + 1
        end
        
        if has_closing then
            local frontmatter_text = input:sub(1, closing_start + 2)
            local parse_result, err = yaml.parse(frontmatter_text)
            if not parse_result then
                return nil, err
            end

            frontmatter = parse_result
            markdown_content = input:sub(closing_start + 4):gsub("^%s+", "")
        else
            -- No closing ---, check if frontmatter content is empty
            local frontmatter_content = input:sub(5):match("^(.-)\n") or input:sub(5)
            if frontmatter_content:gsub("%s+", "") == "" then
                -- Empty frontmatter
                frontmatter = {}
                markdown_content = input:sub(5):gsub("^%s+", "")
            else
                -- Malformed, has content but no closing
                return nil, "missing closing"
            end
        end
    end

    -- Parse markdown to HTML
    local html, err = parse_markdown(markdown_content)
    if not html then
        return nil, err
    end

    return {
        frontmatter = frontmatter,
        markdown = markdown_content,
        html = html
    }
end

--- Parse markdown text into HTML using recursive descent parsing
--- @param text string The markdown text to parse
--- @return string html The rendered HTML string
--- @return string|nil error Error message if parsing failed (currently always returns html)
function parse_markdown(text)
    if not text or text == "" then
        return ""
    end

    local lines = {}
    for line in text:gmatch("[^\n]*") do
        table.insert(lines, line)
    end

    local html_parts = {}
    local i = 1

    while i <= #lines do
        local line = lines[i]

        -- Headers
        if line:match("^#+%s+") then
            local level = line:match("^(#+)")
            if #level >= 1 and #level <= 6 then
                local content = line:sub(#level + 2)
                table.insert(html_parts, string.format("<h%d>%s</h%d>", #level, parse_inline(content), #level))
                i = i + 1
            end

        -- Horizontal rule
        elseif line:match("^[-*_][-*_][-*_]+$") then
            table.insert(html_parts, "<hr>")
            i = i + 1

        -- Blockquote
        elseif line:match("^>%s*") then
            local blockquote_lines = {}
            while i <= #lines and lines[i]:match("^>%s*") do
                local content = lines[i]:gsub("^>%s*", "")
                table.insert(blockquote_lines, content)
                i = i + 1
            end
            local blockquote_content = table.concat(blockquote_lines, "\n")
            table.insert(html_parts, string.format("<blockquote>%s</blockquote>", parse_markdown(blockquote_content)))

        -- Code block
        elseif line:match("^```") then
            local lang = line:match("^```(%w*)")
            i = i + 1
            local code_lines = {}
            while i <= #lines and not lines[i]:match("^```") do
                table.insert(code_lines, lines[i])
                i = i + 1
            end
            i = i + 1 -- Skip closing ```
            local code = table.concat(code_lines, "\n")
            if lang and lang ~= "" then
                table.insert(html_parts, string.format('<pre><code class="language-%s">%s</code></pre>', lang, escape_html(code)))
            else
                table.insert(html_parts, string.format("<pre><code>%s</code></pre>", escape_html(code)))
            end

        -- Unordered list
        elseif line:match("^[-*+]%s+") then
            local list_items = {}
            while i <= #lines and lines[i]:match("^[-*+]%s+") do
                local content = lines[i]:gsub("^[-*+]%s+", "")
                table.insert(list_items, string.format("<li>%s</li>", parse_inline(content)))
                i = i + 1
            end
            table.insert(html_parts, string.format("<ul>%s</ul>", table.concat(list_items)))

        -- Ordered list
        elseif line:match("^%d+%.%s+") then
            local list_items = {}
            while i <= #lines and lines[i]:match("^%d+%.%s+") do
                local content = lines[i]:gsub("^%d+%.%s+", "")
                table.insert(list_items, string.format("<li>%s</li>", parse_inline(content)))
                i = i + 1
            end
            table.insert(html_parts, string.format("<ol>%s</ol>", table.concat(list_items)))

        -- Table
        elseif line:match("^|") and i + 1 <= #lines and lines[i + 1]:match("^|[-:]+|") then
            local table_html = parse_table(lines, i)
            table.insert(html_parts, table_html.html)
            i = table_html.new_index

        -- Empty line or regular paragraph
        else
            if line:match("%S") then
                -- Collect paragraph lines
                local para_lines = {line}
                i = i + 1
                while i <= #lines and lines[i]:match("%S") and not lines[i]:match("^#{1,6}%s+") and not lines[i]:match("^[-*_]{3,}$") and not lines[i]:match("^>%s*") and not lines[i]:match("^```") and not lines[i]:match("^[-*+]%s+") and not lines[i]:match("^%d+%.%s+") and not lines[i]:match("^|") do
                    table.insert(para_lines, lines[i])
                    i = i + 1
                end
                local para_content = table.concat(para_lines, "\n")
                table.insert(html_parts, string.format("<p>%s</p>", parse_inline(para_content)))
            else
                i = i + 1
            end
        end
    end

    return table.concat(html_parts, "\n")
end

--- Parse inline markdown elements within text
--- @param text string The text containing inline markdown elements
--- @return string The text with markdown elements converted to HTML
function parse_inline(text)
    if not text then return "" end

    -- Escape HTML first
    local result = escape_html(text)

    -- Code spans (escape backticks in content)
    result = result:gsub("`([^`\n]+)`", "<code>%1</code>")

    -- Strikethrough
    result = result:gsub("~~([^~\n]+)~~", "<del>%1</del>")

    -- Bold
    result = result:gsub("%*%*%*([^*]+)%*%*%*", "<strong><em>%1</em></strong>")
    result = result:gsub("%*%*([^*]+)%*%*", "<strong>%1</strong>")

    -- Italic
    result = result:gsub("%*([^*]+)%*", "<em>%1</em>")

    -- Links and images
    result = result:gsub("!%[([^%]]+)%]%(([^%)]+)%)", '<img alt="%1" src="%2">')
    result = result:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<a href="%2">%1</a>')

    return result
end

--- Parse a markdown table structure
--- @param lines table Array of lines from the markdown text
--- @param start_index number The index of the first table line
--- @return table result Table with html field containing the rendered table HTML and new_index field
function parse_table(lines, start_index)
    local headers = {}
    local alignments = {}
    local rows = {}

    -- Parse header row
    local header_line = lines[start_index]:gsub("^|", ""):gsub("|$", "")
    local header_cells = {}
    for cell in header_line:gmatch("[^|]+") do
        header_cells[#header_cells + 1] = cell:gsub("^%s+", ""):gsub("%s+$", "")
    end
    for _, cell in ipairs(header_cells) do
        headers[#headers + 1] = cell
    end

    -- Parse alignment row
    local align_line = lines[start_index + 1]:gsub("^|", ""):gsub("|$", "")
    local align_cells = {}
    for cell in align_line:gmatch("[^|]+") do
        align_cells[#align_cells + 1] = cell:gsub("^%s+", ""):gsub("%s+$", "")
    end
    for _, cell in ipairs(align_cells) do
        if cell:match("^:.*:$") then
            alignments[#alignments + 1] = "center"
        elseif cell:match("^:") then
            alignments[#alignments + 1] = "left"
        elseif cell:match(":$") then
            alignments[#alignments + 1] = "right"
        else
            alignments[#alignments + 1] = "left"
        end
    end

    -- Parse data rows
    local i = start_index + 2
    while i <= #lines and lines[i]:match("^|") do
        local row = {}
        local row_line = lines[i]:gsub("^|", ""):gsub("|$", "")
        local row_cells = {}
        for cell in row_line:gmatch("[^|]+") do
            row_cells[#row_cells + 1] = cell:gsub("^%s+", ""):gsub("%s+$", "")
        end
        for _, cell in ipairs(row_cells) do
            row[#row + 1] = cell
        end
        rows[#rows + 1] = row
        i = i + 1
    end

    -- Generate HTML
    local html = "<table>\n<thead>\n<tr>\n"
    for j, header in ipairs(headers) do
        local align = alignments[j] or "left"
        html = html .. string.format('<th style="text-align: %s">%s</th>\n', align, parse_inline(header))
    end
    html = html .. "</tr>\n</thead>\n<tbody>\n"

    for _, row in ipairs(rows) do
        html = html .. "<tr>\n"
        for j, cell in ipairs(row) do
            local align = alignments[j] or "left"
            html = html .. string.format('<td style="text-align: %s">%s</td>\n', align, parse_inline(cell))
        end
        html = html .. "</tr>\n"
    end

    html = html .. "</tbody>\n</table>"

    return {html = html, new_index = i}
end

--- Escape HTML entities in text
--- @param text string The text to escape
--- @return string The text with HTML entities escaped
function escape_html(text)
    if not text then return "" end
    return text:gsub("&", "&amp;")
               :gsub("<", "&lt;")
               :gsub(">", "&gt;")
               :gsub('"', "&quot;")
               :gsub("'", "&#39;")
end

return markdown