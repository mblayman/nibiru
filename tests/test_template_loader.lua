local TemplateLoader = require("nibiru.loader")
local Template = require("nibiru.template")

local tests = {}

-- Test basic directory loading with multiple template files.
function tests.test_from_directory_basic()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_loader_basic_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create test template files
    local file1 = io.open(temp_dir .. "/index.html", "w")
    file1:write("<h1>{{title}}</h1>")
    file1:close()

    local file2 = io.open(temp_dir .. "/partial.html", "w")
    file2:write("<div>{{content}}</div>")
    file2:close()

    -- Load templates from directory
    TemplateLoader.from_directory(temp_dir)

    -- Verify templates were registered by trying to extend them
    -- If templates weren't registered, this would fail with "Template 'index.html' not found"
    local success1, result1 = pcall(function()
        local index_extending = Template('{% extends "index.html" %}')
        return index_extending({ title = "Hello" })
    end)
    assert(success1, "Template 'index.html' should be registered")
    assert(result1 == "<h1>Hello</h1>", "Template should render correctly")

    local success2, result2 = pcall(function()
        local partial_extending = Template('{% extends "partial.html" %}')
        return partial_extending({ content = "Loaded Content" })
    end)
    assert(success2, "Template 'partial.html' should be registered")
    assert(result2 == "<div>Loaded Content</div>", "Template should render correctly")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test error handling for nonexistent directory.
function tests.test_from_directory_nonexistent()
    -- Test with nonexistent directory
    local success, err = pcall(function()
        TemplateLoader.from_directory("/tmp/nonexistent_templates_dir_12345")
    end)

    assert(not success, "Should fail with nonexistent directory")
    assert(
        err:match("Failed to read directory"),
        "Should give appropriate error message"
    )
end

-- Test nested directory structure with proper relative paths.
function tests.test_from_directory_nested()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_loader_nested_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir .. "/pages")
    os.execute("mkdir -p " .. temp_dir .. "/partials")

    -- Create test template files in nested structure
    local base_file = io.open(temp_dir .. "/base.html", "w")
    base_file:write("<html>{{body}}</html>")
    base_file:close()

    local index_file = io.open(temp_dir .. "/pages/index.html", "w")
    index_file:write("<h1>Home</h1>")
    index_file:close()

    local footer_file = io.open(temp_dir .. "/partials/footer.html", "w")
    footer_file:write("<p>Footer</p>")
    footer_file:close()

    -- Load all templates with proper relative paths
    TemplateLoader.from_directory(temp_dir)

    -- Verify all templates were registered with correct relative paths
    local success1, result1 = pcall(function()
        local base_extending = Template('{% extends "base.html" %}')
        return base_extending({ body = "Test Body" })
    end)
    assert(success1, "Template 'base.html' should be registered")
    assert(result1 == "<html>Test Body</html>", "Template should render correctly")

    local success2, result2 = pcall(function()
        local index_extending = Template('{% extends "pages/index.html" %}')
        return index_extending({})
    end)
    assert(success2, "Template 'pages/index.html' should be registered")
    assert(result2 == "<h1>Home</h1>", "Template should render correctly")

    local success3, result3 = pcall(function()
        local footer_extending = Template('{% extends "partials/footer.html" %}')
        return footer_extending({})
    end)
    assert(success3, "Template 'partials/footer.html' should be registered")
    assert(result3 == "<p>Footer</p>", "Template should render correctly")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test loading from empty directory.
function tests.test_from_directory_empty()
    Template.clear_templates()

    -- Create a temporary empty directory
    local temp_dir = "/tmp/nibiru_test_loader_empty_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- This should succeed but load no templates
    TemplateLoader.from_directory(temp_dir)

    -- Verify no templates were registered by trying to extend a non-existent template
    local success, err = pcall(function()
        local template = Template('{% extends "nonexistent.html" %}')
        return template({})
    end)
    assert(not success, "Empty directory should not register any templates")
    assert(err and err:find("nonexistent.html"), "Should mention nonexistent.html in error")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test error handling for unreadable files.
function tests.test_from_directory_file_error()
    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_loader_error_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create readable file
    local readable_file = io.open(temp_dir .. "/readable.html", "w")
    readable_file:write("<h1>Test</h1>")
    readable_file:close()

    -- Create unreadable file
    local unreadable_file = io.open(temp_dir .. "/unreadable.html", "w")
    unreadable_file:write("<h1>Secret</h1>")
    unreadable_file:close()
    os.execute("chmod 000 " .. temp_dir .. "/unreadable.html")

    -- This should fail when trying to read the unreadable file
    local success, err = pcall(function()
        TemplateLoader.from_directory(temp_dir)
    end)

    -- Clean up
    os.execute("chmod 644 " .. temp_dir .. "/unreadable.html")
    os.execute("rm -rf " .. temp_dir)

    assert(not success, "Should fail with unreadable file")
    assert(err:match("Failed to open template file"), "Should give appropriate error message")
end

