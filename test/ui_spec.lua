-- Test suite for maorun.time.ui.select (formerly maorun.ui.select)

local helper = require('test.helper')
local time_ui = require('maorun.time.ui') -- CORRECTED: System Under Test

-- Helper for assertions (minimal version for this environment)
local assert = {
    is_true = function(val, msg)
        if not val then
            error(msg or 'Assertion failed: expected true')
        end
    end,
    is_false = function(val, msg)
        if val then
            error(msg or 'Assertion failed: expected false')
        end
    end,
    are_equal = function(expected, actual, msg)
        if expected ~= actual then
            -- Special handling for nil vs string comparison for better error messages
            local exp_str = expected == nil and 'nil' or "'" .. tostring(expected) .. "'"
            local act_str = actual == nil and 'nil' or "'" .. tostring(actual) .. "'"
            error(string.format(msg or 'Assertion failed: expected %s, got %s', exp_str, act_str))
        end
    end,
    is_nil = function(val, msg)
        if val ~= nil then
            error(msg or "Assertion failed: expected nil, got '" .. tostring(val) .. "'")
        end
    end,
    is_not_nil = function(val, msg)
        if val == nil then
            error(msg or 'Assertion failed: expected not nil')
        end
    end,
    table_contains = function(tbl, val, msg)
        for _, v in ipairs(tbl) do
            if v == val then
                return
            end
        end
        error(msg or 'Assertion failed: table does not contain ' .. tostring(val))
    end,
}

-- The maorun.time.ui module might have a setup function.
-- If it needs the weekday_select_module, helper already put the mock in package.loaded.
-- So, direct setup like before might not be needed unless maorun.time.ui.setup does more.
-- Assuming maorun.time.ui.setup is similar to the previous maorun.ui.setup
if time_ui.setup then
    time_ui.setup({ weekday_select_module = package.loaded['maorun.time.weekday_select'] })
end

local function describe(text, fn)
    print('DESCRIBE: ' .. text)
    fn()
end

local current_test_name = ''
local function it(text, fn)
    current_test_name = text
    -- Vusted will print the test name. Redundant print('  IT: ' .. text) removed.

    -- Reset all mock states and flags before each test
    helper.input_mock:reset()
    helper.select_mock:reset()
    helper.weekday_select_mock:reset()
    helper.notify_mock:reset()
    helper.reset_all_was_called_flags()

    -- Let Vusted handle pcall and error reporting for the test function (fn)
    fn()

    -- Teardown all global mocks after each test to ensure clean state for the next 'it' block
    -- Vusted runs each 'it' block in isolation, but mocks are global so manual teardown is good.
    helper.teardown_all_mocks()
    current_test_name = '' -- Reset test name
end

