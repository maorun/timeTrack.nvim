local helper = require('test.helper')
local utils = require('maorun.time.utils')
local Path = require('plenary.path') -- For mocking Path related functions
local TrueOriginalPlenaryPathNew = Path.new -- Capture the true original Plenary Path.new at load time

-- Mock for vim.api.nvim_buf_get_name
local nvim_buf_get_name_mock_ctrl = {
    return_value = nil,
    was_called_with = nil,
    call_count = 0,
}
local original_nvim_buf_get_name

-- Mock for plenary.path Path object methods
local path_mock_ctrl = {
    new_was_called_with = nil,
    write_was_called_with_content = nil,
    write_was_called_with_mode = nil,
    write_return_value = nil, -- typically nil for write
    exists_return_value = false,
    is_root_return_value = false,
    parent_return_value = nil, -- This should be another Path mock or a table simulating it
    absolute_return_value = '',
    filename_value = 'mock_filename', -- Default filename for mock Path objects
    -- Add other methods as needed for tests
}
-- No longer need 'local original_Path_new' here as it's scoped differently or replaced by TrueOriginalPlenaryPathNew

describe('Utils Tests', function()
    before_each(function()
        -- Reset nvim_buf_get_name mock
        nvim_buf_get_name_mock_ctrl.return_value = nil
        nvim_buf_get_name_mock_ctrl.was_called_with = nil
        nvim_buf_get_name_mock_ctrl.call_count = 0
        original_nvim_buf_get_name = vim.api.nvim_buf_get_name
        vim.api.nvim_buf_get_name = function(bufnr)
            nvim_buf_get_name_mock_ctrl.call_count = nvim_buf_get_name_mock_ctrl.call_count + 1
            nvim_buf_get_name_mock_ctrl.was_called_with = bufnr
            return nvim_buf_get_name_mock_ctrl.return_value
        end

        -- Reset Path mock
        path_mock_ctrl.new_was_called_with = nil
        path_mock_ctrl.write_was_called_with_content = nil
        path_mock_ctrl.write_was_called_with_mode = nil
        path_mock_ctrl.write_return_value = nil
        path_mock_ctrl.exists_return_value = false
        path_mock_ctrl.is_root_return_value = false
        path_mock_ctrl.parent_return_value = nil
        path_mock_ctrl.absolute_return_value = ''
        path_mock_ctrl.filename_value = 'mock_filename'

        -- Path.new is NOT mocked globally in the main before_each anymore.
        -- Specific describe blocks (like for M.save) will set up their own Path.new mocks.

        -- Mock config_module
        -- Note: utils.lua requires 'maorun.time.config'
        -- We need to mock what 'maorun.time.config' returns.
        -- Assuming it returns a table with 'obj' and 'config' keys.
        package.loaded['maorun.time.config'] = {
            obj = {
                path = '/fake/path/data.json',
                content = { data = 'initial_data' },
            },
            config = {
                hoursPerWeekday = {
                    Monday = 8,
                    Tuesday = 8,
                    Wednesday = 8,
                    Thursday = 8,
                    Friday = 8,
                    Saturday = 0,
                    Sunday = 0,
                },
            },
        }
        -- Force utils to re-require with the new config mock for each test
        package.loaded['maorun.time.utils'] = nil
        utils = require('maorun.time.utils')

        -- Reset helper mocks if they are stateful and used by utils functions (e.g., notify)
        helper.reset_all_was_called_flags() -- if you have such a function in helper
        helper.notify_mock:reset() -- if utils uses notify directly
    end)

    after_each(function()
        -- Restore original vim.api.nvim_buf_get_name
        vim.api.nvim_buf_get_name = original_nvim_buf_get_name

        -- No global Path.new restoration needed here anymore

        -- Restore original config module
        package.loaded['maorun.time.config'] = nil -- Or restore original if it was preloaded by other tests
        package.loaded['maorun.time.utils'] = nil
        -- If other tests depend on a specific state of config, this might need adjustment.
        -- For isolated utils tests, nil-ing it out is usually fine.

        helper.teardown_all_mocks() -- if helper manages global mocks that need cleanup
    end)

    describe('M.save', function()
        local original_Path_new_for_save_block -- Stores the Path.new that was active before this block

        before_each(function()
            -- This before_each is specific to the 'M.save' describe block
            prior_Path_new_for_save_block = Path.new -- Capture current Path.new
            Path.new = function(first_arg, second_arg) -- Mock Path.new for M.save tests
                local path_str_to_use
                if type(first_arg) == 'table' and type(second_arg) == 'string' then
                    path_str_to_use = second_arg -- Likely called as Path:new("string") or internal dispatch Path.new(self, str)
                elseif type(first_arg) == 'string' and second_arg == nil then
                    path_str_to_use = first_arg -- Likely called as Path.new("string")
                else
                    -- This call is not the one we are trying to mock for M.save's primary path.
                    -- It could be an internal Plenary call with unexpected signature, or from joinpath if path_str_to_use was not set.
                    return TrueOriginalPlenaryPathNew(first_arg, second_arg) -- Pass through all args
                end

                path_mock_ctrl.new_was_called_with = path_str_to_use -- Log the identified string path
                local mock_instance = {
                    write = function(self, content, mode)
                        path_mock_ctrl.write_was_called_with_content = content
                        path_mock_ctrl.write_was_called_with_mode = mode
                        return path_mock_ctrl.write_return_value
                    end,
                    exists = function()
                        return path_mock_ctrl.exists_return_value
                    end,
                    is_root = function()
                        return path_mock_ctrl.is_root_return_value
                    end,
                    parent = function()
                        return path_mock_ctrl.parent_return_value
                    end,
                    absolute = function()
                        return path_mock_ctrl.absolute_return_value
                    end,
                    filename = path_mock_ctrl.filename_value,
                    joinpath = function(self, child)
                        -- Ensure path_str_to_use is available from the outer scope of Path.new
                        local current_p = path_str_to_use
                        if not current_p then
                            error(
                                'joinpath called on mock instance where path_str_to_use was not determined'
                            )
                        end
                        local joined = current_p
                            .. (current_p:sub(-1) == '/' and '' or '/')
                            .. child
                        return Path.new(joined)
                    end,
                }
                if path_str_to_use then -- Set filename if we successfully extracted a path string
                    local parts = {}
                    for part in string.gmatch(path_str_to_use, '[^/\\\\]+') do
                        table.insert(parts, part)
                    end
                    if #parts > 0 then
                        mock_instance.filename = parts[#parts]
                    else
                        mock_instance.filename = ''
                    end
                end
                return mock_instance
            end
            Path.new('direct call test') -- This should NOT fail the assertion in the mock above
        end)

        after_each(function()
            -- This after_each is specific to the 'M.save' describe block
            Path.new = prior_Path_new_for_save_block -- Restore Path.new
        end)

        it('should write the content from config_module.obj to the specified path', function()
            -- Arrange: Set up mock config values
            local test_path = '/my/test/path/data.json'
            local test_content = { key1 = 'value1', nested = { num = 123 } }
            local expected_json_content = vim.fn.json_encode(test_content)

            package.loaded['maorun.time.config'].obj = {
                path = test_path,
                content = test_content,
            }

            -- Act: Call the save function
            utils.save()

            -- Assert: Verify Path.new and write were called correctly
            assert.are.same(
                test_path,
                path_mock_ctrl.new_was_called_with,
                'Path.new should be called with the configured path.'
            )
            assert.are.same(
                expected_json_content,
                path_mock_ctrl.write_was_called_with_content,
                'Write should be called with JSON encoded content.'
            )
            assert.are.same(
                'w',
                path_mock_ctrl.write_was_called_with_mode,
                "Write should be called with mode 'w'."
            )
        end)
    end)

    describe('M.get_project_and_file_info', function()
        -- Test case 1: Input is a buffer number, .git found
        it(
            'should return project and file when input is buffer number and .git is found',
            function()
                -- Arrange
                local buffer_nr = 1
                local file_path_str = '/projects/myNeovimPlugin/.git/some/file.lua' -- Path returned by nvim_buf_get_name
                local expected_project = 'myNeovimPlugin'
                local expected_file = 'file.lua'

                nvim_buf_get_name_mock_ctrl.return_value = file_path_str

                -- Mock Path object behavior for finding .git
                -- Path.new("/projects/myNeovimPlugin/.git/some/file.lua")
                -- -> parent is "/projects/myNeovimPlugin/.git/some/"
                -- -> parent is "/projects/myNeovimPlugin/.git/"
                -- -> parent is "/projects/myNeovimPlugin/" -> .git exists here
                local git_dir_path_obj_mock = {
                    exists = function()
                        print('git_dir_path_obj_mock:exists() called -> true')
                        return true
                    end, -- .git/exists()
                    filename = '.git', -- not actually used for project name but for structure
                    absolute = function()
                        return '/projects/myNeovimPlugin/.git'
                    end,
                    is_root = function()
                        return false
                    end,
                }

                local project_path_obj_mock = {
                    exists = function()
                        return false
                    end, -- Default for non-.git paths
                    filename = expected_project,
                    absolute = function()
                        return '/projects/myNeovimPlugin/'
                    end,
                    joinpath = function(self, name)
                        print('project_path_obj_mock:joinpath called with:', name) -- DEBUG PRINT
                        if name == '.git' then
                            return git_dir_path_obj_mock
                        end
                        return {
                            exists = function()
                                print(
                                    'project_path_obj_mock:joinpath generic .exists called -> false for name: '
                                        .. name
                                )
                                return false
                            end,
                            absolute = function()
                                return self:absolute() .. name
                            end,
                            is_root = function()
                                return false
                            end,
                        }
                    end,
                    is_root = function()
                        return false
                    end,
                    parent = function()
                        -- Mock parent of project dir (e.g., "/projects/")
                        return {
                            filename = 'projects',
                            absolute = function()
                                return '/projects/'
                            end,
                            is_root = function()
                                return false
                            end,
                            parent = function()
                                return {
                                    filename = '',
                                    absolute = function()
                                        return '/'
                                    end,
                                    parent = function()
                                        return nil
                                    end,
                                    is_root = function()
                                        return true
                                    end,
                                }
                            end, -- root
                            joinpath = function()
                                return {
                                    exists = function()
                                        return false
                                    end,
                                }
                            end,
                        }
                    end,
                }

                local file_dir_obj_mock = {
                    filename = 'some',
                    absolute = function()
                        return '/projects/myNeovimPlugin/.git/some/'
                    end,
                    parent = function()
                        return project_path_obj_mock
                    end, -- This setup is a bit simplified, focusing on the .git check path
                    is_root = function()
                        return false
                    end,
                    joinpath = function(self, name)
                        if name == '.git' then
                            -- This case implies .git is a subdirectory of 'some', which is not the structure we're aiming for here.
                            -- The .git check should happen on "/projects/myNeovimPlugin/"
                            return {
                                exists = function()
                                    return false
                                end,
                            }
                        end
                        return {
                            exists = function()
                                return false
                            end,
                            absolute = function()
                                return self.absolute() .. name
                            end,
                        }
                    end,
                }

                -- Redefine Path.new for this specific test to control the chain of parent objects
                local original_plenary_new_for_this_test = TrueOriginalPlenaryPathNew -- Always capture the true original
                Path.new = function(first_arg, second_arg) -- Applied 2-arg strategy, removed debug prints
                    local path_str_to_use
                    local potential_self = nil
                    if type(first_arg) == 'table' and type(second_arg) == 'string' then
                        path_str_to_use = second_arg
                        potential_self = first_arg
                    elseif type(first_arg) == 'string' and second_arg == nil then
                        path_str_to_use = first_arg
                    else
                        if type(first_arg) == 'table' and first_arg.__plenary_path_meta then
                            return first_arg
                        end
                        return TrueOriginalPlenaryPathNew(first_arg, second_arg)
                    end

                    path_mock_ctrl.new_was_called_with = path_str_to_use
                    local result_obj

                    if path_str_to_use == file_path_str then
                        result_obj = {
                            filename = expected_file,
                            absolute = function()
                                return file_path_str
                            end,
                            parent = function()
                                return file_dir_obj_mock
                            end,
                            joinpath = function(self, name)
                                return {
                                    exists = function()
                                        return false
                                    end,
                                }
                            end,
                        }
                    elseif path_str_to_use == '/projects/myNeovimPlugin/.git/some/' then
                        result_obj = file_dir_obj_mock
                    elseif path_str_to_use == '/projects/myNeovimPlugin/' then
                        result_obj = project_path_obj_mock
                    elseif path_str_to_use == '/projects/' then
                        result_obj = project_path_obj_mock:parent()
                    elseif path_str_to_use == '/' then
                        result_obj = project_path_obj_mock:parent():parent()
                    else
                        if potential_self then
                            result_obj = TrueOriginalPlenaryPathNew(potential_self, path_str_to_use)
                        else
                            result_obj = TrueOriginalPlenaryPathNew(path_str_to_use)
                        end
                    end
                    return result_obj
                end

                -- Act
                local result = utils.get_project_and_file_info(buffer_nr)

                -- Assert
                assert.are.same(1, nvim_buf_get_name_mock_ctrl.call_count)
                assert.are.same(buffer_nr, nvim_buf_get_name_mock_ctrl.was_called_with)
                assert.is_not_nil(result)
                assert.are.same(expected_project, result.project)
                assert.are.same(expected_file, result.file)

                Path.new = original_plenary_new_for_this_test -- Restore to true original
            end
        )

        -- Test case 2: Input is a string path, .git found
        it('should return project and file when input is string path and .git is found', function()
            -- Arrange
            local file_path_str = '/work/anotherProject/.git/src/main.lua'
            local expected_project = 'anotherProject'
            local expected_file = 'main.lua'

            -- Mock Path object behavior
            local git_dir_path_obj_mock = {
                exists = function()
                    return true
                end,
                filename = '.git',
                absolute = function()
                    return '/work/anotherProject/.git'
                end,
                is_root = function()
                    return false
                end,
            }
            local project_path_obj_mock = {
                exists = function()
                    return false
                end,
                filename = expected_project,
                absolute = function()
                    return '/work/anotherProject/'
                end,
                joinpath = function(self, name)
                    if name == '.git' then
                        return git_dir_path_obj_mock
                    end
                    return {
                        exists = function()
                            return false
                        end,
                        absolute = function()
                            return self:absolute() .. name
                        end,
                        is_root = function()
                            return false
                        end,
                    }
                end,
                is_root = function()
                    return false
                end,
                parent = function()
                    return {
                        filename = 'work',
                        absolute = function()
                            return '/work/'
                        end,
                        is_root = function()
                            return false
                        end,
                        parent = function()
                            return {
                                filename = '',
                                absolute = function()
                                    return '/'
                                end,
                                is_root = function()
                                    return true
                                end,
                                parent = function()
                                    return nil
                                end,
                            }
                        end,
                        joinpath = function()
                            return {
                                exists = function()
                                    return false
                                end,
                            }
                        end,
                    }
                end,
            }
            local file_dir_obj_mock = {
                filename = 'src',
                absolute = function()
                    return '/work/anotherProject/.git/src/'
                end,
                parent = function()
                    return project_path_obj_mock
                end,
                is_root = function()
                    return false
                end,
                joinpath = function()
                    return {
                        exists = function()
                            return false
                        end,
                    }
                end,
            }

            local original_plenary_new_for_this_test = TrueOriginalPlenaryPathNew
            Path.new = function(first_arg, second_arg) -- Corrected 2-arg strategy for Test 4
                local path_str_to_use
                local potential_self = nil
                if type(first_arg) == 'table' and type(second_arg) == 'string' then
                    path_str_to_use = second_arg
                    potential_self = first_arg
                elseif type(first_arg) == 'string' and second_arg == nil then
                    path_str_to_use = first_arg
                else
                    if type(first_arg) == 'table' and first_arg.__plenary_path_meta then
                        return first_arg
                    end -- Avoid re-wrapping
                    return TrueOriginalPlenaryPathNew(first_arg, second_arg)
                end

                path_mock_ctrl.new_was_called_with = path_str_to_use
                local result_obj

                if path_str_to_use == file_path_str then
                    return {
                        filename = expected_file,
                        absolute = function()
                            return file_path_str
                        end,
                        parent = function()
                            return file_dir_obj_mock
                        end,
                        joinpath = function()
                            return {
                                exists = function()
                                    return false
                                end,
                            }
                        end,
                    }
                elseif path_arg == '/work/anotherProject/.git/src/' then
                    return file_dir_obj_mock
                elseif path_arg == '/work/anotherProject/' then
                    return project_path_obj_mock
                elseif path_arg == '/work/' then
                    return project_path_obj_mock:parent()
                elseif path_arg == '/' then
                    return project_path_obj_mock:parent():parent()
                else
                    return {
                        exists = function()
                            return path_mock_ctrl.exists_return_value
                        end,
                        filename = 'generic',
                        absolute = function()
                            return path_arg
                        end,
                        parent = function()
                            return nil
                        end,
                        joinpath = function()
                            return {
                                exists = function()
                                    return false
                                end,
                            }
                        end,
                    }
                end
            end

            -- Act
            local result = utils.get_project_and_file_info(file_path_str)

            -- Assert
            assert.is_not_nil(result)
            assert.are.same(expected_project, result.project)
            assert.are.same(expected_file, result.file)

            Path.new = original_plenary_new_for_this_test
        end)

        -- Test case 3: No .git found, fallback to parent directory name
        it('should fallback to parent directory name when .git is not found', function()
            -- Arrange
            local file_path_str = '/my_projects/project_alpha/src/main.lua'
            local expected_project = 'my_projects' -- Changed expectation based on refined utils.lua logic
            local expected_file = 'main.lua'

            -- Mock Path object behavior: No .git found anywhere up the chain
            local project_alpha_dir_mock = {
                exists = function()
                    return false
                end, -- for .git check
                filename = expected_project,
                absolute = function()
                    return '/my_projects/project_alpha/'
                end,
                joinpath = function(self, name)
                    return {
                        exists = function()
                            return false
                        end,
                        absolute = function()
                            return self:absolute() .. name
                        end,
                    }
                end, -- .git not found
                is_root = function()
                    return false
                end,
                parent = function()
                    return { -- /my_projects/
                        filename = 'my_projects',
                        absolute = function()
                            return '/my_projects/'
                        end,
                        joinpath = function(self, name)
                            return {
                                exists = function()
                                    return false
                                end,
                                absolute = function()
                                    return self:absolute() .. name
                                end,
                            }
                        end,
                        is_root = function()
                            return false
                        end,
                        parent = function() -- /
                            return {
                                filename = '', -- or some representation of root
                                absolute = function()
                                    return '/'
                                end,
                                joinpath = function(self, name)
                                    return {
                                        exists = function()
                                            return false
                                        end,
                                        absolute = function()
                                            return self:absolute() .. name
                                        end,
                                    }
                                end,
                                is_root = function()
                                    return true
                                end, -- Actual root
                                parent = function()
                                    return nil
                                end, -- Stop recursion
                            }
                        end,
                    }
                end,
            }
            local src_dir_mock = {
                filename = 'src',
                absolute = function()
                    return '/my_projects/project_alpha/src/'
                end,
                parent = function()
                    return project_alpha_dir_mock
                end,
                joinpath = function(self, name)
                    return {
                        exists = function()
                            return false
                        end,
                        absolute = function()
                            return self:absolute() .. name
                        end,
                    }
                end,
                is_root = function()
                    return false
                end,
            }

            local original_plenary_new_for_this_test = TrueOriginalPlenaryPathNew
            Path.new = function(first_arg, second_arg) -- Cleaned 2-arg strategy for Test 3
                local path_str_to_use
                local potential_self = nil
                if type(first_arg) == 'table' and type(second_arg) == 'string' then
                    path_str_to_use = second_arg
                    potential_self = first_arg
                elseif type(first_arg) == 'string' and second_arg == nil then
                    path_str_to_use = first_arg
                else
                    if type(first_arg) == 'table' and first_arg.__plenary_path_meta then
                        return first_arg
                    end -- Avoid re-wrapping
                    return TrueOriginalPlenaryPathNew(first_arg, second_arg)
                end

                path_mock_ctrl.new_was_called_with = path_str_to_use
                local result_obj

                if path_str_to_use == file_path_str then
                    result_obj = {
                        filename = expected_file,
                        absolute = function()
                            return file_path_str
                        end,
                        parent = function()
                            return src_dir_mock
                        end,
                        joinpath = function(self, name)
                            return {
                                exists = function()
                                    return false
                                end,
                                absolute = function()
                                    return self:absolute() .. name
                                end,
                            }
                        end,
                    }
                elseif path_str_to_use == '/my_projects/project_alpha/src/' then
                    result_obj = src_dir_mock
                elseif path_str_to_use == '/my_projects/project_alpha/' then
                    result_obj = project_alpha_dir_mock
                elseif path_str_to_use == '/my_projects/' then
                    result_obj = project_alpha_dir_mock:parent()
                elseif path_str_to_use == '/' then
                    result_obj = project_alpha_dir_mock:parent():parent()
                else
                    if potential_self then
                        result_obj = TrueOriginalPlenaryPathNew(potential_self, path_str_to_use)
                    else
                        result_obj = TrueOriginalPlenaryPathNew(path_str_to_use)
                    end
                end
                return result_obj
            end

            -- Act
            local result = utils.get_project_and_file_info(file_path_str)

            -- Assert
            assert.is_not_nil(result)
            assert.are.same(expected_project, result.project)
            assert.are.same(expected_file, result.file)
            Path.new = original_plenary_new_for_this_test
        end)

        -- Test Case 4 (Revised): Fallback to _root_ when file is in root directory
        it(
            'should fallback to _root_ for project when file is in root directory and no .git is found',
            function()
                -- Arrange
                local file_path_str = '/actual_file.txt' -- File directly in root
                local expected_project = '_root_'
                local expected_file = 'actual_file.txt'

                local root_dir_mock = {
                    filename = '', -- Or perhaps "/", Plenary behavior might vary. Assume "" for now.
                    absolute = function()
                        return '/'
                    end,
                    is_root = function()
                        return true
                    end, -- This is key for the _root_ logic
                    parent = function()
                        return nil
                    end, -- Root's parent is nil
                    joinpath = function(self, name)
                        assert.are.same('.git', name, 'Should check for .git in root')
                        return {
                            exists = function()
                                return false
                            end,
                            absolute = function()
                                return '/.git'
                            end,
                        } -- .git not found in root
                    end,
                }

                local original_plenary_new_for_this_test = TrueOriginalPlenaryPathNew
                Path.new = function(first_arg, second_arg) -- Applied 2-arg strategy for Test 5
                    local path_str_to_use
                    local potential_self = nil
                    if type(first_arg) == 'table' and type(second_arg) == 'string' then
                        path_str_to_use = second_arg
                        potential_self = first_arg
                    elseif type(first_arg) == 'string' and second_arg == nil then
                        path_str_to_use = first_arg
                    else
                        if type(first_arg) == 'table' and first_arg.__plenary_path_meta then
                            return first_arg
                        end -- Avoid re-wrapping
                        return TrueOriginalPlenaryPathNew(first_arg, second_arg)
                    end

                    path_mock_ctrl.new_was_called_with = path_str_to_use
                    local result_obj

                    if path_str_to_use == file_path_str then
                        return {
                            filename = expected_file,
                            absolute = function()
                                return file_path_str
                            end,
                            parent = function()
                                return root_dir_mock
                            end,
                            joinpath = function()
                                error(
                                    'Should not call joinpath on file object directly for .git search'
                                )
                            end,
                        }
                    elseif path_str_to_use == '/' then -- This is for file_path_obj:parent() and also for Path:new('/') in the or condition
                        result_obj = root_dir_mock
                    else
                        -- Fallback for any other Path.new calls
                        if potential_self then
                            result_obj = TrueOriginalPlenaryPathNew(potential_self, path_str_to_use)
                        else
                            result_obj = TrueOriginalPlenaryPathNew(path_str_to_use)
                        end
                    end
                    return result_obj
                end

                -- Act
                local result = utils.get_project_and_file_info(file_path_str)

                -- Assert
                assert.is_not_nil(result, 'Result should not be nil for file in root')
                assert.are.same(expected_project, result.project)
                assert.are.same(expected_file, result.file)
                Path.new = original_plenary_new_for_this_test
            end
        )

        -- Test Case 5: Fallback to default_project
        it('should fallback to default_project when parent directory info is unusable', function()
            -- Arrange
            local file_path_str = 'just_a_file.lua' -- A file without a clear parent directory context from Path:new
            local expected_project = 'default_project'
            local expected_file = 'just_a_file.lua'

            local problematic_parent_mock = {
                filename = nil, -- This will trigger the default_project fallback
                absolute = function()
                    return ''
                end, -- Should not matter if filename is nil
                is_root = function()
                    return false
                end,
                parent = function()
                    return nil
                end,
                joinpath = function()
                    return {
                        exists = function()
                            return false
                        end,
                    }
                end,
            }

            local original_plenary_new_for_this_test = TrueOriginalPlenaryPathNew
            Path.new = function(first_arg, second_arg) -- Applied 2-arg strategy for Test 6
                local path_str_to_use
                local potential_self = nil
                if type(first_arg) == 'table' and type(second_arg) == 'string' then
                    path_str_to_use = second_arg
                    potential_self = first_arg
                elseif type(first_arg) == 'string' and second_arg == nil then
                    path_str_to_use = first_arg
                else
                    if type(first_arg) == 'table' and first_arg.__plenary_path_meta then
                        return first_arg
                    end -- Avoid re-wrapping
                    return TrueOriginalPlenaryPathNew(first_arg, second_arg)
                end

                path_mock_ctrl.new_was_called_with = path_str_to_use
                local result_obj

                if path_str_to_use == file_path_str then
                    return {
                        filename = expected_file,
                        absolute = function()
                            return file_path_str
                        end,
                        parent = function()
                            return problematic_parent_mock
                        end,
                    }
                -- No .git search mock needed as parent().filename is nil, short-circuiting before .git search for fallback.
                -- The initial .git search loop starting from `problematic_parent_mock` would also fail or not run if parent is nil.
                -- Let's ensure the initial .git search fails:
                elseif path_str_to_use == '' then -- problematic_parent_mock:absolute()
                    result_obj = problematic_parent_mock
                else
                    if potential_self then
                        result_obj = TrueOriginalPlenaryPathNew(potential_self, path_str_to_use)
                    else
                        result_obj = TrueOriginalPlenaryPathNew(path_str_to_use)
                    end
                end
                return result_obj
            end

            -- Act
            local result = utils.get_project_and_file_info(file_path_str)

            -- Assert
            assert.is_not_nil(result)
            assert.are.same(expected_project, result.project)
            assert.are.same(expected_file, result.file)
            Path.new = original_plenary_new_for_this_test
        end)

        -- Test Case 6: Invalid inputs
        it('should return nil for invalid inputs', function()
            -- Test nil input
            assert.is_nil(utils.get_project_and_file_info(nil), 'Nil input should return nil')

            -- Test empty string input
            assert.is_nil(
                utils.get_project_and_file_info(''),
                'Empty string input should return nil'
            )

            -- Test when nvim_buf_get_name returns nil
            nvim_buf_get_name_mock_ctrl.return_value = nil
            assert.is_nil(utils.get_project_and_file_info(123), 'nvim_buf_get_name returns nil')

            -- Test when nvim_buf_get_name returns empty string
            nvim_buf_get_name_mock_ctrl.return_value = ''
            assert.is_nil(
                utils.get_project_and_file_info(456),
                'nvim_buf_get_name returns empty string'
            )
            nvim_buf_get_name_mock_ctrl.return_value = nil -- Reset for other tests

            -- Test for path that results in no filename (e.g. a directory)
            local previous_Path_new_for_this_test = Path.new
            Path.new = function(path_arg)
                -- This mock is specifically for the directory case
                if path_arg == '/some/directory/' then
                    return {
                        filename = '', -- Simulate how Plenary might return empty filename for a path ending in /
                        absolute = function()
                            return '/some/directory/'
                        end,
                        parent = function()
                            return {
                                filename = 'some',
                                absolute = function()
                                    return '/some/'
                                end,
                                parent = function()
                                    return nil
                                end,
                            }
                        end,
                    }
                else -- Fallback for other Path.new calls within the function, if any
                    if potential_self then
                        return TrueOriginalPlenaryPathNew(potential_self, path_str_to_use)
                    else
                        return TrueOriginalPlenaryPathNew(path_str_to_use)
                    end
                end
            end
            assert.is_nil(
                utils.get_project_and_file_info('/some/directory/'),
                'Directory path should return nil'
            )
            Path.new = original_plenary_new_for_this_test -- Restore to true original
        end)
    end)

    describe('M.calculateAverage', function()
        it('should calculate the average of hoursPerWeekday correctly', function()
            -- Arrange
            package.loaded['maorun.time.config'].config.hoursPerWeekday = {
                Monday = 8,
                Tuesday = 7,
                Wednesday = 6,
                Thursday = 8,
                Friday = 5,
                Saturday = 0, -- Should be included in count
                Sunday = 0, -- Should be included in count
            }
            -- Sum = 8+7+6+8+5+0+0 = 34. Count = 7. Average = 34/7
            local expected_average = 34 / 7

            -- Act
            local average = utils.calculateAverage()

            -- Assert
            assert.is_near(expected_average, average, 0.00001)
        end)

        it('should return 0 if hoursPerWeekday is empty', function()
            -- Arrange
            package.loaded['maorun.time.config'].config.hoursPerWeekday = {}
            local expected_average = 0

            -- Act
            local average = utils.calculateAverage()

            -- Assert
            assert.are.same(expected_average, average)
        end)

        it('should correctly calculate average including weekdays with 0 hours', function()
            -- Arrange
            package.loaded['maorun.time.config'].config.hoursPerWeekday = {
                Monday = 10,
                Tuesday = 0, -- This counts as a day
                Wednesday = 5,
                Thursday = 0, -- This counts as a day
                Friday = 3,
            }
            -- Sum = 10+0+5+0+3 = 18. Count = 5. Average = 18/5 = 3.6
            local expected_average = 18 / 5

            -- Act
            local average = utils.calculateAverage()

            -- Assert
            assert.is_near(expected_average, average, 0.00001)
        end)

        it('should handle a single day in hoursPerWeekday', function()
            -- Arrange
            package.loaded['maorun.time.config'].config.hoursPerWeekday = {
                Monday = 8,
            }
            local expected_average = 8

            -- Act
            local average = utils.calculateAverage()

            -- Assert
            assert.are.same(expected_average, average)
        end)
    end)
end)