-- Test that topological sorting works: child templates load even when filesystem ordering is "wrong".
function tests.test_topological_sorting_order_independence()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_topo_sort_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create templates with dependencies: child extends parent
    -- Filesystem ordering is non-deterministic, but dependency analysis should handle it
    local parent_file = io.open(temp_dir .. "/parent.html", "w")
    parent_file:write("<div>{% block content %}Parent{% endblock %}</div>")
    parent_file:close()

    local child_file = io.open(temp_dir .. "/child.html", "w")
    child_file:write('{% extends "parent.html" %}{% block content %}Child{% endblock %}')
    child_file:close()

    -- Load templates - dependency analysis should ensure correct loading order
    TemplateLoader.from_directory(temp_dir)

    -- Verify the child template works (proves parent was loaded before child)
    local test_template = Template('{% extends "child.html" %}')
    local output = test_template({})
    assert(output == "<div>Child</div>", "Topological sorting should ensure parent loads before child")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test that dependency analysis handles complex inheritance chains correctly.
function tests.test_dependency_analysis_complex_chain()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_complex_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir .. "/level1" .. temp_dir .. "/level2")

    -- Create a complex inheritance chain: base -> middle -> leaf
    local base_file = io.open(temp_dir .. "/base.html", "w")
    base_file:write("<html>{% block content %}{% block inner %}Base{% endblock %}{% endblock %}</html>")
    base_file:close()

    local middle_file = io.open(temp_dir .. "/middle.html", "w")
    middle_file:write('{% extends "base.html" %}{% block content %}Middle: {% block inner %}Middle{% endblock %}{% endblock %}')
    middle_file:close()

    local leaf_file = io.open(temp_dir .. "/leaf.html", "w")
    leaf_file:write('{% extends "middle.html" %}{% block inner %}Leaf{% endblock %}')
    leaf_file:close()

    -- Load templates - dependency analysis should handle the chain correctly
    TemplateLoader.from_directory(temp_dir)

    -- Verify the inheritance chain works
    local leaf_template = Template('{% extends "leaf.html" %}')
    local output = leaf_template({})
    -- Multi-level inheritance should allow grandchild to override grandparent blocks
    assert(output == "<html>Middle: Leaf</html>", "Complex inheritance chain supports multi-level block overrides")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test that demonstrates why topological sorting matters: filesystem order independence.
function tests.test_filesystem_order_independence()
    Template.clear_templates()

    -- This test demonstrates that dependency analysis ensures templates work
    -- regardless of the order they're encountered in the filesystem

    -- Create a temporary directory
    local temp_dir = "/tmp/nibiru_test_fs_order_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create templates that would be problematic if loaded in wrong order
    -- Using filenames that might sort differently
    local z_parent_file = io.open(temp_dir .. "/z_parent.html", "w")
    z_parent_file:write("<div>{% block content %}Parent{% endblock %}</div>")
    z_parent_file:close()

    local a_child_file = io.open(temp_dir .. "/a_child.html", "w")
    a_child_file:write('{% extends "z_parent.html" %}{% block content %}Child{% endblock %}')
    a_child_file:close()

    -- Load templates - even if filesystem returns a_child.html before z_parent.html,
    -- dependency analysis should ensure correct loading order
    TemplateLoader.from_directory(temp_dir)

    -- Verify child works (proves dependency analysis handled ordering)
    local child_template = Template('{% extends "a_child.html" %}')
    local output = child_template({})
    assert(output == "<div>Child</div>", "Dependency analysis should handle filesystem ordering issues")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test dependency analysis: simple parent-child relationship.
function tests.test_dependency_analysis_simple_inheritance()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_simple_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create base template
    local base_file = io.open(temp_dir .. "/base.html", "w")
    base_file:write("<html><head><title>Base</title></head><body>{% block content %}Default{% endblock %}</body></html>")
    base_file:close()

    -- Create child template that extends base
    local child_file = io.open(temp_dir .. "/child.html", "w")
    child_file:write('{% extends "base.html" %}{% block content %}Child content{% endblock %}')
    child_file:close()

    -- Load templates (should handle dependency ordering)
    TemplateLoader.from_directory(temp_dir)

    -- Verify child template can be rendered (proving base was loaded first)
    local child_template = Template('{% extends "child.html" %}')
    local output = child_template({})
    assert(output == "<html><head><title>Base</title></head><body>Child content</body></html>",
           "Child template should render correctly with inherited base template")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test dependency analysis: multiple children extending same parent.
function tests.test_dependency_analysis_multiple_children()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_multi_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create base template
    local base_file = io.open(temp_dir .. "/base.html", "w")
    base_file:write("<div>{% block content %}Base{% endblock %}</div>")
    base_file:close()

    -- Create multiple child templates
    local child1_file = io.open(temp_dir .. "/child1.html", "w")
    child1_file:write('{% extends "base.html" %}{% block content %}Child 1{% endblock %}')
    child1_file:close()

    local child2_file = io.open(temp_dir .. "/child2.html", "w")
    child2_file:write('{% extends "base.html" %}{% block content %}Child 2{% endblock %}')
    child2_file:close()

    -- Load templates
    TemplateLoader.from_directory(temp_dir)

    -- Verify both children can render
    local child1_template = Template('{% extends "child1.html" %}')
    local child2_template = Template('{% extends "child2.html" %}')

    local output1 = child1_template({})
    local output2 = child2_template({})

    assert(output1 == "<div>Child 1</div>", "First child should render correctly")
    assert(output2 == "<div>Child 2</div>", "Second child should render correctly")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test dependency analysis: chain inheritance (A -> B -> C).
