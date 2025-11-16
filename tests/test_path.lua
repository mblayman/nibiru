local path = require("nibiru.path")

local function test_files_from()
    -- Create a temporary directory with random name
    local temp_dir = "/tmp/nibiru_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir .. "/subdir")

    -- Create test files
    local files_to_create = {
        temp_dir .. "/file1.txt",
        temp_dir .. "/file2.txt",
        temp_dir .. "/subdir/file3.txt",
        temp_dir .. "/subdir/file4.txt",
        temp_dir .. "/deep/nested/file5.txt"
    }

    -- Create deep directory
    os.execute("mkdir -p " .. temp_dir .. "/deep/nested")

    -- Write files
    for _, filepath in ipairs(files_to_create) do
        local f = assert(io.open(filepath, "w"))
        f:write("test content")
        f:close()
    end

    -- Test files_from
    local files = path.files_from(temp_dir)

    -- Convert to set for easier checking
    local file_set = {}
    for _, file in ipairs(files) do
        file_set[file] = true
    end

    -- Check that all expected files are found
    local expected_files = {
        "file1.txt",
        "file2.txt",
        "subdir/file3.txt",
        "subdir/file4.txt",
        "deep/nested/file5.txt"
    }

    for _, expected in ipairs(expected_files) do
        assert(file_set[expected], "Missing file: " .. expected)
    end

    -- Check that we don't have extra files
    assert(#files == #expected_files, "Wrong number of files: expected " .. #expected_files .. ", got " .. #files)

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

local function test_files_from_empty_dir()
    -- Create empty temporary directory
    local temp_dir = "/tmp/nibiru_test_empty_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000))
    os.execute("mkdir -p " .. temp_dir)

    -- Test files_from on empty directory
    local files = path.files_from(temp_dir)
    assert(#files == 0, "Empty directory should return empty array")

    -- Clean up
    os.execute("rm -rf " .. temp_dir)
end

local function test_files_from_nonexistent_dir()
    -- Test with non-existent directory
    local files, err = path.files_from("/tmp/nonexistent_directory_12345")
    assert(files == nil, "Should return nil for non-existent directory")
    assert(err:match("Path does not exist or is not a directory"), "Should give appropriate error message")
end

local tests = {
    test_files_from = test_files_from,
    test_files_from_empty_dir = test_files_from_empty_dir,
    test_files_from_nonexistent_dir = test_files_from_nonexistent_dir
}

return tests