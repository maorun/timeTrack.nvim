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
    tempPath = vim.fn.tempname()
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

        -- File Summary
        local fileSummary =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(fileSummary.diffInHours - -hoursToSubtract) < 0.001,
            'File summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert.is_nil(fileSummary.overhour, 'File summary overhour should be nil')

        -- Weekday Summary (actual day summary)
        local daySummary = data.content.data[expected_year_key][expected_week_key][weekday].summary
        assert.is_not_nil(daySummary, 'Day summary for ' .. weekday .. ' should exist')
        assert(
            math.abs(daySummary.diffInHours - -hoursToSubtract) < 0.001,
            'Day summary diffInHours should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(daySummary.overhour - (-hoursToSubtract - defaultHoursForMonday)) < 0.001,
            'Day summary overhour should be ' .. (-hoursToSubtract - defaultHoursForMonday)
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        -- Monday: (-3) - 8 = -11. No auto-init Wednesday in this calculate context.
        local expectedWeekOverhour = (-hoursToSubtract - defaultHoursForMonday) -- Was: (-hoursToSubtract - defaultHoursForMonday) - 8
        assert(
            math.abs(weekSummary.overhour - expectedWeekOverhour) < 0.001,
            'Week summary overhour should be '
                .. expectedWeekOverhour
                .. '. Got: '
                .. weekSummary.overhour
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

        -- File Summary
        local fileSummaryTuesday =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(fileSummaryTuesday.diffInHours - -hoursToSubtract) < 0.001,
            'File summary diffInHours for Tuesday should be approximately ' .. -hoursToSubtract
        )
        assert.is_nil(
            fileSummaryTuesday.overhour,
            'File summary overhour for Tuesday should be nil'
        )

        -- Weekday Summary (actual day summary)
        local daySummaryTuesday =
            data.content.data[expected_year_key][expected_week_key][weekday].summary
        assert.is_not_nil(daySummaryTuesday, 'Day summary for ' .. weekday .. ' should exist')
        assert(
            math.abs(daySummaryTuesday.diffInHours - -hoursToSubtract) < 0.001,
            'Day summary diffInHours for Tuesday should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(daySummaryTuesday.overhour - (-hoursToSubtract - defaultHoursForTuesday))
                < 0.001,
            'Day summary overhour for Tuesday should be '
                .. (-hoursToSubtract - defaultHoursForTuesday)
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        -- Tuesday: (-2.5) - 8 = -10.5. No auto-init Wednesday.
        local expectedWeekOverhour = (-hoursToSubtract - defaultHoursForTuesday) -- Was: (-hoursToSubtract - defaultHoursForTuesday) - 8
        assert(
            math.abs(weekSummary.overhour - expectedWeekOverhour) < 0.001,
            'Week summary overhour should reflect Tuesday subtraction. Expected: '
                .. expectedWeekOverhour
                .. '. Got: '
                .. weekSummary.overhour
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

        -- File Summary
        local fileSummaryCurrentDay =
            data.content.data[expected_year_key][expected_week_key][currentWeekday]['default_project']['default_file'].summary
        assert(
            math.abs(fileSummaryCurrentDay.diffInHours - -hoursToSubtract) < 0.001,
            'File summary diffInHours for current day should be approximately ' .. -hoursToSubtract
        )
        assert.is_nil(
            fileSummaryCurrentDay.overhour,
            'File summary overhour for current day should be nil'
        )

        -- Weekday Summary (actual day summary)
        local daySummaryCurrentDay =
            data.content.data[expected_year_key][expected_week_key][currentWeekday].summary
        assert.is_not_nil(
            daySummaryCurrentDay,
            'Day summary for ' .. currentWeekday .. ' should exist'
        )
        assert(
            math.abs(daySummaryCurrentDay.diffInHours - -hoursToSubtract) < 0.001,
            'Day summary diffInHours for current day should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(daySummaryCurrentDay.overhour - (-hoursToSubtract - defaultHoursForCurrentDay))
                < 0.001,
            'Day summary overhour for current day calculation'
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

        -- File Summary
        local fileSummaryWednesday =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(fileSummaryWednesday.diffInHours - -hoursToSubtract) < 0.001,
            'File summary diffInHours for Wednesday should be approximately ' .. -hoursToSubtract
        )
        assert.is_nil(
            fileSummaryWednesday.overhour,
            'File summary overhour for Wednesday should be nil'
        )

        -- Weekday Summary (actual day summary)
        local daySummaryWednesday =
            data.content.data[expected_year_key][expected_week_key][weekday].summary
        assert.is_not_nil(daySummaryWednesday, 'Day summary for ' .. weekday .. ' should exist')
        assert(
            math.abs(daySummaryWednesday.diffInHours - -hoursToSubtract) < 0.001,
            'Day summary diffInHours for Wednesday should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(daySummaryWednesday.overhour - (-hoursToSubtract - defaultHoursForWednesday))
                < 0.001,
            'Day summary overhour for Wednesday calculation'
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
        -- File Summary
        local fileSummaryThursday =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(fileSummaryThursday.diffInHours - totalDiffInHours) < 0.001, -- This now reflects sum of items in file
            'File summary diffInHours for Thursday should be ' .. totalDiffInHours
        )
        assert.is_nil(
            fileSummaryThursday.overhour,
            'File summary overhour for Thursday should be nil'
        )

        -- Weekday Summary (actual day summary)
        local daySummaryThursday =
            data.content.data[expected_year_key][expected_week_key][weekday].summary
        assert.is_not_nil(daySummaryThursday, 'Day summary for ' .. weekday .. ' should exist')
        assert(
            math.abs(daySummaryThursday.diffInHours - totalDiffInHours) < 0.001,
            'Day summary diffInHours for Thursday should be ' .. totalDiffInHours
        )
        assert(
            math.abs(daySummaryThursday.overhour - (totalDiffInHours - defaultHoursForThursday))
                < 0.001,
            'Day summary overhour for Thursday should be '
                .. (totalDiffInHours - defaultHoursForThursday)
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        -- Thursday: (5-2) - 8 = -5. No auto-init Wednesday.
        local expectedWeekOverhour = (totalDiffInHours - defaultHoursForThursday) -- Was: (totalDiffInHours - defaultHoursForThursday) - 8
        assert(
            math.abs(weekSummary.overhour - expectedWeekOverhour) < 0.001,
            'Week summary overhour should reflect combined Thursday operations. Expected: '
                .. expectedWeekOverhour
                .. '. Got: '
                .. weekSummary.overhour
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

        -- File Summary
        local fileSummaryFriday =
            data.content.data[expected_year_key][expected_week_key][weekday]['default_project']['default_file'].summary
        assert(
            math.abs(fileSummaryFriday.diffInHours - -hoursToSubtract) < 0.001,
            'File summary diffInHours for Friday should be approximately ' .. -hoursToSubtract
        )
        assert.is_nil(fileSummaryFriday.overhour, 'File summary overhour for Friday should be nil')

        -- Weekday Summary (actual day summary)
        local daySummaryFriday =
            data.content.data[expected_year_key][expected_week_key][weekday].summary
        assert.is_not_nil(daySummaryFriday, 'Day summary for ' .. weekday .. ' should exist')
        assert(
            math.abs(daySummaryFriday.diffInHours - -hoursToSubtract) < 0.001,
            'Day summary diffInHours for Friday should be approximately ' .. -hoursToSubtract
        )
        assert(
            math.abs(daySummaryFriday.overhour - (-hoursToSubtract - defaultHoursForFriday)) < 0.001,
            'Day summary overhour for Friday calculation'
        )

        local weekSummary = data.content.data[expected_year_key][expected_week_key].summary
        -- Friday: (-1 logged - 8 expected) = -9.
        -- Auto-initialized Wednesday (by setup in before_each): (0 logged - 8 expected) = -8.
        -- Total = -9 - 8 = -17.
        local expectedWeekOverhour = (-hoursToSubtract - defaultHoursForFriday) - 8
        assert(
            math.abs(weekSummary.overhour - expectedWeekOverhour) < 0.001,
            'Week summary overhour should reflect Friday subtraction. Expected: '
                .. expectedWeekOverhour
                .. '. Got: '
                .. weekSummary.overhour
        )
    end)
end)
