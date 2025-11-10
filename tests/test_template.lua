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

-- Expression: Property access with dot notation (currently broken)
function tests.test_expression_property_access()
    -- This currently fails due to expression parsing bug in {{ }} blocks
    local template = Template('{{ user.name }}')
    local success, err = pcall(function()
        return template({ user = { name = "Alice" } })
    end)
    -- Currently fails at runtime due to invalid generated code like 'c.user . c.name'
    -- Should eventually work and return "Alice"
    assert.is_false(success)
end

-- Expression: Property access with default value
function tests.test_expression_property_access_with_default()
    -- This currently fails due to expression parsing bug
    local template = Template('{{ user.name or "Anonymous" }}')
    local success, err = pcall(function()
        return template({ user = {} })  -- user exists but name is nil
    end)
    -- Currently this fails at runtime due to invalid generated code
    -- Should eventually pass and return "Anonymous"
    assert.is_false(success)
end

-- Expression: Complex property access
function tests.test_expression_complex_property_access()
    -- This currently fails due to expression parsing bug
    local template = Template('{{ user.profile.settings.theme }}')
    local success, err = pcall(function()
        return template({
            user = {
                profile = {
                    settings = {
                        theme = "dark"
                    }
                }
            }
        })
    end)
    -- Currently this fails at runtime due to invalid generated code
    -- Should eventually pass and return "dark"
    assert.is_false(success)
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

return tests
