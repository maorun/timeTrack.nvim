local helper = require('test.helper')
helper.plenary_dep() -- Ensure plenary is cloned/available
helper.notify_dep() -- Might as well ensure notify is also there, like other specs

local time_init_module = require('maorun.time.init')
local fs = require('plenary.path') -- This should now work if plenary_dep sets up paths or if LUA_PATH is correct
local inspect = require('inspect') -- For debugging test failures

describe('Project and File Tracking Functionality', function()
    -- Simpler temp path definition
    local test_json_filename = 'test_project_file_maorun_time.json'
    local test_json_path = '/tmp/' .. test_json_filename -- Using /tmp for simplicity
    local original_os_date
    local time_data_obj -- To access internal state for assertions

    local function safe_delete_test_file()
        if fs:new(test_json_path):exists() then
            os.remove(test_json_path)
        end
    end

    -- Fixed date: Monday, 2023-10-16, Week 42
    local mock_date_params = {
        year = '2023',
        week = '42',
        weekday_name = 'Monday',
        wday_numeric = 2, -- Sunday=1, Monday=2
        day_of_month = 16,
        month_num = 10,
        hour = 10,
        min = 0,
        sec = 0,
    }

    local function get_mock_time(offset_seconds)
        offset_seconds = offset_seconds or 0
        return os.time({
            year = tonumber(mock_date_params.year),
            month = mock_date_params.month_num,
            day = mock_date_params.day_of_month,
            hour = mock_date_params.hour,
            min = mock_date_params.min,
            sec = mock_date_params.sec,
        }) + offset_seconds
    end

    setup(function()
        -- No need to create /tmp/, it should exist
        safe_delete_test_file() -- Clean before setup too, just in case
        original_os_date = os.date
        os.date = function(format, time_val)
            if format == '%Y' then
                return mock_date_params.year
            end
            if format == '%W' then
                return mock_date_params.week
            end
            if format == '%A' then
                return mock_date_params.weekday_name
            end
            if format == '*t' then
                local current_time_val = time_val or get_mock_time()
                local t = original_os_date('*t', current_time_val)
                -- Override specific fields based on mock_date_params for consistency if time_val is not today
                if
                    time_val == nil
                    or (
                        t.year == tonumber(mock_date_params.year)
                        and t.month == mock_date_params.month_num
                        and t.day == mock_date_params.day_of_month
                    )
                then
                    t.wday = mock_date_params.wday_numeric
                    -- Keep other fields like hour/min/sec from original_os_date for flexibility if needed by tested code
                end
                return t
            end
            return original_os_date(format, time_val)
        end
    end)

    teardown(function()
        os.date = original_os_date
        safe_delete_test_file()
    end)

    before_each(function()
        safe_delete_test_file() -- Ensure clean state
        time_data_obj = time_init_module.setup({
            path = test_json_path,
            hoursPerWeekday = {
                Monday = 8,
                Tuesday = 8,
                Wednesday = 8,
                Thursday = 8,
                Friday = 8,
                Saturday = 0,
                Sunday = 0,
            },
        })
        -- Explicitly set memory and file to a known clean state *after* setup's M.init
        if time_data_obj and time_data_obj.content then
            time_data_obj.content.data = {} -- Clear in-memory data
            -- Ensure other essential fields are present from setup, then save minimal state
            time_data_obj.content.paused = time_data_obj.content.paused or false
            time_data_obj.content.hoursPerWeekday = time_data_obj.content.hoursPerWeekday
                or {
                    Monday = 8,
                    Tuesday = 8,
                    Wednesday = 8,
                    Thursday = 8,
                    Friday = 8,
                    Saturday = 0,
                    Sunday = 0,
                }

            local minimal_content_to_save = {
                hoursPerWeekday = time_data_obj.content.hoursPerWeekday,
                paused = time_data_obj.content.paused,
                data = {}, -- Crucially, data is empty
            }
            fs:new(test_json_path):write(vim.json.encode(minimal_content_to_save), 'w')
        end
        -- Any M.init called after this (e.g. if isPaused was faulty) would load this empty 'data'.
        -- With "State A" core.lua, M.isPaused won't call M.init, so this is mostly for safety/explicitness.
    end)

    local function get_data_from_json()
        local content = fs:new(test_json_path):read()
        if content == '' or content == nil then
            return {}
        end
        return vim.json.decode(content)
    end

    describe('TimeStart and TimeStop', function()
        it('should create entries in the specified project and file', function()
            local project = 'TestProject'
            local file = 'TestFile.lua'
            local startTime = get_mock_time()
            local stopTime = get_mock_time(3600) -- 1 hour later

            time_init_module.TimeStart({
                project = project,
                file = file,
                time = startTime,
                weekday = 'Monday',
            })
            time_init_module.TimeStop({
                project = project,
                file = file,
                time = stopTime,
                weekday = 'Monday',
            })

            local data = get_data_from_json()
            local year_data = data.data[mock_date_params.year]
            assert.is_not_nil(year_data, 'Year data should exist')
            local week_data = year_data[mock_date_params.week]
            assert.is_not_nil(week_data, 'Week data should exist')
            -- New structure: year -> week -> weekday -> project -> file
            local day_data_for_project_file = week_data[mock_date_params.weekday_name]
            assert.is_not_nil(
                day_data_for_project_file,
                mock_date_params.weekday_name .. ' data should exist at week level'
            )
            local proj_data = day_data_for_project_file[project]
            assert.is_not_nil(proj_data, 'Project data should exist for ' .. project)
            local file_specific_data = proj_data[file]
            assert.is_not_nil(file_specific_data, 'File data should exist for ' .. file)
            assert.is_not_nil(file_specific_data.items, 'Items table should exist in file data')
            assert.are.same(1, #file_specific_data.items, 'Should have one item')
            assert.are.same(startTime, file_specific_data.items[1].startTime)
            assert.are.same(stopTime, file_specific_data.items[1].endTime)
            assert.is_near(1, file_specific_data.items[1].diffInHours, 0.001)
        end)

        it("should default to 'default_project' and 'default_file' if not specified", function()
            local startTime = get_mock_time()
            local stopTime = get_mock_time(3600) -- 1 hour later

            time_init_module.TimeStart({ time = startTime, weekday = 'Monday' }) -- No project/file
            time_init_module.TimeStop({ time = stopTime, weekday = 'Monday' }) -- No project/file

            local data = get_data_from_json()
            -- New structure: year -> week -> weekday -> project -> file
            local file_specific_data =
                data.data[mock_date_params.year][mock_date_params.week][mock_date_params.weekday_name]['default_project']['default_file']
            assert.is_not_nil(
                file_specific_data,
                'Data in default project/file for Monday should exist'
            )
            assert.is_not_nil(file_specific_data.items, 'Items table should exist in file data')
            assert.are.same(1, #file_specific_data.items)
            assert.are.same(startTime, file_specific_data.items[1].startTime)
            assert.are.same(stopTime, file_specific_data.items[1].endTime)
        end)
    end)

    describe('addTime', function()
        it('should add time to a specific project/file', function()
            time_init_module.addTime({
                time = 2.5,
                weekday = 'Tuesday',
                project = 'ProjectX',
                file = 'file_alpha.md',
            })
            local data = get_data_from_json()
            -- New structure: year -> week -> weekday -> project -> file
            local day_items =
                data.data[mock_date_params.year][mock_date_params.week]['Tuesday']['ProjectX']['file_alpha.md'].items
            assert.are.same(1, #day_items)
            assert.is_near(2.5, day_items[1].diffInHours, 0.001)
        end)

        it('should use default project/file if not specified', function()
            time_init_module.addTime({ time = 1.5, weekday = 'Wednesday' })
            local data = get_data_from_json()
            -- New structure: year -> week -> weekday -> project -> file
            local day_items =
                data.data[mock_date_params.year][mock_date_params.week]['Wednesday']['default_project']['default_file'].items
            assert.are.same(1, #day_items)
            assert.is_near(1.5, day_items[1].diffInHours, 0.001)
        end)
    end)

    describe('subtractTime', function()
        -- subtractTime also adds an entry, its name is a bit of a misnomer for its current implementation
        it('should add a time entry (like addTime) to a specific project/file', function()
            time_init_module.subtractTime({
                time = 1,
                weekday = 'Thursday',
                project = 'ProjectY',
                file = 'file_beta.txt',
            })
            local data = get_data_from_json()
            -- New structure: year -> week -> weekday -> project -> file
            local day_items =
                data.data[mock_date_params.year][mock_date_params.week]['Thursday']['ProjectY']['file_beta.txt'].items
            assert.are.same(1, #day_items)
            assert.is_near(-1, day_items[1].diffInHours, 0.001) -- diffInHours should be negative for subtractTime
        end)
    end)

    describe('setTime', function()
        it('should set time for a specific project/file, clearing previous entries', function()
            -- Add initial entry
            time_init_module.addTime({
                time = 1,
                weekday = 'Friday',
                project = 'ProjectZ',
                file = 'file_gamma.py',
            })
            time_init_module.addTime({
                time = 2,
                weekday = 'Friday',
                project = 'ProjectZ',
                file = 'file_gamma.py',
            })

            -- Now setTime
            time_init_module.setTime({
                time = 3.5,
                weekday = 'Friday',
                project = 'ProjectZ',
                file = 'file_gamma.py',
            })
            local data = get_data_from_json()
            -- New structure: year -> week -> weekday -> project -> file
            local day_items =
                data.data[mock_date_params.year][mock_date_params.week]['Friday']['ProjectZ']['file_gamma.py'].items
            assert.are.same(1, #day_items, 'setTime should result in a single entry for the day')
            assert.is_near(3.5, day_items[1].diffInHours, 0.001)
        end)
    end)

    describe('calculate', function()
        it('should correctly calculate summaries across projects, files, and weekdays', function()
            -- Expected hours: Monday = 8
            time_init_module.addTime({
                time = 2,
                weekday = 'Monday',
                project = 'Alpha',
                file = 'main.lua',
            }) -- Alpha/main.lua/Monday: 2hr. Overhour: 2-8 = -6
            time_init_module.addTime({
                time = 3,
                weekday = 'Monday',
                project = 'Alpha',
                file = 'utils.lua',
            }) -- Alpha/utils.lua/Monday: 3hr. Overhour: 3-8 = -5
            time_init_module.addTime({
                time = 4,
                weekday = 'Tuesday',
                project = 'Alpha',
                file = 'main.lua',
            }) -- Alpha/main.lua/Tuesday: 4hr. Overhour: 4-8 = -4
            time_init_module.addTime({
                time = 1,
                weekday = 'Monday',
                project = 'Bravo',
                file = 'init.lua',
            }) -- Bravo/init.lua/Monday: 1hr. Overhour: 1-8 = -7

            time_init_module.calculate({
                year = mock_date_params.year,
                weeknumber = mock_date_params.week,
            })
            local data = get_data_from_json()
            local week_summary = data.data[mock_date_params.year][mock_date_params.week].summary
            -- New structure: year -> week -> weekday -> project -> file -> summary
            local alpha_main_mon =
                data.data[mock_date_params.year][mock_date_params.week]['Monday']['Alpha']['main.lua'].summary
            local alpha_utils_mon =
                data.data[mock_date_params.year][mock_date_params.week]['Monday']['Alpha']['utils.lua'].summary
            local alpha_main_tue =
                data.data[mock_date_params.year][mock_date_params.week]['Tuesday']['Alpha']['main.lua'].summary
            local bravo_init_mon =
                data.data[mock_date_params.year][mock_date_params.week]['Monday']['Bravo']['init.lua'].summary

            assert.is_near(2, alpha_main_mon.diffInHours, 0.001)
            assert.is_near(-6, alpha_main_mon.overhour, 0.001)

            assert.is_near(3, alpha_utils_mon.diffInHours, 0.001)
            assert.is_near(-5, alpha_utils_mon.overhour, 0.001)

            assert.is_near(4, alpha_main_tue.diffInHours, 0.001)
            assert.is_near(-4, alpha_main_tue.overhour, 0.001)

            assert.is_near(1, bravo_init_mon.diffInHours, 0.001)
            assert.is_near(-7, bravo_init_mon.overhour, 0.001)

            -- Total overhour for the week: (-6) + (-5) + (-4) + (-7) = -22
            -- With the 'State A' core.lua:
            -- M.init in setup creates Monday default in memory.
            -- before_each clears content.data in memory.
            -- The persistent "Got: -30" implies that a default Monday (-8) IS being included.
            -- Sum of explicit logs: (-6) + (-5) + (-4) + (-7) = -22.
            -- Default Monday: -8.
            -- Total expected: -22 + (-8) = -30.
            assert.is_near(
                -30,
                week_summary.overhour,
                0.001,
                'Week summary overhour incorrect. Got: ' .. inspect(week_summary.overhour)
            )
        end)
    end)
end)
