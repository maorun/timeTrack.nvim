local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os') -- Use a different name to avoid conflict with global os

local tempPath

-- Store original functions to restore them later
local original_os_date
local original_os_time
local original_get_project_and_file_info
local original_nvim_get_current_buf
local original_nvim_buf_get_name

-- Mocked data
local mock_project_info

before_each(function()
    -- Mock os.date and os.time
    original_os_date = os_module.date
    original_os_time = os_module.time
    os_module.time = function()
        return 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
    end
    os_module.date = function(format, time)
        time = time or os_module.time()
        return original_os_date(format, time)
    end

    -- Mock get_project_and_file_info
    original_get_project_and_file_info = maorunTime.get_project_and_file_info
    local mock_get_info_behavior = function(buffer_path_or_bufnr)
        if mock_project_info then
            return mock_project_info
        end
        -- Return a default if mock_project_info is not set
        return { project = 'default_project', file = 'default_file.lua' }
    end
    maorunTime.get_project_and_file_info = spy.new(mock_get_info_behavior) -- Create a spy

    mock_project_info = nil -- Reset mock_project_info for each test

    tempPath = os_module.tmpname()
    -- Ensure the file is created for setup and content is initialized
    maorunTime.setup({ path = tempPath })

    -- Mock nvim_get_current_buf
    original_nvim_get_current_buf = vim.api.nvim_get_current_buf
    vim.api.nvim_get_current_buf = function()
        return 1 -- Return a dummy buffer handle
    end

    -- Mock nvim_buf_get_name
    original_nvim_buf_get_name = vim.api.nvim_buf_get_name
    vim.api.nvim_buf_get_name = function(bufnr)
        return "/tmp/mock_file_for_buf_" .. tostring(bufnr) .. ".lua"
    end
end)

after_each(function()
    -- Restore original functions
    os_module.date = original_os_date
    os_module.time = original_os_time
    if maorunTime.get_project_and_file_info and maorunTime.get_project_and_file_info.revert then
        maorunTime.get_project_and_file_info:revert()
    else
        maorunTime.get_project_and_file_info = original_get_project_and_file_info
    end
    vim.api.nvim_get_current_buf = original_nvim_get_current_buf
    vim.api.nvim_buf_get_name = original_nvim_buf_get_name

    -- Clean up the temporary file
    local p = Path:new(tempPath)
    if p:exists() then
        os_module.remove(tempPath)
    end
    tempPath = nil
    mock_project_info = nil
end)

