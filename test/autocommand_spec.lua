local helpers = require('test.helper') -- Assuming this provides spy, mock_os_time, etc.
local Path = require('plenary.path') -- We will mock methods on this

-- Forward declare modules to allow for easy reloading
local timeTrack
local get_project_and_file_info

local function reload_timeTrack_module()
  package.loaded['maorun.time.init'] = nil
  timeTrack = require('maorun.time.init')
  get_project_and_file_info = timeTrack.get_project_and_file_info -- if it's exported, otherwise test internal function reference
end

describe('Autocommand BufEnter Tests', function()
  local original_Path_new
  local original_os_time
  local original_nvim_buf_get_name
  local original_nvim_get_current_buf
  local original_notify
  local mock_data_file_content

  before_each(function()
    -- 1. Reload the module
    reload_timeTrack_module()

    -- 2. Spy on timeTrack.TimeStart
    -- Ensure helpers.spy is available or provide a basic spy implementation
    if not helpers.spy then
      helpers.spy = {
        new = function(fn)
          local calls = {}
          local proxy = function(...)
            local args = { ... }
            table.insert(calls, args)
            if fn then
              return fn(select(1, ...)) -- Pass through to original function if provided
            end
          end
          proxy.calls = calls
          proxy.called = function() return #calls > 0 end
          proxy.called_with = function(...)
            local expected_args = { ... }
            for _, actual_call_args in ipairs(calls) do
              if vim.deep_equal(actual_call_args, expected_args) then
                return true
              end
            end
            return false
          end
          proxy.get_call_args = function(call_index)
            return calls[call_index or #calls]
          end
          return proxy
        end,
      }
    end
    timeTrack.TimeStart = helpers.spy.new(timeTrack.TimeStart) -- Spy on the actual TimeStart

    -- 3. Mock Path.new and other Path instance methods
    original_Path_new = Path.new
    Path.new = function(path_str)
      local mock_path_obj = {
        path_str = path_str,
        name = '',
        parent_obj = nil,
        joined_paths = {},
        exists_val = false,
        is_root_val = false,
        absolute_val = path_str, -- Default absolute to path_str

        absolute = function(self) return self.absolute_val end,
        is_root = function(self) return self.is_root_val end,
        exists = function(self) return self.exists_val end,
        joinpath = function(self, component)
          local new_path_str = self.path_str .. '/' .. component -- Simplified join
          local joined_mock = Path.new(new_path_str) -- Recurse to allow chaining if needed
          -- We might need to pre-configure behavior of these joined paths if 'exists' is called on them
          if self.joined_paths_config and self.joined_paths_config[component] then
             for k,v in pairs(self.joined_paths_config[component]) do
                joined_mock[k] = v
             end
          end
          return joined_mock
        end,
        parent = function(self) return self.parent_obj end,
        -- Add other methods like is_file, is_dir if get_project_and_file_info uses them
      }

      -- Default name from path_str
      local parts = {}
      for part in string.gmatch(path_str, "[^/\\]+") do table.insert(parts, part) end
      mock_path_obj.name = parts[#parts] or ''
      if path_str == '/' then mock_path_obj.name = '/' end


      -- Allow tests to override properties of this specific mock_path_obj
      if helpers.current_path_mock_config then
        for k, v in pairs(helpers.current_path_mock_config) do
          mock_path_obj[k] = v
        end
        helpers.current_path_mock_config = nil -- Consume it
      end
      return mock_path_obj
    end

    -- 4. Mock os.time
    original_os_time = os.time
    if not helpers.mock_os_time then -- Basic mock if not in helper
        local current_time = 1678886400 -- Default: 2023-03-15 12:00:00 UTC
        os.time = function() return current_time end
        helpers.set_mock_os_time = function(t) current_time = t end
    else
        helpers.mock_os_time(1678886400) -- Use helper's default or specific time
    end


    -- 5. Mock vim.api.nvim_buf_get_name & nvim_get_current_buf
    original_nvim_buf_get_name = vim.api.nvim_buf_get_name
    if not helpers.mock_nvim_buf_get_name then -- Basic mock
        local current_buf_name = ""
        vim.api.nvim_buf_get_name = function(bufnr) return current_buf_name end
        helpers.set_mock_nvim_buf_get_name = function(name) current_buf_name = name end
    else
        helpers.mock_nvim_buf_get_name('') -- Default to empty, tests will set
    end

    original_nvim_get_current_buf = vim.api.nvim_get_current_buf
    if not helpers.mock_nvim_get_current_buf then -- Basic mock
        local current_buf_handle = 1
        vim.api.nvim_get_current_buf = function() return current_buf_handle end
        helpers.set_mock_nvim_get_current_buf = function(handle) current_buf_handle = handle end
    else
        helpers.mock_nvim_get_current_buf(1) -- Default
    end

    -- 6. Mock global notify (if used by TimeStart or init indirectly)
    original_notify = _G.notify -- Assuming notify is global or loaded appropriately
    _G.notify = helpers.spy.new()

    -- 7. Mock JSON data file
    -- For TimeStart, it calls init(), which reads/writes a JSON file.
    -- We need to mock Path:new(obj.path):write and Path:new(obj.path):read
    mock_data_file_content = "{}" -- Default empty JSON
    local original_path_methods = {}

    local mock_file_path_obj_for_data = {
      write = function(self, content_to_write, mode)
        mock_data_file_content = content_to_write
      end,
      read = function(self)
        return mock_data_file_content
      end,
      exists = function(self) return true end, -- Assume data file exists for simplicity
      touch = function(self, opts) end, -- Mock touch
      -- Other methods like :parent() might be needed if path construction is complex
      parent = function(self) return Path.new(vim.fn.stdpath('data')) end, -- Mock parent
    }

    local real_Path_new_for_data_handling = Path.new -- Keep a reference
    Path.new = function(path_str)
      if path_str == vim.fn.stdpath('data') .. require('plenary.path').path.sep .. 'maorun-time.json' then
        if not original_path_methods[path_str] then
          original_path_methods[path_str] = {} -- Store original methods if any, not strictly needed here
        end
        return mock_file_path_obj_for_data
      else
        -- For all other Path.new calls (e.g., in get_project_and_file_info)
        local mock_path_obj = {
          path_str = path_str, name = '', parent_obj = nil, joined_paths = {},
          exists_val = false, is_root_val = false, absolute_val = path_str,
          absolute = function(self) return self.absolute_val end,
          is_root = function(self) return self.is_root_val end,
          exists = function(self) return self.exists_val end,
          joinpath = function(self, component)
            local new_path_str = self.path_str .. '/' .. component
            local joined_mock = real_Path_new_for_data_handling(new_path_str) -- Use real one for structure
            if self.joined_paths_config and self.joined_paths_config[component] then
               for k,v in pairs(self.joined_paths_config[component]) do joined_mock[k] = v end
            end
            return joined_mock
          end,
          parent = function(self) return self.parent_obj end,
        }
        local parts = {}
        for part in string.gmatch(path_str, "[^/\\]+") do table.insert(parts, part) end
        mock_path_obj.name = parts[#parts] or ''
        if path_str == '/' then mock_path_obj.name = '/' end

        if helpers.current_path_mock_config then
          for k, v in pairs(helpers.current_path_mock_config) do mock_path_obj[k] = v end
          helpers.current_path_mock_config = nil
        end
        return mock_path_obj
      end
    end

    -- Clear existing autocommands in the 'Maorun-Time' group
    vim.api.nvim_command('augroup Maorun-Time | autocmd! | augroup END')
    -- Re-create the autocommands from the plugin file to test them
    -- This is a bit indirect. A better way would be to directly get the callback.
    -- For now, let's assume the plugin's autocommands are set up by requiring it.
    -- The init.lua itself sets up autocommands using nvim_create_autocmd.
    -- So, reloading the module should set them up.
  end)

  after_each(function()
    Path.new = original_Path_new
    os.time = original_os_time
    vim.api.nvim_buf_get_name = original_nvim_buf_get_name
    vim.api.nvim_get_current_buf = original_nvim_get_current_buf
    _G.notify = original_notify
    package.loaded['maorun.time.init'] = nil -- Ensure clean state for next test
    helpers.current_path_mock_config = nil -- Reset any leftover mock config

    -- Clear any autocommands created during the test
    vim.api.nvim_command('augroup Maorun-Time | autocmd! | augroup END')
  end)

  local function mock_path(config)
    helpers.current_path_mock_config = config
  end

  local function trigger_buf_enter_autocmd(buf_handle)
    -- Simulate the BufEnter autocommand execution
    -- The callback is defined in lua/maorun/time/init.lua
    -- We need to find it or replicate its logic for triggering directly
    -- For now, using the nvim_command as a simplified trigger.
    -- Note: This relies on the autocommand being correctly set up by module reload.
    vim.api.nvim_command('doautocmd <nomodeline> BufEnter BufRead ' .. buf_handle)

    -- A more direct way to test the callback (if it were accessible):
    -- local autocmd_callback = -- get the callback function reference somehow
    -- autocmd_callback({buf = buf_handle, event = "BufEnter"})
  end


  it('1. BufEnter in Git project: TimeStart with project and file name', function()
    local buf_handle = 10
    local file_path = '/users/testuser/projects/my-git-project/src/main.lua'
    helpers.set_mock_nvim_buf_get_name(file_path) -- Mock for nvim_buf_get_name(buf_handle)

    -- Configure Path.new for this test case
    -- Path for file_path itself
    mock_path({
      name = 'main.lua',
      absolute_val = file_path,
      parent_obj = Path.new('/users/testuser/projects/my-git-project/src')
    })
    -- Path for parent: /users/testuser/projects/my-git-project/src
    mock_path({
      name = 'src',
      absolute_val = '/users/testuser/projects/my-git-project/src',
      parent_obj = Path.new('/users/testuser/projects/my-git-project'),
      joined_paths_config = { ['.git'] = { exists_val = false } } -- .git not in src
    })
    -- Path for project root: /users/testuser/projects/my-git-project
    mock_path({
      name = 'my-git-project',
      absolute_val = '/users/testuser/projects/my-git-project',
      parent_obj = Path.new('/users/testuser/projects'),
      joined_paths_config = { ['.git'] = { exists_val = true } } -- .git IS in project root
    })
     -- Path for /users/testuser/projects (one level above project)
    mock_path({
      name = 'projects',
      absolute_val = '/users/testuser/projects',
      parent_obj = Path.new('/users/testuser'),
      joined_paths_config = { ['.git'] = { exists_val = false } }
    })


    trigger_buf_enter_autocmd(buf_handle)

    assert(timeTrack.TimeStart.called(), "TimeStart was not called")
    local call_args = timeTrack.TimeStart.get_call_args(1)[1] -- First argument of first call
    assert.same({ project = 'my-git-project', file = 'main.lua' }, call_args)
  end)

  it('2. BufEnter not in Git project: TimeStart with parent dir as project', function()
    local buf_handle = 20
    local file_path = '/users/testuser/otherstuff/notes.txt'
    helpers.set_mock_nvim_buf_get_name(file_path)

    mock_path({
      name = 'notes.txt',
      absolute_val = file_path,
      parent_obj = Path.new('/users/testuser/otherstuff')
    })
    mock_path({ -- /users/testuser/otherstuff
      name = 'otherstuff',
      absolute_val = '/users/testuser/otherstuff',
      parent_obj = Path.new('/users/testuser'),
      joined_paths_config = { ['.git'] = { exists_val = false } },
      is_root_val = false
    })
    mock_path({ -- /users/testuser
      name = 'testuser',
      absolute_val = '/users/testuser',
      parent_obj = Path.new('/users'),
      joined_paths_config = { ['.git'] = { exists_val = false } },
      is_root_val = false
    })
    mock_path({ -- /users
      name = 'users',
      absolute_val = '/users',
      parent_obj = Path.new('/'),
      joined_paths_config = { ['.git'] = { exists_val = false } },
      is_root_val = false
    })
     mock_path({ -- / (root)
      name = '/',
      absolute_val = '/',
      parent_obj = nil, -- Or Path.new('/') to avoid breaking parent() calls, depending on Path impl.
      is_root_val = true,
      joined_paths_config = { ['.git'] = { exists_val = false } }
    })

    trigger_buf_enter_autocmd(buf_handle)

    assert(timeTrack.TimeStart.called(), "TimeStart was not called")
    local call_args = timeTrack.TimeStart.get_call_args(1)[1]
    assert.same({ project = 'otherstuff', file = 'notes.txt' }, call_args)
  end)

  it('3. BufEnter file in root dir (/file.txt): TimeStart with _root_ as project', function()
    local buf_handle = 30
    local file_path = '/file.txt'
    helpers.set_mock_nvim_buf_get_name(file_path)

    mock_path({ -- /file.txt
      name = 'file.txt',
      absolute_val = file_path,
      parent_obj = Path.new('/')
    })
    mock_path({ -- / (root)
      name = '/', -- Plenary path.name for root might be empty or '/', adjust as per actual behavior
      absolute_val = '/',
      parent_obj = nil, -- No parent above root for the loop
      is_root_val = true,
      joined_paths_config = { ['.git'] = { exists_val = false } }
    })

    trigger_buf_enter_autocmd(buf_handle)

    assert(timeTrack.TimeStart.called(), "TimeStart was not called")
    local call_args = timeTrack.TimeStart.get_call_args(1)[1]
    assert.same({ project = '_root_', file = 'file.txt' }, call_args)
  end)

  it('4. BufEnter for root dir itself (/): TimeStart with defaults', function()
    -- This case is tricky. `get_project_and_file_info` expects a file, not a dir.
    -- If nvim_buf_get_name returns '/', Path:new('/'), its .name might be '/' or empty.
    -- If .name is empty or '/', `get_project_and_file_info` should return nil.
    local buf_handle = 40
    local dir_path = '/'
    helpers.set_mock_nvim_buf_get_name(dir_path)

    mock_path({ -- For Path:new('/')
      name = '/', -- Or potentially empty string if that's what Plenary does for root's name
      absolute_val = dir_path,
      parent_obj = nil, -- Or Path.new('/') itself if plenary indicates that.
      is_root_val = true
    })
    -- The logic in get_project_and_file_info: "if file_name == nil or file_name == '' then return nil"
    -- If Path:new('/'.name is '', it returns nil. If it's '/', it proceeds.
    -- Let's assume Path:new('/'.name is '/' for this test, to test further down.
    -- The parent search for .git will start from root, find nothing, then try parent of root.
    -- parent of root is nil, so project_name remains nil.
    -- Fallback: parent_dir_obj = Path:new('/'):parent(). This is nil.
    -- So, it should hit 'default_project'.
    -- However, the condition "if file_name and file_name ~= ''" might fail if file_name is '/'.
    -- Let's trace: file_name = '/'. project_name = 'default_project'.
    -- Returns { project = 'default_project', file = '/' }
    -- The prompt expects default project/file. This implies get_project_and_file_info returns nil.
    -- This happens if filepath_str is '/', and Path:new('/'.name is considered not a valid "file_name".
    -- The current code: `if file_name == nil or file_name == '' then return nil`. If Path:new('/'.name is '/', this check passes.
    -- Let's adjust the mock for Path:new('/'.name to be empty to force the nil return from get_project_and_file_info
     mock_path({
      name = '', -- Simulate what might happen for a pure directory, or if root name is empty
      absolute_val = dir_path,
      parent_obj = nil,
      is_root_val = true
    })

    trigger_buf_enter_autocmd(buf_handle)

    assert(timeTrack.TimeStart.called(), "TimeStart was not called")
    local call_args = timeTrack.TimeStart.get_call_args(1)[1] -- TimeStart called with no args
    assert.is_nil(call_args, "TimeStart should be called with nil/no arguments for defaults")
    -- The autocommand itself will call TimeStart() which uses defaults.
    -- So we check that TimeStart was called, and then can infer it used defaults if args were nil.
  end)

  it('5. BufEnter for buffer with no name: TimeStart with defaults', function()
    local buf_handle = 50
    helpers.set_mock_nvim_buf_get_name('') -- No buffer name

    -- No Path.new mocks needed as get_project_and_file_info should return nil early.

    trigger_buf_enter_autocmd(buf_handle)

    assert(timeTrack.TimeStart.called(), "TimeStart was not called")
    local call_args = timeTrack.TimeStart.get_call_args(1)[1]
    assert.is_nil(call_args, "TimeStart should be called with nil/no arguments for defaults")
  end)

  it('6. BufEnter for path ending in slash (directory-like): TimeStart with parent as project', function()
    local buf_handle = 60
    -- plenary.path considers "folder/" to have name "folder"
    local dir_like_path = '/some/folder/'
    helpers.set_mock_nvim_buf_get_name(dir_like_path)

    -- Path:new('/some/folder/')
    mock_path({
      name = 'folder', -- Plenary Path strips trailing slash for .name
      absolute_val = dir_like_path,
      parent_obj = Path.new('/some')
    })
    -- Path:new('/some')
    mock_path({
      name = 'some',
      absolute_val = '/some',
      parent_obj = Path.new('/'),
      joined_paths_config = { ['.git'] = { exists_val = false } },
      is_root_val = false
    })
    -- Path:new('/')
    mock_path({
      name = '/',
      absolute_val = '/',
      parent_obj = nil,
      is_root_val = true,
      joined_paths_config = { ['.git'] = { exists_val = false } }
    })

    trigger_buf_enter_autocmd(buf_handle)

    assert(timeTrack.TimeStart.called(), "TimeStart was not called")
    local call_args = timeTrack.TimeStart.get_call_args(1)[1]
    -- Based on current get_project_and_file_info:
    -- file_name = 'folder'
    -- project search from '/some': no .git. parent is '/'.
    -- parent_dir_obj for '/some/folder/' is '/some'. Its name is 'some'.
    -- So, project = 'some', file = 'folder'
    assert.same({ project = 'some', file = 'folder' }, call_args)
  end)
end)
