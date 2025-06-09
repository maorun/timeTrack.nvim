local helper = require('test.helper')
-- helper.plenary_dep() -- Removed, as it doesn't exist in helper.lua
-- helper.notify_dep() -- Removed, as it doesn't exist in helper.lua

-- local plugin = require('maorun.plugin') -- Removed as maorun.plugin does not exist and 'plugin' is unused
local maorunTime = require('maorun.time')
local os = require('os') -- Added as it's used in before_each/after_each

local tempPath

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
end)
after_each(function()
    os.remove(tempPath)
end)

describe('init plugin', function()
    it('should have the path saved', function()
        local data = maorunTime.setup({
            path = tempPath,
        }).path
        assert.are.same(tempPath, data)
    end)

    it('should have default hoursPerWeekday', function()
        local data = maorunTime.setup({
            path = tempPath,
        }).content
        local expectedHours = {
            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 8,
            Saturday = 0,
            Sunday = 0,
        }
        assert.are.same(expectedHours, data.hoursPerWeekday)
    end)

    it('should overwrite default hourPerWeekday', function()
        local data = maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = {
                Monday = 7,

                Wednesday = 6,
            },
        }).content

        assert.are.same({
            Monday = 7,

            Wednesday = 6,
        }, data.hoursPerWeekday)
    end)

    it('should initialize initial date', function()
        local data = maorunTime.setup({
            path = tempPath,
        }).content
        -- Updated expected structure for init
        assert.are.same({
            [os.date('%Y')] = {
                [os.date('%W')] = {
                    ['default_project'] = {
                        ['default_file'] = {
                            weekdays = {},
                        },
                    },
                    -- Week summary is not created by init directly anymore, but by calculate
                },
            },
        }, data.data)
    end)
end)

it('should add/subtract time to a specific day', function()
    maorunTime.setup({ path = tempPath })

    local current_wday_numeric = os.date('*t', os.time()).wday
    local current_weekday = wdayToEngName[current_wday_numeric]

    local data = maorunTime.addTime({
        time = 2,
        weekday = current_weekday,
    })

    local year = os.date('%Y')
    local weekNum = os.date('%W')
    local week_content_path = data.content.data[year][weekNum]['default_project']['default_file']
    local week_summary_path = data.content.data[year][weekNum].summary

    local configured_hours_day = data.content.hoursPerWeekday[current_weekday]
    local expected_daily_overhour_1st_add = 2 - configured_hours_day
    assert.are.same(
        expected_daily_overhour_1st_add,
        week_content_path.weekdays[current_weekday].summary.overhour,
        'Daily overhour for ' .. current_weekday .. ' after 1st add'
    )
    assert.is_not_nil(
        week_summary_path,
        'Week summary should exist after calculate (called by addTime via saveTime)'
    )
    if week_summary_path then
        assert.are.same(
            expected_daily_overhour_1st_add,
            week_summary_path.overhour,
            'Weekly overhour after 1st add'
        )
    end

    data = maorunTime.addTime({
        time = 2,
        weekday = current_weekday,
    })
    week_content_path = data.content.data[year][weekNum]['default_project']['default_file']
    week_summary_path = data.content.data[year][weekNum].summary

    local total_logged_hours_after_2nd_add = 4
    local expected_daily_overhour_2nd_add = total_logged_hours_after_2nd_add - configured_hours_day
    assert.are.same(
        expected_daily_overhour_2nd_add,
        week_content_path.weekdays[current_weekday].summary.overhour,
        'Daily overhour for ' .. current_weekday .. ' after 2nd add'
    )
    if week_summary_path then
        assert.are.same(
            expected_daily_overhour_2nd_add,
            week_summary_path.overhour,
            'Weekly overhour after 2nd add'
        )
    end

    data = maorunTime.subtractTime({ time = 2, weekday = current_weekday })
    week_content_path = data.content.data[year][weekNum]['default_project']['default_file']
    week_summary_path = data.content.data[year][weekNum].summary

    local final_logged_hours_after_subtract = 2
    local expected_daily_overhour_after_subtract = final_logged_hours_after_subtract
        - configured_hours_day
    assert.are.same(
        expected_daily_overhour_after_subtract,
        week_content_path.weekdays[current_weekday].summary.overhour,
        'Daily overhour for ' .. current_weekday .. ' after subtract'
    )
    if week_summary_path then
        assert.are.same(
            expected_daily_overhour_after_subtract,
            week_summary_path.overhour,
            'Weekly overhour after subtract'
        )
    end
end)

describe('pause / resume time-tracking', function()
    it('should pause time tracking', function()
        maorunTime.setup({
            path = tempPath,
        })
        maorunTime.TimePause()
        assert.is_true(maorunTime.isPaused())
    end)
    it('should resume time tracking', function()
        maorunTime.setup({
            path = tempPath,
        })
        maorunTime.TimePause()
        maorunTime.TimeResume()
        assert.is_false(maorunTime.isPaused())
    end)
end)

it('should init weekdayNumberMap', function()
    maorunTime.setup({
        path = tempPath,
    })
    assert.same(maorunTime.weekdays, {
        Sunday = 0,
        Monday = 1,
        Tuesday = 2,
        Wednesday = 3,
        Thursday = 4,
        Friday = 5,
        Saturday = 6,
    })
end)