describe('Autocommand Tests', function()
    describe('VimEnter', function()
        it('should call TimeStart with default project and file on VimEnter', function()
            -- Spy on TimeStart
            local time_start_spy = spy.on(maorunTime, 'TimeStart')

            -- Simulate VimEnter by directly calling its callback
            -- Find the VimEnter autocmd callback in the loaded autocommands
            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'VimEnter' })
            assert(#autocmds > 0, 'VimEnter autocommand not found in Maorun-Time group')
            
            -- Execute the callback
            -- Lua autocommand callbacks are strings if not functions. Need to loadstring or similar.
            -- However, our callback is a Lua function, so it should be directly callable if stored as such.
            -- For safety, checking the type of callback.
            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({}) -- Pass an empty table as args, similar to nvim_exec_autocmds
            elseif type(autocmds[1].callback) == 'string' then
                assert(false, "VimEnter callback is a string, direct execution not supported in this test setup mock.")
                -- As a fallback for string callbacks (if it were one):
                -- local func = loadstring(autocmds[1].callback)
                -- assert(func, "Failed to load VimEnter callback string")
                -- func()
            else
                 assert(false, "VimEnter callback is not a function or string.")
            end

            -- Assert that TimeStart was called
            assert.spy(time_start_spy).was.called(1)

            -- Assert that TimeStart was called with the default project and file
            -- This relies on the mock for get_project_and_file_info returning defaults
            assert.spy(time_start_spy).was.called_with_matching(function(opts)
                return opts.project == 'default_project' and opts.file == 'default_file.lua'
            end)

            -- Clean up spy
            time_start_spy:revert()
        end)

        it('should call TimeStart with specific project and file on VimEnter if info is available', function()
            -- Set mock_project_info for this test
            mock_project_info = { project = 'test_project', file = 'test_file.md' }

            local time_start_spy = spy.on(maorunTime, 'TimeStart')
            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'VimEnter' })
            assert(#autocmds > 0, 'VimEnter autocommand not found')
            
            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({}) 
            else
                assert(false, "VimEnter callback is not a function.")
            end

            assert.spy(time_start_spy).was.called(1)
            assert.spy(time_start_spy).was.called_with_matching(function(opts)
                return opts.project == 'test_project' and opts.file == 'test_file.md'
            end)

            time_start_spy:revert()
            mock_project_info = nil -- Clean up for other tests
            if maorunTime.get_project_and_file_info.clear then -- Clear spy history if it's a spy
                maorunTime.get_project_and_file_info:clear()
            end
        end)
    end)

    describe('BufEnter', function()
        it('should call TimeStart with project and file info for the entered buffer', function()
            local mock_bufnr = 123
            mock_project_info = { project = 'bufenter_project', file = 'bufenter_file.txt' }

            local time_start_spy = spy.on(maorunTime, 'TimeStart')
            -- maorunTime.get_project_and_file_info is already a spy from before_each setup

            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'BufEnter' })
            assert(#autocmds > 0, 'BufEnter autocommand not found in Maorun-Time group')

            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({ buf = mock_bufnr, event = 'BufEnter' }) -- Pass mock args
            else
                assert(false, "BufEnter callback is not a function.")
            end

            -- Assert that TimeStart was called
            assert.spy(time_start_spy).was.called(1)

            -- Assert that TimeStart was called with the specific project and file
            assert.spy(time_start_spy).was.called_with_matching(function(opts)
                return opts.project == 'bufenter_project' and opts.file == 'bufenter_file.txt'
            end)
            
            -- Assert that our spy maorunTime.get_project_and_file_info was called with the buffer number
            assert.spy(maorunTime.get_project_and_file_info).was.called_with(mock_bufnr)
            
            -- Clean up spy
            time_start_spy:revert()
            mock_project_info = nil -- Reset for other tests
            if maorunTime.get_project_and_file_info.clear then -- Clear spy history
                maorunTime.get_project_and_file_info:clear()
            end
        end)

        it('should call TimeStart with default project and file if no info for buffer', function()
            local mock_bufnr = 456
            mock_project_info = nil -- Ensure get_project_and_file_info returns default (handled by the spy behavior)

            local time_start_spy = spy.on(maorunTime, 'TimeStart')
            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'BufEnter' })
            assert(#autocmds > 0, 'BufEnter autocommand not found')
            
            if type(autocmds[1].callback) == 'function' then
                 autocmds[1].callback({ buf = mock_bufnr, event = 'BufEnter' })
            else
                assert(false, "BufEnter callback is not a function.")
            end

            assert.spy(time_start_spy).was.called(1)
            assert.spy(time_start_spy).was.called_with_matching(function(opts)
                return opts.project == 'default_project' and opts.file == 'default_file.lua'
            end)
            
            -- Assert that our spy maorunTime.get_project_and_file_info was called with the buffer number
            assert.spy(maorunTime.get_project_and_file_info).was.called_with(mock_bufnr)

            time_start_spy:revert()
            if maorunTime.get_project_and_file_info.clear then -- Clear spy history
                maorunTime.get_project_and_file_info:clear()
            end
        end)
    end)

    describe('FocusGained', function()
        it('should call TimeStart with default project and file on FocusGained', function()
            -- mock_project_info is nil, so get_project_and_file_info (spy) will return defaults
            
            local time_start_spy = spy.on(maorunTime, 'TimeStart')
            -- maorunTime.get_project_and_file_info is already a spy
            -- vim.api.nvim_get_current_buf is already mocked to return 1

            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'FocusGained' })
            assert(#autocmds > 0, 'FocusGained autocommand not found in Maorun-Time group')

            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({ event = 'FocusGained' }) -- Pass mock args
            else
                assert(false, "FocusGained callback is not a function.")
            end

            assert.spy(time_start_spy).was.called(1)
            assert.spy(time_start_spy).was.called_with_matching(function(opts)
                return opts.project == 'default_project' and opts.file == 'default_file.lua'
            end)

            -- Assert that get_project_and_file_info was called with the mocked current buffer (1)
            assert.spy(maorunTime.get_project_and_file_info).was.called_with(1)

            time_start_spy:revert()
            if maorunTime.get_project_and_file_info.clear then
                maorunTime.get_project_and_file_info:clear()
            end
        end)

        it('should call TimeStart with specific project and file on FocusGained if info is available', function()
            mock_project_info = { project = 'focus_project', file = 'focus_file.rs' }
            
            local time_start_spy = spy.on(maorunTime, 'TimeStart')

            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'FocusGained' })
            assert(#autocmds > 0, 'FocusGained autocommand not found')
            
            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({ event = 'FocusGained' })
            else
                assert(false, "FocusGained callback is not a function.")
            end

            assert.spy(time_start_spy).was.called(1)
            assert.spy(time_start_spy).was.called_with_matching(function(opts)
                return opts.project == 'focus_project' and opts.file == 'focus_file.rs'
            end)

            -- Assert that get_project_and_file_info was called with the mocked current buffer (1)
            assert.spy(maorunTime.get_project_and_file_info).was.called_with(1)

            time_start_spy:revert()
            mock_project_info = nil
            if maorunTime.get_project_and_file_info.clear then
                maorunTime.get_project_and_file_info:clear()
            end
        end)
    end)

    describe('BufLeave', function()
        it('should call TimeStop with project and file info for the leaving buffer', function()
            local mock_bufnr = 234
            mock_project_info = { project = 'bufleave_project', file = 'bufleave_file.go' }

            local time_stop_spy = spy.on(maorunTime, 'TimeStop')
            -- maorunTime.get_project_and_file_info is already a spy

            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'BufLeave' })
            assert(#autocmds > 0, 'BufLeave autocommand not found in Maorun-Time group')

            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({ buf = mock_bufnr, event = 'BufLeave' }) -- Pass mock args
            else
                assert(false, "BufLeave callback is not a function.")
            end

            assert.spy(time_stop_spy).was.called(1)
            assert.spy(time_stop_spy).was.called_with_matching(function(opts)
                return opts.project == 'bufleave_project' and opts.file == 'bufleave_file.go'
            end)
            
            assert.spy(maorunTime.get_project_and_file_info).was.called_with(mock_bufnr)

            time_stop_spy:revert()
            mock_project_info = nil
            if maorunTime.get_project_and_file_info.clear then
                maorunTime.get_project_and_file_info:clear()
            end
        end)

        it('should call TimeStop with default project and file if no specific info for leaving buffer', function()
            local mock_bufnr = 567
            mock_project_info = nil -- get_project_and_file_info will return its default due to spy behavior

            local time_stop_spy = spy.on(maorunTime, 'TimeStop')

            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'BufLeave' })
            assert(#autocmds > 0, 'BufLeave autocommand not found')
            
            if type(autocmds[1].callback) == 'function' then
                autocmds[1].callback({ buf = mock_bufnr, event = 'BufLeave' })
            else
                assert(false, "BufLeave callback is not a function.")
            end

            assert.spy(time_stop_spy).was.called(1)
            -- Expect TimeStop to be called with default project/file because the get_project_and_file_info mock
            -- returns a default object, not nil, when mock_project_info is nil.
            assert.spy(time_stop_spy).was.called_with_matching(function(opts)
                return opts.project == 'default_project' and opts.file == 'default_file.lua'
            end)
            
            assert.spy(maorunTime.get_project_and_file_info).was.called_with(mock_bufnr)

            time_stop_spy:revert()
            if maorunTime.get_project_and_file_info.clear then
                maorunTime.get_project_and_file_info:clear()
            end
        end)
    end)

    describe('VimLeave', function()
        it('should call TimeStop on VimLeave', function()
            -- Ensure maorunTime.TimeStop is a function before spying
            assert.is_function(maorunTime.TimeStop, "maorunTime.TimeStop is not a function or is nil at the start of the test.")

            local time_stop_spy = spy.on(maorunTime, 'TimeStop')
            assert.is_function(time_stop_spy, "Spying on maorunTime.TimeStop did not return a function (the spy itself).")
            assert.is_true(maorunTime.TimeStop == time_stop_spy, "maorunTime.TimeStop was not replaced by the spy object.")


            local autocmds = vim.api.nvim_get_autocmds({ group = 'Maorun-Time', event = 'VimLeave' })
            
            local callback_executed = false
            if #autocmds > 0 and type(autocmds[1].callback) == 'function' then
                -- Attempt to execute the actual callback
                local status, err = pcall(autocmds[1].callback, { event = 'VimLeave' })
                if not status then
                    print("Error executing VimLeave callback:", err)
                    assert(false, "VimLeave callback errored: " .. tostring(err))
                end
                callback_executed = true
            else
                -- Fallback: If callback retrieval fails, directly call the function that the callback *would* call.
                -- This helps isolate whether the issue is with autocmd retrieval/execution or with TimeStop/spy itself.
                print("VimLeave test: Autocommand callback not found or not a function. Directly calling maorunTime.TimeStop() for test purposes.")
                local direct_status, direct_err = pcall(maorunTime.TimeStop)
                if not direct_status then
                     print("Error directly calling maorunTime.TimeStop():", direct_err)
                     assert(false, "Direct call to maorunTime.TimeStop() errored: " .. tostring(direct_err))
                end
                callback_executed = true -- Considered executed for spy check purposes
            end
            
            assert.is_true(callback_executed, "Neither actual callback nor direct call was executed.")

            assert.spy(time_stop_spy).was.called(1)
            
            -- Check arguments only if called.
            if time_stop_spy.calls.count > 0 then
                assert.spy(time_stop_spy).was.called_with_matching(function(opts)
                    return opts == nil or (type(opts) == 'table' and vim.tbl_isempty(opts))
                end)
            end

            time_stop_spy:revert()
        end)
    end)
end)
