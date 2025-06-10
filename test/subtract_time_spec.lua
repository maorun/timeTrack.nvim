local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os = require('os')
local Path = require('plenary.path') -- Added for file manipulation
local tempPath

-- Store original os functions
local original_os_date = os.date
local original_os_time = os.time

-- Copied from lua/maorun/time/init.lua for test purposes
local wdayToEngName = {
    [1] = 'Sunday',
    [2] = 'Monday',
    [3] = 'Tuesday',
    [4] = 'Wednesday',
    [5] = 'Thursday',
    [6] = 'Friday',
    [7] = 'Saturday',
}

before_each(function()
    tempPath = os.tmpname()
    -- Default setup, tests can override if specific hoursPerWeekday are needed
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os.remove(tempPath)
    -- Restore original os functions
    os.date = original_os_date
    os.time = original_os_time
end)

describe('subtractTime', function()
    it('should subtract a whole number of hours from a specific weekday', function()
        local mock_context_ts = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_context_ts
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_context_ts
            return original_os_date(format, time_val)
        end

        local weekday = 'Monday'
        local hoursToSubtract = 3
        local defaultHoursForMonday = 8 -- Assuming default config

        maorunTime.subtractTime({ time = hoursToSubtract, weekday = weekday })

        local expected_year_key = '2023'
        local expected_week_key = '11' -- Monday, Mar 13 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'],
            'Weekday data should exist'
        )
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'Items should exist'
        )
        assert.are.same(
            1,
            #data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'One item should be created'
        )

        local item =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items[1]
        assert(
            math.abs(item.diffInHours - -hoursToSubtract) < 0.001,
            'diffInHours should be approximately ' .. -hoursToSubtract
        )

        local weekdaySummary =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(weekdaySummary.diffInHours - -hoursToSubtract) < 0.001,
            'Weekday summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(weekdaySummary.overhour - (-hoursToSubtract - defaultHoursForMonday)) < 0.001,
            'Weekday summary overhour should be ' .. (-hoursToSubtract - defaultHoursForMonday)
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        assert(
            math.abs(weekSummary.overhour - (-hoursToSubtract - defaultHoursForMonday)) < 0.001,
            'Week summary overhour should be ' .. (-hoursToSubtract - defaultHoursForMonday)
        )
    end)

    it('should subtract fractional hours from a specific weekday', function()
        local mock_context_ts = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_context_ts
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_context_ts
            return original_os_date(format, time_val)
        end

        local weekday = 'Tuesday'
        local hoursToSubtract = 2.5
        local defaultHoursForTuesday = 8 -- Assuming default config

        maorunTime.subtractTime({ time = hoursToSubtract, weekday = weekday })

        local expected_year_key = '2023'
        local expected_week_key = '11' -- Tuesday, Mar 14 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'Items should exist for Tuesday'
        )
        assert.are.same(
            1,
            #data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'One item should be created for Tuesday'
        )

        local item =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items[1]
        assert(
            math.abs(item.diffInHours - -hoursToSubtract) < 0.001,
            'diffInHours for Tuesday should be approximately ' .. -hoursToSubtract
        )

        local weekdaySummary =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(weekdaySummary.diffInHours - -hoursToSubtract) < 0.001,
            'Tuesday summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(weekdaySummary.overhour - (-hoursToSubtract - defaultHoursForTuesday)) < 0.001,
            'Tuesday summary overhour should be ' .. (-hoursToSubtract - defaultHoursForTuesday)
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        assert(
            math.abs(weekSummary.overhour - (-hoursToSubtract - defaultHoursForTuesday)) < 0.001,
            'Week summary overhour should reflect Tuesday subtraction'
        )
    end)

    it('should subtract time from the current day if weekday is not provided', function()
        local mock_context_ts = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_context_ts
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_context_ts
            return original_os_date(format, time_val)
        end

        local hoursToSubtract = 1.5
        local currentWeekday = original_os_date('%A', mock_context_ts) -- Should be 'Wednesday'
        local setup_content = maorunTime.setup({ path = tempPath }) -- Ensure setup is called to get hoursPerWeekday
        local defaultHoursForCurrentDay = setup_content.content.hoursPerWeekday[currentWeekday]

        maorunTime.subtractTime({ time = hoursToSubtract }) -- No weekday argument

        local expected_year_key = '2023'
        local expected_week_key = '11' -- Wednesday, Mar 15 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][currentWeekday]['default_project']['default_file'].items,
            'Items should exist for current day'
        )
        assert.are.same(
            1,
            #data.content.data[expected_year_key][expected_week_key][currentWeekday]['default_project']['default_file'].items,
            'One item should be created for current day'
        )

        local item =
            data.content.data[expected_year_key][expected_week_key][currentWeekday]['default_project']['default_file'].items[1]
        assert(
            math.abs(item.diffInHours - -hoursToSubtract) < 0.001,
            'diffInHours for current day should be approximately ' .. -hoursToSubtract
        )

        local weekdaySummary =
            data.content.data[expected_year_key][expected_week_key][currentWeekday]['default_project']['default_file'].summary
        assert(
            math.abs(weekdaySummary.diffInHours - -hoursToSubtract) < 0.001,
            'Current day summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(weekdaySummary.overhour - (-hoursToSubtract - defaultHoursForCurrentDay))
                < 0.001,
            'Current day summary overhour calculation'
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        assert(
            math.abs(weekSummary.overhour - (-hoursToSubtract - defaultHoursForCurrentDay)) < 0.001,
            'Week summary overhour should reflect current day subtraction'
        )
    end)

    it('should correctly subtract time from a day with no prior entries', function()
        local mock_context_ts = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_context_ts
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_context_ts
            return original_os_date(format, time_val)
        end

        local weekday = 'Wednesday'
        local hoursToSubtract = 4
        local defaultHoursForWednesday = 8 -- Assuming default config

        maorunTime.subtractTime({ time = hoursToSubtract, weekday = weekday })

        local expected_year_key = '2023'
        local expected_week_key = '11' -- Wednesday, Mar 15 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'Items should exist for Wednesday'
        )
        assert.are.same(
            1,
            #data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'One item should be created for Wednesday'
        )

        local item =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items[1]
        assert(
            math.abs(item.diffInHours - -hoursToSubtract) < 0.001,
            'diffInHours for Wednesday should be approximately ' .. -hoursToSubtract
        )

        local weekdaySummary =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(weekdaySummary.diffInHours - -hoursToSubtract) < 0.001,
            'Wednesday summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(weekdaySummary.overhour - (-hoursToSubtract - defaultHoursForWednesday))
                < 0.001,
            'Wednesday summary overhour calculation'
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        assert(
            math.abs(weekSummary.overhour - (-hoursToSubtract - defaultHoursForWednesday)) < 0.001,
            'Week summary overhour should reflect Wednesday subtraction'
        )
    end)

    it('should correctly update summaries after subtraction and recalculation', function()
        local mock_context_ts = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_context_ts
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_context_ts
            return original_os_date(format, time_val)
        end

        local weekday = 'Thursday'
        local initialHours = 5
        local hoursToSubtract = 2
        local defaultHoursForThursday = 8 -- Assuming default config

        maorunTime.addTime({ time = initialHours, weekday = weekday })
        maorunTime.subtractTime({ time = hoursToSubtract, weekday = weekday })

        local expected_year_key = '2023'
        local expected_week_key = '11' -- Thursday, Mar 16 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'Items should exist for Thursday'
        )
        assert.are.same(
            2,
            #data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'Two items should exist for Thursday (add and subtract)'
        )

        local totalDiffInHours = initialHours - hoursToSubtract
        local weekdaySummary =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(weekdaySummary.diffInHours - totalDiffInHours) < 0.001,
            'Thursday summary diffInHours should be ' .. totalDiffInHours
        )
        assert(
            math.abs(weekdaySummary.overhour - (totalDiffInHours - defaultHoursForThursday)) < 0.001,
            'Thursday summary overhour should be ' .. (totalDiffInHours - defaultHoursForThursday)
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        assert(
            math.abs(weekSummary.overhour - (totalDiffInHours - defaultHoursForThursday)) < 0.001,
            'Week summary overhour should reflect combined Thursday operations'
        )
    end)

    it('should function correctly when time tracking is paused and resumed', function()
        local mock_context_ts = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_context_ts
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_context_ts
            return original_os_date(format, time_val)
        end

        local weekday = 'Friday'
        local hoursToSubtract = 1
        local defaultHoursForFriday = 8 -- Assuming default config

        maorunTime.TimePause()
        assert.is_true(maorunTime.isPaused(), 'Time tracking should be paused')

        maorunTime.subtractTime({ time = hoursToSubtract, weekday = weekday })

        maorunTime.TimeResume()
        assert.is_false(maorunTime.isPaused(), 'Time tracking should be resumed')

        local expected_year_key = '2023'
        local expected_week_key = '11' -- Friday, Mar 17 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        -- Check file content for paused state (optional, as isPaused() checks internal state)
        local file_content_raw = Path:new(tempPath):read()
        local file_content = vim.json.decode(file_content_raw)
        assert.is_false(
            file_content.paused,
            'Paused state in data file should be false after resume'
        )

        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'Items should exist for Friday'
        )
        assert.are.same(
            1,
            #data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items,
            'One item should be created for Friday despite pause/resume'
        )

        local item =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].items[1]
        assert(
            math.abs(item.diffInHours - -hoursToSubtract) < 0.001,
            'diffInHours for Friday should be approximately ' .. -hoursToSubtract
        )

        local weekdaySummary =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(weekdaySummary.diffInHours - -hoursToSubtract) < 0.001,
            'Friday summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(weekdaySummary.overhour - (-hoursToSubtract - defaultHoursForFriday)) < 0.001,
            'Friday summary overhour calculation'
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        assert(
            math.abs(weekSummary.overhour - (-hoursToSubtract - defaultHoursForFriday)) < 0.001,
            'Week summary overhour should reflect Friday subtraction'
        )
    end)
end)