function tests.test_dependency_analysis_chain_inheritance()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_chain_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create chain: C extends B, B extends A
    local a_file = io.open(temp_dir .. "/a.html", "w")
    a_file:write("<root>{% block level1 %}A{% endblock %}</root>")
    a_file:close()

    local b_file = io.open(temp_dir .. "/b.html", "w")
    b_file:write('{% extends "a.html" %}{% block level1 %}B: {% block level2 %}B{% endblock %}{% endblock %}')
    b_file:close()

    local c_file = io.open(temp_dir .. "/c.html", "w")
    c_file:write('{% extends "b.html" %}{% block level2 %}C{% endblock %}')
    c_file:close()

    -- Load templates (should handle A -> B -> C ordering)
    TemplateLoader.from_directory(temp_dir)

    -- Verify the chain renders correctly
    local c_template = Template('{% extends "c.html" %}')
    local output = c_template({})
    -- Multi-level inheritance should allow grandchild to override grandparent blocks
    assert(output == "<root>B: C</root>", "Chain inheritance supports multi-level block overrides")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test dependency analysis: templates with no dependencies.
function tests.test_dependency_analysis_no_dependencies()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_none_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create templates with no extends statements
    local standalone1 = io.open(temp_dir .. "/standalone1.html", "w")
    standalone1:write("<div>Template 1</div>")
    standalone1:close()

    local standalone2 = io.open(temp_dir .. "/standalone2.html", "w")
    standalone2:write("<span>Template 2</span>")
    standalone2:close()

    -- Load templates
    TemplateLoader.from_directory(temp_dir)

    -- Verify templates can be used
    local template1 = Template('{% extends "standalone1.html" %}')
    local template2 = Template('{% extends "standalone2.html" %}')

    local output1 = template1({})
    local output2 = template2({})

    assert(output1 == "<div>Template 1</div>", "Standalone template 1 should work")
    assert(output2 == "<span>Template 2</span>", "Standalone template 2 should work")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

-- Test error case: circular dependency (A extends B, B extends A).
function tests.test_dependency_analysis_circular_dependency()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_circular_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create circular dependency: A extends B, B extends A
    local a_file = io.open(temp_dir .. "/a.html", "w")
    a_file:write('{% extends "b.html" %}<div>A</div>')
    a_file:close()

    local b_file = io.open(temp_dir .. "/b.html", "w")
    b_file:write('{% extends "a.html" %}<span>B</span>')
    b_file:close()

    -- This should fail with circular dependency error during loading
    local success, err = pcall(function()
        TemplateLoader.from_directory(temp_dir)
    end)

    -- Clean up
    os.execute("rm -rf " .. temp_dir)

    assert(not success, "Should fail with circular dependency")
    assert(err:match("Circular dependency detected"), "Should mention circular dependency in error")
end

-- Test error case: circular dependency in chain (A -> B -> C -> A).
function tests.test_dependency_analysis_circular_chain()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_circular_chain_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create circular chain: A -> B -> C -> A
    local a_file = io.open(temp_dir .. "/a.html", "w")
    a_file:write('{% extends "b.html" %}A')
    a_file:close()

    local b_file = io.open(temp_dir .. "/b.html", "w")
    b_file:write('{% extends "c.html" %}B')
    b_file:close()

    local c_file = io.open(temp_dir .. "/c.html", "w")
    c_file:write('{% extends "a.html" %}C')
    c_file:close()

    -- This should fail with circular dependency error during loading
    local success, err = pcall(function()
        TemplateLoader.from_directory(temp_dir)
    end)

    -- Clean up
    os.execute("rm -rf " .. temp_dir)

    assert(not success, "Should fail with circular dependency in chain")
    assert(err:match("Circular dependency detected"), "Should mention circular dependency in error")
end

-- Test error case: self-referencing template.
function tests.test_dependency_analysis_self_reference()
    Template.clear_templates()

    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_dep_self_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Create self-referencing template
    local self_file = io.open(temp_dir .. "/self.html", "w")
    self_file:write('{% extends "self.html" %}<div>Self</div>')
    self_file:close()

    -- This should fail with circular dependency error during loading
    local success, err = pcall(function()
        TemplateLoader.from_directory(temp_dir)
    end)

    -- Clean up
    os.execute("rm -rf " .. temp_dir)

    assert(not success, "Should fail with self-reference")
    assert(err:match("Circular dependency detected"), "Should mention circular dependency in error")
end

return tests

