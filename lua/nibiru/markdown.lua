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
--- - Footnotes ([^label] and [^label]: content)
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
function parse_markdown(text, parse_lists)
    if parse_lists == nil then parse_lists = true end
    if not text or text == "" then
        return ""
    end



    local lines = {}
    for line in text:gmatch("[^\n]*") do
        table.insert(lines, line)
    end

    local html_parts = {}
    local footnotes = {}  -- Store footnote definitions: {label = content}
    local i = 1

    -- First pass: collect footnote definitions
    local content_lines = {}
    local j = 1
    while j <= #lines do
        local line = lines[j]
        -- Check if this is a footnote definition: [^label]: content
        local label = line:match("^%[%^([^%]]+)%]:%s*(.*)")
        if label then
            -- Collect continuation lines for the footnote
            local footnote_content_start = line:gsub("^%[%^[^%]]+%]:%s*", "")
            local footnote_lines = {footnote_content_start}  -- Remove the [^label]: part
            j = j + 1
            -- Continue collecting lines until we hit another footnote definition or other block element
            -- (but allow blank lines within footnotes for paragraph separation)
            while j <= #lines do
                local next_line = lines[j]

                if next_line == "" or next_line:match("^%[%^[^%]]+%]:") or next_line:match("^#{1,6}%s+") or
                   next_line:match("^[-*_]{3,}$") or next_line:match("^>%s*") or
                   next_line:match("^```") or next_line:match("^[-*+]%s+") or
                   next_line:match("^%d+%.%s+") or next_line:match("^|") or
                   next_line:match("^%s*<") then
                    -- Stop if we hit an empty line, another footnote definition, or another block element
                    j = j - 1
                    break
                end
                table.insert(footnote_lines, next_line)
                j = j + 1
            end
            -- Join footnote lines and parse as markdown
            local footnote_content = table.concat(footnote_lines, "\n")
            footnote_content = footnote_content:gsub("^%s+", ""):gsub("%s+$", "")
            footnotes[label] = parse_markdown(footnote_content)
        else
            table.insert(content_lines, line)
        end
        j = j + 1
    end

    -- Replace lines with content_lines (excluding footnote definitions)
    lines = content_lines

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
            -- First line with >
            local content = lines[i]:gsub("^>%s*", "")
            table.insert(blockquote_lines, content)
            i = i + 1

                   -- Continue collecting continuation lines until we hit a block boundary
                   while i <= #lines and
                         not lines[i]:match("^#{1,6}%s+") and
                         not lines[i]:match("^[-*_]{3,}$") and
                         not lines[i]:match("^%s*[-*+]%s+") and
                         not lines[i]:match("^%s*%d+%.%s+") and
                         not lines[i]:match("^|") and
                         lines[i] ~= "" do
                -- If this line starts with >, strip the marker and include it
                if lines[i]:match("^>%s*") then
                    local content = lines[i]:gsub("^>%s*", "")
                    table.insert(blockquote_lines, content)
                else
                    table.insert(blockquote_lines, lines[i])
                end
                i = i + 1
            end
             local blockquote_content = table.concat(blockquote_lines, "\n")

             -- Check if this is an aside blockquote (starts with [!ASIDE])
             if blockquote_lines[1] and blockquote_lines[1]:match("^%[!ASIDE%]%s*") then
                 -- Strip the [!ASIDE] marker from the first line
                 blockquote_lines[1] = blockquote_lines[1]:gsub("^%[!ASIDE%]%s*", "")
                 local aside_content = table.concat(blockquote_lines, "\n")
                 table.insert(html_parts, string.format("<aside>%s</aside>", parse_markdown(aside_content)))
             else
                 table.insert(html_parts, string.format("<blockquote>%s</blockquote>", parse_markdown(blockquote_content)))
             end

        -- HTML blocks (type 1: pre, script, style, textarea)
        elseif line:match("^%s*<pre%s*>") or line:match("^%s*<script%s*>") or
               line:match("^%s*<style%s*>") or line:match("^%s*<textarea%s*>") then
            local html_lines = {line}
            local tag_name = line:match("<(%w+)")
            local closing_tag = "</" .. tag_name .. ">"
            i = i + 1
            while i <= #lines do
                table.insert(html_lines, lines[i])
                if lines[i]:match(closing_tag) then
                    break
                end
                i = i + 1
            end
            table.insert(html_parts, table.concat(html_lines, "\n"))
            i = i + 1

        -- HTML blocks (type 2: comments)
        elseif line:match("^%s*<!%-%-") then
            local html_lines = {line}
            i = i + 1
            -- Continue until we find the closing -->
            while i <= #lines and not lines[i-1]:match("%-%->%s*$") do
                table.insert(html_lines, lines[i])
                i = i + 1
            end
            table.insert(html_parts, table.concat(html_lines, "\n"))

        -- HTML blocks (type 3: processing instructions)
        elseif line:match("^%s*<%?") then
            local html_lines = {line}
            i = i + 1
            while i <= #lines do
                table.insert(html_lines, lines[i])
                if lines[i]:match("%?>%s*$") then
                    break
                end
                i = i + 1
            end
            table.insert(html_parts, table.concat(html_lines, "\n"))
            i = i + 1

        -- HTML blocks (type 4: declarations)
        elseif line:match("^%s*<!%w") then
            local html_lines = {line}
            i = i + 1
            while i <= #lines do
                table.insert(html_lines, lines[i])
                if lines[i]:match(">%s*$") then
                    break
                end
                i = i + 1
            end
            table.insert(html_parts, table.concat(html_lines, "\n"))
            i = i + 1

        -- HTML blocks (type 5: CDATA)
        elseif line:match("^%s*<!%[CDATA%[") then
            local html_lines = {line}
            i = i + 1
            while i <= #lines do
                table.insert(html_lines, lines[i])
                if lines[i]:match("%]%]%>%s*$") then
                    break
                end
                i = i + 1
            end
            table.insert(html_parts, table.concat(html_lines, "\n"))
            i = i + 1

        -- HTML blocks (type 6: block-level tags)
        elseif line:match("^%s*<") and
              (line:match("<address%s*>") or line:match("<article%s*>") or line:match("<aside%s*>") or
               line:match("<base%s*>") or line:match("<basefont%s*>") or line:match("<blockquote%s*>") or
               line:match("<body%s*>") or line:match("<caption%s*>") or line:match("<center%s*>") or
               line:match("<col%s*>") or line:match("<colgroup%s*>") or line:match("<dd%s*>") or
               line:match("<details%s*>") or line:match("<dialog%s*>") or line:match("<dir%s*>") or
               line:match("<div%s*>") or line:match("<dl%s*>") or line:match("<dt%s*>") or
               line:match("<fieldset%s*>") or line:match("<figcaption%s*>") or line:match("<figure%s*>") or
               line:match("<footer%s*>") or line:match("<form%s*>") or line:match("<frame%s*>") or
               line:match("<frameset%s*>") or line:match("<h1%s*>") or line:match("<h2%s*>") or
               line:match("<h3%s*>") or line:match("<h4%s*>") or line:match("<h5%s*>") or
               line:match("<h6%s*>") or line:match("<head%s*>") or line:match("<header%s*>") or
               line:match("<hr%s*>") or line:match("<html%s*>") or line:match("<iframe%s*>") or
               line:match("<legend%s*>") or line:match("<li%s*>") or line:match("<link%s*>") or
               line:match("<main%s*>") or line:match("<menu%s*>") or line:match("<menuitem%s*>") or
               line:match("<nav%s*>") or line:match("<noframes%s*>") or line:match("<ol%s*>") or
               line:match("<optgroup%s*>") or line:match("<option%s*>") or line:match("<p%s*>") or
               line:match("<param%s*>") or line:match("<search%s*>") or line:match("<section%s*>") or
               line:match("<summary%s*>") or line:match("<table%s*>") or line:match("<tbody%s*>") or
               line:match("<td%s*>") or line:match("<tfoot%s*>") or line:match("<th%s*>") or
               line:match("<thead%s*>") or line:match("<title%s*>") or line:match("<tr%s*>") or
               line:match("<track%s*>") or line:match("<ul%s*>") or line:match("</") and
               (line:match("</address>") or line:match("</article>") or line:match("</aside>") or
                line:match("</base>") or line:match("</basefont>") or line:match("</blockquote>") or
                line:match("</body>") or line:match("</caption>") or line:match("</center>") or
                line:match("</col>") or line:match("</colgroup>") or line:match("</dd>") or
                line:match("</details>") or line:match("</dialog>") or line:match("</dir>") or
                line:match("</div>") or line:match("</dl>") or line:match("</dt>") or
                line:match("</fieldset>") or line:match("</figcaption>") or line:match("</figure>") or
                line:match("</footer>") or line:match("</form>") or line:match("</frame>") or
                line:match("</frameset>") or line:match("</h1>") or line:match("</h2>") or
                line:match("</h3>") or line:match("</h4>") or line:match("</h5>") or
                line:match("</h6>") or line:match("</head>") or line:match("</header>") or
                line:match("</hr>") or line:match("</html>") or line:match("</iframe>") or
                line:match("</legend>") or line:match("</li>") or line:match("</link>") or
                line:match("</main>") or line:match("</menu>") or line:match("</menuitem>") or
                line:match("</nav>") or line:match("</noframes>") or line:match("</ol>") or
                line:match("</optgroup>") or line:match("</option>") or line:match("</p>") or
                line:match("</param>") or line:match("</search>") or line:match("</section>") or
                line:match("</summary>") or line:match("</table>") or line:match("</tbody>") or
                line:match("</td>") or line:match("</tfoot>") or line:match("</th>") or
                line:match("</thead>") or line:match("</title>") or line:match("</tr>") or
                line:match("</track>") or line:match("</ul>"))) then
            local html_lines = {line}
            i = i + 1
            while i <= #lines and lines[i]:match("%S") do
                table.insert(html_lines, lines[i])
                i = i + 1
            end
            table.insert(html_parts, table.concat(html_lines, "\n"))
            i = i + 1 -- Skip the blank line

        -- HTML blocks (type 7: complete open or closing tags)
        elseif line:match("^%s*<[^/][^>]*>") or line:match("^%s*</[^>]+>") then
            table.insert(html_parts, line)
            i = i + 1

        -- Code block (including indented code blocks in list items)
        elseif line:match("^%s*```") then
            local lang = line:match("^%s*```(%w*)")
            i = i + 1
            local code_lines = {}
            while i <= #lines and not lines[i]:match("^%s*```") do
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
          elseif parse_lists and line:match("^%s*[-*+]%s+") then
              local list_items = {}
              while i <= #lines and lines[i]:match("^%s*[-*+]%s+") do
                   -- Collect all lines for this list item
                   local item_lines = {}
                   local trimmed_line = lines[i]:gsub("^%s+", "")
                    local content = trimmed_line:gsub("^[-*+]%s+", "")
                   table.insert(item_lines, content)
                   i = i + 1

                    -- Continue collecting continuation lines until we hit a block boundary
                    while i <= #lines and
                          not lines[i]:match("^#{1,6}%s+") and
                          not lines[i]:match("^[-*_]{3,}$") and
                          not lines[i]:match("^>%s*") and
                          not lines[i]:match("^%s*[-*+]%s+") and
                          not lines[i]:match("^|") do
                     local current_line = lines[i]
                     if current_line:match("^%s*$") then
                         -- Blank line: check if next non-blank line should be included
                         local next_non_blank_idx = i + 1
                         while next_non_blank_idx <= #lines and lines[next_non_blank_idx]:match("^%s*$") do
                             next_non_blank_idx = next_non_blank_idx + 1
                         end
                         if next_non_blank_idx <= #lines then
                             local next_line = lines[next_non_blank_idx]
                             -- Include blank line only if next non-blank line is indented or is a code block
                             if next_line:match("^%s+") or next_line:match("^```") then
                                 table.insert(item_lines, current_line)
                                 i = i + 1
                             else
                                 -- Stop before this blank line - unindented content shouldn't be in list item
                                 break
                             end
                         else
                             -- End of input, include the blank line
                             table.insert(item_lines, current_line)
                             i = i + 1
                         end
                     else
                         table.insert(item_lines, current_line)
                         i = i + 1
                     end
                end

                     -- Join all lines for this list item and parse recursively (allows nested lists and code blocks)
                     local item_content = table.concat(item_lines, "\n")
                     local parsed_item_content = parse_markdown(item_content, true)

                     -- If the content is just a single paragraph, unwrap it to avoid unnecessary <p> tags
                     if parsed_item_content:match("^<p>") and parsed_item_content:match("</p>$") and parsed_item_content:find("<p>", 4) == nil then
                         parsed_item_content = parsed_item_content:match("^<p>(.+)</p>$")
                     end

                     table.insert(list_items, string.format("<li>%s</li>", parsed_item_content))
                end
                table.insert(html_parts, string.format("<ul>%s</ul>", table.concat(list_items)))

           -- Ordered list
           elseif parse_lists and line:match("^%s*%d+%.%s+") then
               local list_items = {}
               while i <= #lines and lines[i]:match("^%s*%d+%.%s+") do
                   -- Collect all lines for this list item
                   local item_lines = {}
                   local trimmed_line = lines[i]:gsub("^%s+", "")
                    local content = trimmed_line:gsub("^%d+%.%s+", "")
                   table.insert(item_lines, content)
                   i = i + 1

                    -- Continue collecting continuation lines until we hit a block boundary
                    while i <= #lines and
                          not lines[i]:match("^#{1,6}%s+") and
                          not lines[i]:match("^[-*_]{3,}$") and
                          not lines[i]:match("^>%s*") and
                          not lines[i]:match("^%s*%d+%.%s+") and
                          not lines[i]:match("^|") do
                     local current_line = lines[i]
                     if current_line:match("^%s*$") then
                         -- Blank line: check if next non-blank line should be included
                         local next_non_blank_idx = i + 1
                         while next_non_blank_idx <= #lines and lines[next_non_blank_idx]:match("^%s*$") do
                             next_non_blank_idx = next_non_blank_idx + 1
                         end
                         if next_non_blank_idx <= #lines then
                             local next_line = lines[next_non_blank_idx]
                             -- Include blank line only if next non-blank line is indented or is a code block
                             if next_line:match("^%s+") or next_line:match("^```") then
                                 table.insert(item_lines, current_line)
                                 i = i + 1
                             else
                                 -- Stop before this blank line - unindented content shouldn't be in list item
                                 break
                             end
                         else
                             -- End of input, include the blank line
                             table.insert(item_lines, current_line)
                             i = i + 1
                         end
                     else
                         table.insert(item_lines, current_line)
                         i = i + 1
                     end
                    end

                     -- Join all lines for this list item and parse recursively (allows nested lists and code blocks)
                     local item_content = table.concat(item_lines, "\n")
                     local parsed_item_content = parse_markdown(item_content, true)

                     -- If the content is just a single paragraph, unwrap it to avoid unnecessary <p> tags
                     if parsed_item_content:match("^<p>") and parsed_item_content:match("</p>$") and parsed_item_content:find("<p>", 4) == nil then
                         parsed_item_content = parsed_item_content:match("^<p>(.+)</p>$")
                     end

                     table.insert(list_items, string.format("<li>%s</li>", parsed_item_content))
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
                while i <= #lines and lines[i]:match("%S") and not lines[i]:match("^#{1,6}%s+") and not lines[i]:match("^[-*_]{3,}$") and not lines[i]:match("^>%s*") and not lines[i]:match("^```") and                          not lines[i]:match("^%s*[-*+]%s+") and
                         not lines[i]:match("^%s*%d+%.%s+") and not lines[i]:match("^|") do
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

    local result = table.concat(html_parts, "\n")

    -- Add footnotes section if any footnotes were defined
    if next(footnotes) then
        local footnote_items = {}
        for label, content in pairs(footnotes) do
            -- If content starts with <p> and ends with </p>, extract the inner content
            local inner_content = content
            if content:match("^<p>") and content:match("</p>$") then
                inner_content = content:match("^<p>(.+)</p>$")
            end
            table.insert(footnote_items, string.format('<li id="fn:%s"><p>%s&#160;<a href="#fnref:%s" class="footnote-backref" role="doc-backlink">&#8617;&#xfe0e;</a></p></li>', label, inner_content, label))
        end
        -- Sort footnotes by their first appearance in the document would be ideal,
        -- but for simplicity, we'll sort them alphabetically by label
        table.sort(footnote_items, function(a, b)
            local label_a = a:match('id="fn:([^"]+)"')
            local label_b = b:match('id="fn:([^"]+)"')
            return label_a < label_b
        end)
        local footnotes_html = string.format('<div class="footnotes" role="doc-endnotes"><hr><ol>%s</ol></div>', table.concat(footnote_items, ""))
        result = result .. "\n\n" .. footnotes_html
    end

    return result
