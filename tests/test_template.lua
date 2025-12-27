local assert = require("luassert")
local Template = require("nibiru.template")

local tests = {}

-- A basic expression value renders.
function tests.test_expression_value()
    local template = Template("a test {{ expression_value }}")
    local context = { expression_value = "value" }
    local output = template(context)

    assert.equal("a test value", output)
end

-- Component registration and basic usage.
function tests.test_component_registration_and_usage()
    Template.clear_components()
    -- Register a simple Button component.
    Template.component("Button", [[<button>{{text}}</button>]])

    -- Use the component in a template.
    local template = Template("<div><Button text='Click me'/></div>")
    local context = { text = "Click me" }
    local output = template(context)

    assert.equal([[<div><button>Click me</button></div>]], output)
end

-- Component with props and context data.
function tests.test_component_with_props()
    Template.clear_components()
    -- Register component with props.
    Template.component(
        "UserCard",
        [[
<div class="card">
  <h3>{{name}}</h3>
  <p class="role">{{role}}</p>
</div>]]
    )

    -- Use component with context data.
    local template = Template("<UserCard name=user.name role=user.role/>")
    local context = { user = { name = "Alice", role = "Admin" } }
    local output = template(context)

    assert.equal(
        [[<div class="card">
  <h3>Alice</h3>
  <p class="role">Admin</p>
</div>]],
        output
    )
end

-- Component composition - component using another component.
function tests.test_component_composition()
    Template.clear_components()
    -- Register base Button component.
    Template.component("Button", [[<button class="{{class}}">{{text}}</button>]])

    -- Register Form component that uses Button.
    Template.component(
        "Form",
        [[
<form>
  <input type="text" name="name"/>
  <Button class="primary" text="Submit"/>
</form>]]
    )

    -- Use composed component.
    local template = Template("<div><Form/></div>")
    local output = template({})

    assert.equal(
        [[<div><form>
  <input type="text" name="name"/>
  <button class="primary">Submit</button>
</form></div>]],
        output
    )
end

-- Component with default values.
function tests.test_component_with_defaults()
    Template.clear_components()
    Template.component(
        "Button",
        [[<button type="{{type or 'button'}}">{{text}}</button>]]
    )

    local template = Template("<Button text='Save'/>")
    local output = template({})

    assert.equal('<button type="button">Save</button>', output)
end

-- Multiple components in one template.
function tests.test_multiple_components()
    Template.clear_components()
    Template.component("Header", [[<h1>{{title}}</h1>]])
    Template.component("Footer", [[<footer>{{text}}</footer>]])

    local template = Template([[
<div>
  <Header title="Welcome"/>
  <p>Content here</p>
  <Footer text="Copyright 2024"/>
</div>]])

    local output = template({})
    assert.equal(
        [[
<div>
  <h1>Welcome</h1>
  <p>Content here</p>
  <footer>Copyright 2024</footer>
</div>]],
        output
    )
end

-- Error: Using unregistered component.
function tests.test_unregistered_component_error()
    local template = Template("<UnknownComponent/>")

    -- Should error when trying to render.
    local success, err = pcall(function()
        template({})
    end)
    assert.is_false(success)
    assert.match("UnknownComponent", err)
end

-- Error: Component name conflict.
function tests.test_component_name_conflict()
    Template.clear_components()
    Template.component("Button", [[<button>Original</button>]])

    -- Registering same name again should error.
    local success, err = pcall(function()
        Template.component("Button", [[<button>Duplicate</button>]])
    end)
    assert.is_false(success)
    assert.match("already registered", err)
end

-- Error: Invalid component name (lowercase).
function tests.test_invalid_component_name_lowercase()
    local success, err = pcall(function()
        Template.component("lowercase", [[<div>invalid</div>]])
    end)
    assert.is_false(success)
    assert.match("component names must start with capital", err)
end

-- Error: Component without self-closing tag.
function tests.test_component_missing_self_closing_tag()
    Template.clear_components()
    Template.component("Button", [[<button>{{text}}</button>]])

    -- Missing /> at end of component tag.
    local template = Template('<Button class="primary" text="Save">')
    local success, err = pcall(function()
        template({})
    end)
    assert.is_false(success)
    assert.match("malformed component tag", err)
end

-- Error: Component with missing closing tag.
function tests.test_component_missing_closing_tag()
    Template.clear_components()
    Template.component("Button", [[<button>{{text}}</button>]])

    -- Missing closing </Button> tag.
    local template = Template("<Button><span>content</span>")
    local success, err = pcall(function()
        template({})
    end)
    assert.is_false(success)
    assert.match("malformed component tag", err)
end

-- Error: Mismatched component tags.
function tests.test_component_mismatched_tags()
    Template.clear_components()
    Template.component("Button", [[<button>{{text}}</button>]])
    Template.component("Icon", [[<i>{{name}}</i>]])

    -- Wrong closing tag.
    local template = Template("<Button>Save</Icon>")
    local success, err = pcall(function()
        template({})
    end)
    assert.is_false(success)
    assert.match("malformed component tag", err)
end

-- Error: Component with malformed attributes.
function tests.test_component_malformed_attributes()
    Template.clear_components()
    Template.component("Button", [[<button>{{text}}</button>]])

    -- Malformed attribute syntax.
    local template = Template('<Button class="primary" text=Save">Save</Button>')
    local success, err = pcall(function()
        template({})
    end)
    assert.is_false(success)
    assert.match("malformed attribute", err)
end

