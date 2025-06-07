local helper = require('test.helper')
local time_init = require('maorun.time.init')

describe('BufEnter Autocommand', function()
    local mock_TimeStart_calls

    local function mock_TimeStart_spy(...)
        table.insert(mock_TimeStart_calls, { ... })
    end

    before_each(function()
        mock_TimeStart_calls = {}
        -- Mock TimeStart globally for the module
        helper.mock_function('time_init', 'TimeStart', mock_TimeStart_spy)
    end)

    after_each(function()
        helper.teardown()
    end)

    describe('Test Case 1: BufEnter triggers TimeStart with project and file info', function()
        it('should call TimeStart with project and file info', function()
            -- Mock get_project_and_file_info
            local expected_info = { project = 'TestProject', file = 'TestFile.lua' }
            helper.mock_function('time_init', 'get_project_and_file_info', function(bufnr)
                assert.is_number(
                    bufnr,
                    'get_project_and_file_info should be called with a buffer number'
                )
                return expected_info
            end)

            -- Create a dummy buffer
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_current_buf(buf) -- Make it current so BufEnter might apply to it

            -- Simulate BufEnter autocommand
            -- The autocommand in init.lua uses args.buf
            vim.api.nvim_exec_autocmds('BufEnter', { buffer = buf, modeline = false })

            -- Assertions
            assert.are.same(1, #mock_TimeStart_calls, 'TimeStart should have been called once')
            if #mock_TimeStart_calls > 0 then
                assert.are.same(
                    expected_info,
                    mock_TimeStart_calls[1][1],
                    'TimeStart called with incorrect arguments'
                )
            end

            -- Clean up buffer
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end)

    describe('Test Case 2: BufEnter triggers TimeStart with default values', function()
        it('should call TimeStart with no arguments (or default handling)', function()
            -- Mock get_project_and_file_info to return nil
            helper.mock_function('time_init', 'get_project_and_file_info', function(bufnr)
                assert.is_number(
                    bufnr,
                    'get_project_and_file_info should be called with a buffer number'
                )
                return nil
            end)

            -- Create a dummy buffer
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_current_buf(buf)

            -- Simulate BufEnter autocommand
            vim.api.nvim_exec_autocmds('BufEnter', { buffer = buf, modeline = false })

            -- Assertions
            assert.are.same(1, #mock_TimeStart_calls, 'TimeStart should have been called once')
            if #mock_TimeStart_calls > 0 then
                -- TimeStart() in lua means the first arg is nil.
                -- If it was called with no args, the table mock_TimeStart_calls[1] would be empty.
                -- If it was called with TimeStart(), then mock_TimeStart_calls[1][1] would be nil.
                assert.is_nil(
                    mock_TimeStart_calls[1][1],
                    'TimeStart should be called with nil or no arguments'
                )
            end
            -- Clean up buffer
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end)
end)