end

--- Parse inline markdown elements within text
--- @param text string The text containing inline markdown elements
--- @return string The text with markdown elements converted to HTML
function parse_inline(text)
    if not text then return "" end

    -- Define safe inline HTML tags that should be preserved
    local safe_inline_tags = {
        "sup", "sub", "kbd", "code", "em", "strong", "i", "b", "u", "s", "small",
        "big", "cite", "dfn", "abbr", "acronym", "var", "samp", "tt", "mark",
        "q", "time", "span", "br", "wbr"
    }

    -- Extract safe HTML tags and replace with placeholders
    local html_placeholders = {}
    local placeholder_counter = 0

    -- Pattern to match safe HTML tags
    for _, tag_name in ipairs(safe_inline_tags) do
        -- Match complete opening tags: <tag> or <tag attrs>
        local opening_pattern = "<" .. tag_name .. "[^>]*>"
        text = text:gsub(opening_pattern, function(tag)
            -- Check that this is exactly the tag we want (not a longer tag name)
            local next_char = tag:sub(#tag_name + 2, #tag_name + 2)  -- Character after tag name
            if not (next_char and next_char:match("[a-zA-Z]")) then
                placeholder_counter = placeholder_counter + 1
                local placeholder = "___HTML_TAG_PLACEHOLDER_" .. placeholder_counter .. "___"
                -- Escape % characters in tag for safe storage
                html_placeholders[placeholder] = tag:gsub("%%", "%%%%")
                return placeholder
            end
            return tag  -- Not our tag, leave it unchanged
        end)

        -- Match complete closing tags: </tag>
        local closing_pattern = "</" .. tag_name .. "[^>]*>"
        text = text:gsub(closing_pattern, function(tag)
            -- Check that this is exactly the tag we want
            local next_char = tag:sub(#tag_name + 3, #tag_name + 3)  -- Character after </tag
            if not (next_char and next_char:match("[a-zA-Z]")) then
                placeholder_counter = placeholder_counter + 1
                local placeholder = "___HTML_TAG_PLACEHOLDER_" .. placeholder_counter .. "___"
                -- Escape % characters in tag for safe storage
                html_placeholders[placeholder] = tag:gsub("%%", "%%%%")
                return placeholder
            end
            return tag  -- Not our tag, leave it unchanged
        end)
    end

    -- Escape HTML entities in the remaining text
    local result = escape_html(text)

    -- Process code spans (content is already escaped)
    result = result:gsub("`([^`\n]+)`", function(content)
        local code_tag = "<code>" .. content .. "</code>"
        placeholder_counter = placeholder_counter + 1
        local placeholder = "___HTML_TAG_PLACEHOLDER_" .. placeholder_counter .. "___"
        -- Escape % characters in tag for safe storage
        html_placeholders[placeholder] = code_tag:gsub("%%", "%%%%")
        return placeholder
    end)

    -- Strikethrough
    result = result:gsub("~~([^~\n]+)~~", "<del>%1</del>")

    -- Bold (process first to handle nested italics correctly)
    result = result:gsub("%*%*%*(.-)%*%*%*", "<strong><em>%1</em></strong>")
    result = result:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")

    -- Italic
    result = result:gsub("%*([^*]+)%*", "<em>%1</em>")

    -- Links and images
    result = result:gsub("!%[([^%]]+)%]%(([^%)]+)%)", '<img alt="%1" src="%2">')
    result = result:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<a href="%2">%1</a>')

    -- Footnote references [^label]
    result = result:gsub("%[%^([^%]]+)%]", function(label)
        return string.format('<sup id="fnref:%s"><a href="#fn:%s" class="footnote-ref" role="doc-noteref">%s</a></sup>', label, label, label)
    end)

    -- Restore safe HTML tags
    for placeholder, tag in pairs(html_placeholders) do
        result = result:gsub(placeholder, tag)
    end
    
    -- Helper function to process underscores outside code spans
    local function process_underscores_outside_code(text)
        local processed = text
        
        -- Protect escaped underscore placeholders and split cases
        processed = processed:gsub("§§ESCAPED_UNDERSCORE_PLACEHOLDER§§([^_]*)_", "§§PROTECTED_ESCAPED§§%1§§PROTECTED_ESCAPED_END§§")
        
        -- Process valid underscore emphasis with specific patterns
        -- These patterns avoid matches on content with underscores
        
        -- 1. At start of line: _word_
        processed = processed:gsub("^_([^_]+)_", "<em>%1</em>")
        
        -- 2. After space or punctuation, followed by non-space content: _word_ 
        processed = processed:gsub("%s_([^_]+)_(%p)", " <em>%1</em>%2")
        processed = processed:gsub("(%p)_([^_]+)_(%p)", "%1<em>%2</em>%3")
        
        -- 3. After space or punctuation, followed by non-space content, ending anywhere: _word
        processed = processed:gsub("%s_([^_]+)_", " <em>%1</em>")
        processed = processed:gsub("(%p)_([^_]+)_", "%1<em>%2</em>")
        
        -- 4. Before punctuation or end: _word_
        processed = processed:gsub("_([^_]+)_(%p)", "<em>%1</em>%2")
        processed = processed:gsub("_([^_]+)_$", "<em>%1</em>")
        
        -- 5. In middle of text (not surrounded by spaces)
        processed = processed:gsub("([^%s])_([^_]+)_(%p)", "%1<em>%2</em>%3")
        processed = processed:gsub("([^%s])_([^_]+)_%s", "%1<em>%2</em> ")
        
        return processed
    end
    
    -- Process underscore italics with step-by-step approach
    -- First, preserve escaped underscores and double underscores, plus spaces case
    result = result:gsub("\\_", "§§ESCAPED_UNDERSCORE_PLACEHOLDER§§")
    
    -- Protect underscores inside existing bold/strong tags (should remain literal)
    result = result:gsub("(<strong[^>]*>)(.-)(</strong>)", function(open, content, close)
        -- Replace any underscores in content with placeholders
        content = content:gsub("_", "§§BOLD_UNDERSCORE§§")
        return open .. content .. close
    end)
    
    result = result:gsub("__(.-)__", function(content)
        return "§§DOUBLE_UNDERSCORE§§" .. content .. "§§DOUBLE_UNDERSCORE§§"
    end)
    -- Protect underscores with spaces around them (should not be emphasized)
    result = result:gsub("%s_([^%s]+)_%s", " _%1_ ")
    
    -- Process each line for underscore emphasis
    local lines = {}
    for line in result:gmatch("[^\n]*") do
        table.insert(lines, line)
    end
    
    for i, line in ipairs(lines) do
        local processed = line
        
        -- 1. Skip processing in code spans (preserve underscores in <code> tags)
        if processed:find("<code>") then
            -- Handle code spans by processing outside them only
            local result_parts = {}
            local current_part = ""
            local pos = 1
            
            while pos <= #processed do
                local code_start = processed:find("<code>", pos)
                if not code_start then
                    -- No more code tags, process remaining part
                    current_part = processed:sub(pos)
                    table.insert(result_parts, process_underscores_outside_code(current_part))
                    break
                else
                    -- Process part before code tag
                    current_part = processed:sub(pos, code_start - 1)
                    table.insert(result_parts, process_underscores_outside_code(current_part))
                    
                    -- Find closing code tag
                    local code_end = processed:find("</code>", code_start)
                    if code_end then
                        -- Include the entire code tag as-is
                        current_part = processed:sub(code_start, code_end)
                        table.insert(result_parts, current_part)
                        pos = code_end + 1
                    else
                        -- No closing tag found, treat rest as code
                        current_part = processed:sub(code_start)
                        table.insert(result_parts, current_part)
                        break
                    end
                end
            end
            
            processed = table.concat(result_parts)
        else
            -- No code spans, process entire line
            processed = process_underscores_outside_code(processed)
        end
        
        lines[i] = processed
    end
    
    result = table.concat(lines, "\n")
    
    -- Restore double underscores
    result = result:gsub("§§DOUBLE_UNDERSCORE§§", "__")
    
    -- Fix any <em> tags that shouldn't be there (spaces case)
    result = result:gsub("<em>([^<]*%s[^<]*)</em>", function(content)
        if content:match("^%s.*%s$") then
            return "_" .. content .. "_"
        end
        return "<em>" .. content .. "</em>"
    end)
    
    -- Restore underscores inside bold tags
    result = result:gsub("§§BOLD_UNDERSCORE§§", "_")
    
    -- Ensure underscores inside HTML tags remain literal
    result = result:gsub("<(strong|b|em|i)>(.-)</%1>", function(tag, content)
        content = content:gsub("<em>(.-)</em>", function(italic_content)
            return "_" .. italic_content .. "_"
        end)
        return "<" .. tag .. ">" .. content .. "</" .. tag .. ">"
    end)
    
    -- Restore escaped underscore placeholders
    result = result:gsub("§§PROTECTED_ESCAPED§§([^_]*)§§PROTECTED_ESCAPED_END§§", "\\_%1_")
    result = result:gsub("§§PROTECTED_ESCAPED§§", "\\_")
    result = result:gsub("§§ESCAPED_UNDERSCORE_PLACEHOLDER§§", "\\_")
    
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