-- Error: Nested components with missing closing tags.
function tests.test_nested_components_missing_closing()
    Template.clear_components()
    Template.component("Button", [[<button>{{text}}</button>]])
    Template.component("Form", [[<form>{{children}}</form>]])

    -- Nested components with missing closing tags.
    local template = Template('<Form><Button text="Save"><span>content</span></Form>')
    local success, err = pcall(function()
        template({})
    end)
    assert.is_false(success)
    assert.match("malformed component tag", err)
end

-- Expression: Property access with dot notation
function tests.test_expression_property_access()
    local template = Template('{{ user.name }}')
    local result = template({ user = { name = "Alice" } })
    assert.equal('Alice', result)
end

-- Expression: Property access with default value
function tests.test_expression_property_access_with_default()
    local template = Template('{{ user.name or "Anonymous" }}')
    local result = template({ user = {} })  -- user exists but name is nil
    assert.equal('Anonymous', result)
end

-- Expression: Complex property access
function tests.test_expression_complex_property_access()
    local template = Template('{{ user.profile.settings.theme }}')
    local result = template({
        user = {
            profile = {
                settings = {
                    theme = "dark"
                }
            }
        }
    })
    assert.equal('dark', result)
end

-- Expression: Property access in component attributes
function tests.test_expression_property_access_in_attributes()
    Template.clear_components()
    Template.component("UserCard", [[<div>{{name}} - {{role}}</div>]])

    local template = Template('<UserCard name=user.name role=user.role/>')
    local result = template({
        user = { name = "Bob", role = "Admin" }
    })
    assert.equal('<div>Bob - Admin</div>', result)
end

-- Render: Basic template rendering with defaults
function tests.test_render_basic()
    Template.clear_templates()
    Template.register("test.html", "Hello {{name}}!")

    local response = Template.render("test.html", { name = "World" })

    assert.equal(200, response.status_code)
    assert.equal("Hello World!", response.content)
    assert.equal("text/html", response.content_type)
    assert.equal(type(response.headers), "table")
end

-- Render: Custom content type
function tests.test_render_custom_content_type()
    Template.clear_templates()
    Template.register("data.json", '{"name": "{{name}}"}')

    local response = Template.render("data.json", { name = "Alice" }, "application/json")

    assert.equal(200, response.status_code)
    assert.equal('{"name": "Alice"}', response.content)
    assert.equal("application/json", response.content_type)
end

-- Render: Custom status code
function tests.test_render_custom_status_code()
    Template.clear_templates()
    Template.register("created.html", "<p>Created: {{item}}</p>")

    local response = Template.render("created.html", { item = "New User" }, "text/html", 201)

    assert.equal(201, response.status_code)
    assert.equal("<p>Created: New User</p>", response.content)
    assert.equal("text/html", response.content_type)
end

-- Render: Custom headers
function tests.test_render_custom_headers()
    Template.clear_templates()
    Template.register("download.html", "<h1>{{title}}</h1>")

    local custom_headers = { ["Content-Disposition"] = 'attachment; filename="report.html"' }
    local response = Template.render("download.html", { title = "Report" }, "text/html", 200, custom_headers)

    assert.equal(200, response.status_code)
    assert.equal("<h1>Report</h1>", response.content)
    assert.equal("text/html", response.content_type)
    assert.equal('attachment; filename="report.html"', response.headers["Content-Disposition"])
end

-- Render: Empty context defaults to empty table
function tests.test_render_empty_context()
    Template.clear_templates()
    Template.register("simple.html", "Simple content")

    local response = Template.render("simple.html")

    assert.equal(200, response.status_code)
    assert.equal("Simple content", response.content)
    assert.equal("text/html", response.content_type)
end

-- Render: Error when template not found
function tests.test_render_template_not_found()
    Template.clear_templates()

    local success, err = pcall(function()
        Template.render("nonexistent.html", {})
    end)

    assert.is_false(success)
    assert.match("Template 'nonexistent.html' not found", err)
end

-- Test: Template inheritance with for loop and route function call
function tests.test_template_inheritance_with_for_loop_and_route()
    local Application = require("nibiru.application")
    local Route = require("nibiru.route")

    Template.clear_templates()
    Template.clear_application()

    -- Create a real application with a route
    local routes = {
        Route("/blog/{slug:string}", function(request, slug)
            return { status_code = 200, content = "Blog post: " .. slug }
        end, "blog_entry")
    }
    local app = Application(routes, "tests/data/config.lua")

    -- Clear templates again after application creation (which may register templates)
    Template.clear_templates()

    -- Register base template
    Template.register("base.html", [[
<!DOCTYPE html>
<html>
<head><title>Base</title></head>
<body>{% block content %}{% endblock %}</body>
</html>]])

    -- Register child template that extends base and uses for loop with route
    Template.register("index.html", [[
{% extends "base.html" %}

{% block content %}
  <h1>Matt Layman's website index</h1>
  {% for page in pages %}
    <p><a href="{{ route("blog_entry", page.slug ) }}">{{ page.title }}</a></p>
  {% endfor %}
{% endblock %}]])

    -- Create context with pages data
    local context = {
        pages = {
            { title = "First Post", slug = "first-post" },
            { title = "Second Post", slug = "second-post" }
        }
    }

    -- This should reproduce the error: attempt to index a nil value (field 'context')
    local response = Template.render("index.html", context)

    assert.equal(200, response.status_code)
    assert.equal("text/html", response.content_type)
end

return tests
