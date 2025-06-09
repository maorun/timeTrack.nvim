local time = require('maorun.time')

describe('Time Pause and Resume', function()
    -- Clean up before each test to ensure a consistent state
    before_each(function()
        -- Reset the paused state to false before each test
        -- This assumes that the functions under test might alter a global or module-level state.
        -- If 'obj.content' is accessible and can be reset, do it here.
        -- For now, we'll rely on TimeResume() to reset the state if previously paused.
        -- and the init() function called by isPaused() to initialize the state.
        -- A more robust way would be to directly reset `obj.content.paused` if possible,
        -- or ensure 'init()' always resets to a known default for testing.

        -- Create a dummy time file for testing. This ensures that `init()` reads a known state.
        -- The structure of this JSON should match what `save(obj)` would write,
        -- meaning `paused` should be a top-level key in `obj.content`.
        local Path = require('plenary.path')
        local data_dir_path_str = vim.fn.stdpath('data')
        local data_dir = Path:new(data_dir_path_str)
        data_dir:mkdir({ parents = true, exist_ok = true }) -- Ensure data directory exists

        local test_time_file_path = data_dir_path_str .. Path.path.sep .. 'maorun-time-test.json'
        -- Initialize with paused = false and default hours, similar to how `init` and `save` would structure it.
        local initial_data = {
            paused = false,
            hoursPerWeekday = { -- Add default or test-specific hours to mimic real data structure
                Monday = 8,
                Tuesday = 8,
                Wednesday = 8,
                Thursday = 8,
                Friday = 8,
                Saturday = 0,
                Sunday = 0,
            },
            data = {}, -- Include the 'data' table to prevent errors if accessed
        }
        Path:new(test_time_file_path):write(vim.fn.json_encode(initial_data), 'w')

        -- Configure the time module to use this test file and some default hours.
        -- The hoursPerWeekday here will be merged by init if not present in the file,
        -- but it's good practice to have the file be self-contained if possible.
        time.setup({
            path = test_time_file_path,
            hoursPerWeekday = initial_data.hoursPerWeekday,
        })
    end)

    describe('isPaused()', function()
        it(
            'should return false before TimePause() is ever called (due to before_each setup)',
            function()
                assert.is_false(time.isPaused())
            end
        )

        it('should return true after TimePause() is called', function()
            time.TimePause()
            assert.is_true(time.isPaused())
        end)

        it('should return false after TimePause() then TimeResume() is called', function()
            time.TimePause()
            time.TimeResume()
            assert.is_false(time.isPaused())
        end)
    end)

    describe('TimePause()', function()
        it('should cause isPaused() to return true', function()
            time.TimePause()
            assert.is_true(time.isPaused())
        end)
    end)

    describe('TimeResume()', function()
        it('should cause isPaused() to return false after TimePause()', function()
            time.TimePause() -- Ensure it's paused first
            time.TimeResume()
            assert.is_false(time.isPaused())
        end)

        it('should not error if called when not paused', function()
            -- Ensure time is not paused
            if time.isPaused() then
                time.TimeResume()
            end -- reset if needed
            assert.is_false(time.isPaused()) -- verify it's not paused

            local success, err = pcall(time.TimeResume)
            assert.is_true(
                success,
                'TimeResume() should not error if called when not paused. Error: ' .. tostring(err)
            )
            assert.is_false(
                time.isPaused(),
                'isPaused() should still return false after TimeResume() when not paused.'
            )
        end)
    end)
end)
