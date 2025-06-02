local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()
local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os')

local tempPath

before_each(function()
    tempPath = os_module.tmpname()
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os_module.remove(tempPath)
end)

describe('saveTime', function()
    -- Note: os_module.date('%W') gives week number, os_module.date('%A') gives weekday name
    -- Note: saveTime is local, so we test its effects through exported functions like addTime.

    it('should correctly save a time entry via addTime', function()
        -- maorunTime.setup({ path = tempPath }) -- Already in before_each
        local year = os_module.date('%Y')
        local week_number_str = os_module.date('%W') -- Ensure week number is a string for table keys
        local weekday = 'Monday'
        local hours_to_add = 2

        -- addTime will call saveTime internally
        maorunTime.addTime({ time = hours_to_add, weekday = weekday })

        local data = maorunTime.calculate({ year = year, weeknumber = week_number_str })
        local item =
            data.content.data[year][week_number_str]['default_project']['default_file'].weekdays[weekday].items[1]

        assert.is_not_nil(item, 'Item should be saved')
        assert.are.same(hours_to_add, item.diffInHours)

        local expected_start_time = item.endTime - (hours_to_add * 3600)
        assert.are.same(expected_start_time, item.startTime)

        local start_readable_expected = os_module.date('%H:%M', expected_start_time)
        local end_readable_expected = os_module.date('%H:%M', item.endTime)

        assert.are.same(start_readable_expected, item.startReadable)
        assert.are.same(end_readable_expected, item.endReadable)
    end)

    it('should append multiple time entries for the same day via multiple addTime calls', function()
        -- maorunTime.setup({ path = tempPath }) -- Already in before_each
        local weekday = 'Tuesday'
        local hours_to_add1 = 3
        local hours_to_add2 = 2.5

        maorunTime.addTime({ time = hours_to_add1, weekday = weekday })
        maorunTime.addTime({ time = hours_to_add2, weekday = weekday })

        -- Calculate the year and week that addTime would have used for weekday
        local current_ts_for_test = os_module.time()
        local currentWeekdayNumeric_for_test = os_module.date('*t', current_ts_for_test).wday - 1
        local targetWeekdayNumeric_for_test = maorunTime.weekdays[weekday]
        local diffDays_for_test = currentWeekdayNumeric_for_test - targetWeekdayNumeric_for_test
        if diffDays_for_test < 0 then
            diffDays_for_test = diffDays_for_test + 7
        end
        local target_day_ref_ts_for_test = current_ts_for_test - (diffDays_for_test * 24 * 3600)

        local expected_year_key = os_module.date('%Y', target_day_ref_ts_for_test)
        local expected_week_key = os_module.date('%W', target_day_ref_ts_for_test)

        local data = maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local items =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items

        assert.are.same(2, #items, 'Should have two items for the weekday')
        assert.are.same(hours_to_add1, items[1].diffInHours)
        assert.are.same(hours_to_add2, items[2].diffInHours)
    end)

    it('should correctly calculate diffInHours (positive)', function()
        -- maorunTime.setup({ path = tempPath }) -- Already in before_each
        local weekday = 'Wednesday'
        -- Let addTime determine startTime and endTime based on 23:00 end time.
        local hours_duration = 3.5
        maorunTime.addTime({ time = hours_duration, weekday = weekday })

        -- Calculate the year and week that addTime would have used for weekday
        local current_ts_for_test = os_module.time()
        local currentWeekdayNumeric_for_test = os_module.date('*t', current_ts_for_test).wday - 1
        local targetWeekdayNumeric_for_test = maorunTime.weekdays[weekday]
        local diffDays_for_test = currentWeekdayNumeric_for_test - targetWeekdayNumeric_for_test
        if diffDays_for_test < 0 then
            diffDays_for_test = diffDays_for_test + 7
        end
        local target_day_ref_ts_for_test = current_ts_for_test - (diffDays_for_test * 24 * 3600)

        local expected_year_key = os_module.date('%Y', target_day_ref_ts_for_test)
        local expected_week_key = os_module.date('%W', target_day_ref_ts_for_test)

        local data = maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local item =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items[1]
        assert.are.same(hours_duration, item.diffInHours)
    end)

    it('should correctly save readable time formats (HH:MM)', function()
        -- maorunTime.setup({ path = tempPath }) -- Already in before_each
        local weekday = 'Thursday'
        local hours_to_add = 1

        maorunTime.addTime({ time = hours_to_add, weekday = weekday })

        -- Calculate the year and week that addTime would have used for weekday
        local current_ts_for_test = os_module.time()
        local currentWeekdayNumeric_for_test = os_module.date('*t', current_ts_for_test).wday - 1
        local targetWeekdayNumeric_for_test = maorunTime.weekdays[weekday]
        local diffDays_for_test = currentWeekdayNumeric_for_test - targetWeekdayNumeric_for_test
        if diffDays_for_test < 0 then
            diffDays_for_test = diffDays_for_test + 7
        end
        local target_day_ref_ts_for_test = current_ts_for_test - (diffDays_for_test * 24 * 3600)

        local expected_year_key = os_module.date('%Y', target_day_ref_ts_for_test)
        local expected_week_key = os_module.date('%W', target_day_ref_ts_for_test)

        local data = maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local item =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items[1]

        assert.is_not_nil(item.startTime, 'startTime should be set')
        assert.is_not_nil(item.endTime, 'endTime should be set')

        local start_t_info = os_module.date('*t', item.startTime)
        local end_t_info = os_module.date('*t', item.endTime)

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
        -- maorunTime.setup({ path = tempPath }) -- Already in before_each
        local weekday = 'Friday'
        local hours_to_subtract = 2

        maorunTime.subtractTime({ time = hours_to_subtract, weekday = weekday })

        -- Calculate the year and week that subtractTime (via saveTime) would have used
        local current_ts_for_test = os_module.time()
        local currentWeekdayNumeric_for_test = os_module.date('*t', current_ts_for_test).wday - 1
        local targetWeekdayNumeric_for_test = maorunTime.weekdays[weekday]
        local diffDays_for_test = currentWeekdayNumeric_for_test - targetWeekdayNumeric_for_test
        if diffDays_for_test < 0 then
            diffDays_for_test = diffDays_for_test + 7
        end
        local target_day_ref_ts_for_test = current_ts_for_test - (diffDays_for_test * 24 * 3600)

        local expected_year_key = os_module.date('%Y', target_day_ref_ts_for_test)
        local expected_week_key = os_module.date('%W', target_day_ref_ts_for_test)

        local data = maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local item =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday].items[1]

        assert.is_not_nil(item, 'Item should be saved')
        assert.are.same(-hours_to_subtract, item.diffInHours)

        -- In subtractTime, startTime is set to 23:00 of the target day,
        -- and endTime is startTime - duration.
        -- So, endTime should be item.startTime - (hours_to_subtract * 3600)
        local expected_end_time = item.startTime - (hours_to_subtract * 3600)
        assert.are.same(expected_end_time, item.endTime)

        local start_readable_expected = os_module.date('%H:%M', item.startTime)
        local end_readable_expected = os_module.date('%H:%M', item.endTime)

        assert.are.same(start_readable_expected, item.startReadable)
        assert.are.same(end_readable_expected, item.endReadable)
    end)
end)
