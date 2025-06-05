local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os') -- Use a different name to avoid conflict with global os

local tempPath

-- Store original os functions
local original_os_date = os_module.date
local original_os_time = os_module.time

before_each(function()
    tempPath = os_module.tmpname()
    -- Ensure the file is created for setup, similar to calculate_spec
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os_module.remove(tempPath)
    -- Restore original os functions
    os_module.date = original_os_date
    os_module.time = original_os_time
end)

describe('addTime', function()
    it('should add time to a specific weekday', function()
        -- Mock os.time and os.date
        local mock_specific_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_specific_time
        end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })
        local targetWeekday = 'Monday'
        local hoursToAdd = 2
        maorunTime.addTime({ time = hoursToAdd, weekday = targetWeekday })

        local expected_year_key = '2023'
        local expected_week_key = '11'
        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.are.same(
            hoursToAdd,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
        local endTimeTs =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].endTime
        local endTimeInfo = original_os_date('*t', endTimeTs) -- Use original_os_date for assertions
        assert.are.same(23, endTimeInfo.hour)
        assert.are.same(0, endTimeInfo.min)
        assert.are.same(0, endTimeInfo.sec)

        local startTimeTs =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].startTime
        assert.are.same(hoursToAdd * 3600, endTimeTs - startTimeTs)
    end)

    it('should handle floating point time addition', function()
        -- Mock os.time and os.date
        local mock_specific_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_specific_time
        end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })
        local targetWeekday = 'Tuesday'
        local hoursToAdd = 2.5
        maorunTime.addTime({ time = hoursToAdd, weekday = targetWeekday })

        local expected_year_key = '2023'
        local expected_week_key = '11'
        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.are.same(
            hoursToAdd,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
        local endTimeTs =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].endTime
        local endTimeInfo = original_os_date('*t', endTimeTs) -- Use original_os_date for assertions
        assert.are.same(23, endTimeInfo.hour)
        assert.are.same(0, endTimeInfo.min)
        assert.are.same(0, endTimeInfo.sec)

        local startTimeTs =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].startTime
        -- Using math.floor for comparison due to potential floating point inaccuracies with seconds
        assert.are.same(math.floor(hoursToAdd * 3600), math.floor(endTimeTs - startTimeTs))
    end)

    it('should add time to the current day if weekday is nil', function()
        -- Mock os.time and os.date
        local mock_specific_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_specific_time
        end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })
        local hoursToAdd = 3
        -- targetWeekday will be determined by the mocked time (Wednesday)
        local targetWeekday = original_os_date('%A', mock_specific_time)

        maorunTime.addTime({ time = hoursToAdd }) -- weekday = nil

        local expected_year_key = '2023'
        local expected_week_key = '11'
        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.are.same(
            hoursToAdd,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
        local endTimeTs =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].endTime
        local endTimeInfo = original_os_date('*t', endTimeTs) -- Use original_os_date for assertions
        assert.are.same(23, endTimeInfo.hour)
        assert.are.same(0, endTimeInfo.min)
        assert.are.same(0, endTimeInfo.sec)

        local startTimeTs =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].startTime
        assert.are.same(hoursToAdd * 3600, endTimeTs - startTimeTs)
    end)

    it('should add time correctly when tracking is paused', function()
        -- Mock os.time and os.date
        local mock_specific_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_specific_time
        end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })
        maorunTime.TimePause()
        assert.is_true(maorunTime.isPaused())

        local targetWeekday = 'Wednesday' -- Target day is Wednesday
        local hoursToAdd = 4
        maorunTime.addTime({ time = hoursToAdd, weekday = targetWeekday })

        local expected_year_key = '2023'
        local expected_week_key = '11'
        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.are.same(
            hoursToAdd,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
        assert.is_true(maorunTime.isPaused()) -- As per subtask description
    end)

    it('should add to existing entries, not overwrite by default', function()
        -- Mock os.time and os.date
        local mock_specific_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_specific_time
        end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })
        local targetWeekday = 'Thursday' -- Target day is Thursday
        local initialHours = 1
        local additionalHours = 2

        maorunTime.addTime({ time = initialHours, weekday = targetWeekday })
        -- No need to advance time here as the logic should place it on the same Thursday
        maorunTime.addTime({ time = additionalHours, weekday = targetWeekday })

        local expected_year_key = '2023'
        local expected_week_key = '11'
        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.are.same(
            2,
            #data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items
        )
        assert.are.same(
            initialHours,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
        assert.are.same(
            additionalHours,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[2].diffInHours
        )
    end)
end)
