local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()
local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os')

local tempPath

-- Store original os functions
local original_os_date = os_module.date
local original_os_time = os_module.time

before_each(function()
    tempPath = os_module.tmpname()
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os_module.remove(tempPath)
    -- Restore original os functions
    os_module.date = original_os_date
    os_module.time = original_os_time
end)

describe('saveTime', function()
    it('should correctly save a time entry via addTime', function()
        local mock_specific_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os_module.time = function() return mock_specific_time end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        local year = "2023"
        local week_number_str = "11" -- Monday, Mar 13 is in week 11
        local weekday = 'Monday'
        local hours_to_add = 2

        maorunTime.addTime({ time = hours_to_add, weekday = weekday })

        local data = maorunTime.calculate({ year = year, weeknumber = week_number_str })
        local item =
            data.content.data[year][week_number_str]['default_project']['default_file'].weekdays[weekday].items[1]

        assert.is_not_nil(item, 'Item should be saved')
        assert.are.same(hours_to_add, item.diffInHours)

        local expected_start_time = item.endTime - (hours_to_add * 3600)
        assert.are.same(expected_start_time, item.startTime)

        -- Use original_os_date for formatting assertion values
        local start_readable_expected = original_os_date('%H:%M', expected_start_time)
        local end_readable_expected = original_os_date('%H:%M', item.endTime)

        assert.are.same(start_readable_expected, item.startReadable)
        assert.are.same(end_readable_expected, item.endReadable)
    end)

    it('should append multiple time entries for the same day via multiple addTime calls', function()
        local mock_specific_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os_module.time = function() return mock_specific_time end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        local weekday = 'Tuesday'
        local hours_to_add1 = 3
        local hours_to_add2 = 2.5

        maorunTime.addTime({ time = hours_to_add1, weekday = weekday })
        maorunTime.addTime({ time = hours_to_add2, weekday = weekday })

        local expected_year_key = "2023"
        local expected_week_key = "11" -- Tuesday, Mar 14 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local items =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items

        assert.are.same(2, #items, 'Should have two items for the weekday')
        assert.are.same(hours_to_add1, items[1].diffInHours)
        assert.are.same(hours_to_add2, items[2].diffInHours)
    end)

    it('should correctly calculate diffInHours (positive)', function()
        local mock_specific_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os_module.time = function() return mock_specific_time end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        local weekday = 'Wednesday'
        local hours_duration = 3.5
        maorunTime.addTime({ time = hours_duration, weekday = weekday })

        local expected_year_key = "2023"
        local expected_week_key = "11" -- Wednesday, Mar 15 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local item =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items[1]
        assert.are.same(hours_duration, item.diffInHours)
    end)

    it('should correctly save readable time formats (HH:MM)', function()
        local mock_specific_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os_module.time = function() return mock_specific_time end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        local weekday = 'Thursday'
        local hours_to_add = 1

        maorunTime.addTime({ time = hours_to_add, weekday = weekday })

        local expected_year_key = "2023"
        local expected_week_key = "11" -- Thursday, Mar 16 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local item =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items[1]

        assert.is_not_nil(item.startTime, 'startTime should be set')
        assert.is_not_nil(item.endTime, 'endTime should be set')

        -- Use original_os_date for formatting assertion values
        local start_t_info = original_os_date('*t', item.startTime)
        local end_t_info = original_os_date('*t', item.endTime)

        local expected_start_readable =
            string.format('%02d:%02d', start_t_info.hour, start_t_info.min)
        local expected_end_readable = string.format('%02d:%02d', end_t_info.hour, end_t_info.min)

        assert.are.same(
            expected_start_readable,
            item.startReadable,
            'startReadable format should be HH:MM'
        )
        assert.are.same(
            expected_end_readable,
            item.endReadable,
            'endReadable format should be HH:MM'
        )
        assert.are.same(hours_to_add, item.diffInHours)
    end)

    it('should correctly save a time entry with negative diffInHours via subtractTime', function()
        local mock_specific_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os_module.time = function() return mock_specific_time end
        os_module.date = function(format, time_val)
            time_val = time_val or mock_specific_time
            return original_os_date(format, time_val)
        end

        local weekday = 'Friday'
        local hours_to_subtract = 2

        maorunTime.subtractTime({ time = hours_to_subtract, weekday = weekday })

        local expected_year_key = "2023"
        local expected_week_key = "11" -- Friday, Mar 17 is in week 11

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local item =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items[1]

        assert.is_not_nil(item, 'Item should be saved')
        assert.are.same(-hours_to_subtract, item.diffInHours)

        local expected_end_time = item.startTime - (hours_to_subtract * 3600)
        assert.are.same(expected_end_time, item.endTime)

        -- Use original_os_date for formatting assertion values
        local start_readable_expected = original_os_date('%H:%M', item.startTime)
        local end_readable_expected = original_os_date('%H:%M', item.endTime)

        assert.are.same(start_readable_expected, item.startReadable)
        assert.are.same(end_readable_expected, item.endReadable)
    end)
end)