describe('maorun.time.ui.select', function()
    it('should handle default options (all true)', function()
        -- print('    RUNNING TEST: should handle default options (all true)') -- Vusted will show test status
        local cb_hours, cb_weekday, cb_project, cb_file
        local callback = function(h, wd, p, f)
            -- print("    CALLBACK EXECUTED for 'default options'") -- Debug print, can be removed
            cb_hours, cb_weekday, cb_project, cb_file = h, wd, p, f
        end

        helper.input_mock:set_texts_to_return({ 'test_project_default', 'test_file_default', '5' })
        helper.weekday_select_mock:set_selected_weekday('Monday')
        helper.select_mock:set_item_to_return('Monday') -- For vim.ui.select fallback

        print("    CALLING time_ui.select for 'default options'")
        time_ui.select({ project = true, file = true, weekday = true, hours = true }, callback)
        print("    RETURNED from time_ui.select for 'default options'")

        assert.are_equal('test_project_default', cb_project)
        assert.are_equal('test_file_default', cb_file)
        assert.are_equal('Monday', cb_weekday)
        assert.are_equal(5, cb_hours)

        assert.are_equal(3, helper.input_mock:get_call_count())
        local prompts = helper.input_mock:get_prompts_called_with()
        assert.table_contains(prompts, 'Project name? (default: default_project) ')
        assert.table_contains(prompts, 'File name? (default: default_file) ')
        assert.table_contains(prompts, 'How many hours? ')
        assert.is_true(
            helper.weekday_select_mock:was_called_flag() or helper.select_mock:was_called_flag(),
            'Either custom weekday select or vim.ui.select for weekday should be called'
        )

        if helper.weekday_select_mock:was_called_flag() then
            assert.are_equal(
                'Which day?', -- This is the prompt from maorun.time.weekday_select mock via its options
                helper.weekday_select_mock:get_show_called_with_options().prompt_title
            )
        elseif helper.select_mock:was_called_flag() then
            assert.are_equal(
                'Which day? ', -- This is the prompt from direct vim.ui.select
                helper.select_mock:get_prompt()
            )
        end
        print("    ASSERTIONS COMPLETED for 'default options'")
    end)

    it('should handle opts.hours = false', function()
        local cb_hours, cb_weekday, cb_project, cb_file
        local callback = function(h, wd, p, f)
            cb_hours, cb_weekday, cb_project, cb_file = h, wd, p, f
        end

        helper.input_mock:set_texts_to_return({ 'project_no_hours', 'file_no_hours' })
        helper.weekday_select_mock:set_selected_weekday('Tuesday')
        helper.select_mock:set_item_to_return('Tuesday') -- For vim.ui.select fallback

        time_ui.select({ hours = false }, callback) -- project, file, weekday default to true

        assert.are_equal('project_no_hours', cb_project)
        assert.are_equal('file_no_hours', cb_file)
        assert.are_equal('Tuesday', cb_weekday)
        assert.are_equal(0, cb_hours)
        assert.are_equal(
            2,
            helper.input_mock:get_call_count(),
            'vim.ui.input should be called twice for project and file'
        )
        assert.is_true(helper.weekday_select_mock:was_called_flag())
    end)

    it('should handle opts.weekday = false (and hours = true, causing warning)', function()
        local cb_called_with_data = false
        local callback = function(h, wd, p, f)
            -- This callback should ideally not be called with valid data if there's a prerequisite failure
            if h or wd or p or f then
                cb_called_with_data = true
            end
        end

        helper.input_mock:set_texts_to_return({ 'project_no_wd', 'file_no_wd' })
        -- No call to weekday_select_mock:set_selected_weekday needed
        -- No call to input_mock for hours needed if error happens before

        time_ui.select({ weekday = false, hours = true }, callback) -- project, file default to true

        assert.is_false(cb_called_with_data, 'Callback should not be called with data on warning')
        assert.is_true(helper.notify_mock:was_called_flag(), 'Notify should be called')
        assert.are_equal(
            'Weekday is required when hours are enabled.',
            helper.notify_mock:get_message()
        )
        assert.are_equal(vim.log.levels.WARN, helper.notify_mock:get_level())
        assert.is_false(
            helper.weekday_select_mock:was_called_flag(),
            'Weekday select should not be called'
        )
        -- Depending on implementation, input calls might be 2 (proj, file) then error, or fewer.
        -- The SUT (maorun/time/ui.lua) from previous step would call for project and file.
        assert.are_equal(
            2,
            helper.input_mock:get_call_count(),
            'Input should be called for project and file only'
        )
    end)

    it('should handle opts.weekday = false and opts.hours = false', function()
        local cb_hours, cb_weekday, cb_project, cb_file
        local callback = function(h, wd, p, f)
            cb_hours, cb_weekday, cb_project, cb_file = h, wd, p, f
        end

        helper.input_mock:set_texts_to_return({ 'project_no_wd_no_hr', 'file_no_wd_no_hr' })

        time_ui.select({ weekday = false, hours = false }, callback) -- project, file default to true

        assert.are_equal('project_no_wd_no_hr', cb_project)
        assert.are_equal('file_no_wd_no_hr', cb_file)
        assert.is_nil(cb_weekday)
        assert.are_equal(0, cb_hours)
        assert.is_false(
            helper.weekday_select_mock:was_called_flag(),
            'Weekday select should not be called'
        )
        assert.is_false(helper.notify_mock:was_called_flag(), 'Notify should not be called')
        assert.are_equal(2, helper.input_mock:get_call_count())
    end)

    it('should handle opts.project = false', function()
        local cb_hours, cb_weekday, cb_project, cb_file
        local callback = function(h, wd, p, f)
            cb_hours, cb_weekday, cb_project, cb_file = h, wd, p, f
        end

        helper.input_mock:set_texts_to_return({ 'file_no_proj', '7' }) -- For file and hours
        helper.weekday_select_mock:set_selected_weekday('Wednesday')
        helper.select_mock:set_item_to_return('Wednesday') -- For vim.ui.select fallback

        -- Assuming 'time_ui.default_project' exists or is handled by SUT
        local expected_project = (time_ui.default_project or 'default_project')
        time_ui.select({ project = false }, callback) -- file, weekday, hours default true

        assert.are_equal(expected_project, cb_project)
        assert.are_equal('file_no_proj', cb_file)
        assert.are_equal('Wednesday', cb_weekday)
        assert.are_equal(7, cb_hours)
        assert.are_equal(2, helper.input_mock:get_call_count()) -- file, hours
        assert.is_true(helper.weekday_select_mock:was_called_flag())
    end)

    it('should handle opts.file = false', function()
        local cb_hours, cb_weekday, cb_project, cb_file
        local callback = function(h, wd, p, f)
            cb_hours, cb_weekday, cb_project, cb_file = h, wd, p, f
        end

        helper.input_mock:set_texts_to_return({ 'project_no_file', '8' }) -- For project and hours
        helper.weekday_select_mock:set_selected_weekday('Thursday')
        helper.select_mock:set_item_to_return('Thursday') -- For vim.ui.select fallback

        local expected_file = (time_ui.default_file or 'default_file')
        time_ui.select({ file = false }, callback) -- project, weekday, hours default true

        assert.are_equal('project_no_file', cb_project)
        assert.are_equal(expected_file, cb_file)
        assert.are_equal('Thursday', cb_weekday)
        assert.are_equal(8, cb_hours)
        assert.are_equal(2, helper.input_mock:get_call_count()) -- project, hours
        assert.is_true(helper.weekday_select_mock:was_called_flag())
    end)

    it('should handle all options false', function()
        print('    RUNNING TEST: should handle all options false')
        local cb_hours, cb_weekday, cb_project, cb_file
        local callback = function(h, wd, p, f)
            print("    CALLBACK EXECUTED for 'all options false'")
            cb_hours, cb_weekday, cb_project, cb_file = h, wd, p, f
        end

        local expected_project = (time_ui.default_project or 'default_project')
        local expected_file = (time_ui.default_file or 'default_file')

        print("    CALLING time_ui.select for 'all options false'")
        time_ui.select({ project = false, file = false, weekday = false, hours = false }, callback)
        print("    RETURNED from time_ui.select for 'all options false'")

        assert.are_equal(expected_project, cb_project)
        assert.are_equal(expected_file, cb_file)
        assert.is_nil(cb_weekday)
        assert.are_equal(0, cb_hours)

        assert.are_equal(0, helper.input_mock:get_call_count(), 'vim.ui.input should not be called')
        assert.is_false(
            helper.weekday_select_mock:was_called_flag(),
            'Weekday select should not be called'
        )
        assert.is_false(helper.notify_mock:was_called_flag(), 'Notify should not be called')
        print("    ASSERTIONS COMPLETED for 'all options false'")
    end)

    describe('input validation for hours', function()
        local function test_invalid_hours(hours_input_val, test_label, expected_notify_msg)
            print('    SUB-TEST: ' .. test_label)
            local cb_called_with_data = false
            local callback = function(h, wd, p, f)
                if h or wd or p or f then
                    cb_called_with_data = true
                end
            end

            helper.input_mock:set_texts_to_return({ 'proj_val_hr', 'file_val_hr', hours_input_val })
            helper.weekday_select_mock:set_selected_weekday('Friday')
            helper.select_mock:set_item_to_return('Friday') -- For vim.ui.select fallback

            time_ui.select({ project = true, file = true, weekday = true, hours = true }, callback)

            assert.is_false(
                cb_called_with_data,
                'Callback should not be called with data on invalid hours for ' .. test_label
            )
            assert.is_true(
                helper.notify_mock:was_called_flag(),
                'Notify should be called for ' .. test_label
            )
            assert.are_equal(expected_notify_msg, helper.notify_mock:get_message())
            assert.are_equal(vim.log.levels.WARN, helper.notify_mock:get_level())
            assert.are_equal(
                3,
                helper.input_mock:get_call_count(),
                'Input should be called thrice for ' .. test_label
            )
            assert.is_true(
                helper.weekday_select_mock:was_called_flag(),
                'Weekday select should have been called before hours input for ' .. test_label
            )
        end

        local invalid_hours_msg = 'Invalid hours. Please enter a number between 0 and 24.'
        local cancelled_hours_msg = 'Hours input cancelled.' -- Or specific message from SUT

        it("should warn on invalid hours string 'invalid_input'", function()
            test_invalid_hours('invalid_input', 'string', invalid_hours_msg)
        end)
        it('should warn on nil hours input', function()
            test_invalid_hours(nil, 'nil', cancelled_hours_msg)
        end)
        it("should warn on empty string '' hours input", function()
            test_invalid_hours('', 'empty_string', cancelled_hours_msg)
        end)
        it('should warn on hours < 0', function()
            test_invalid_hours('-5', 'negative_hours', invalid_hours_msg)
        end)
        it('should warn on hours > 24', function()
            test_invalid_hours('25', 'too_many_hours', invalid_hours_msg)
        end)
    end)
end)

print('All tests described in test/ui_spec.lua. Helper module is now test/helper.lua.')
-- To actually run these, a Lua test runner would typically execute the file.
-- The print statements and pcall are for basic feedback in this environment.
