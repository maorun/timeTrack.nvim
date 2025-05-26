local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os = require('os')
local tempPath

local wdayToEngName = {
    [1] = "Sunday", [2] = "Monday", [3] = "Tuesday", [4] = "Wednesday",
    [5] = "Thursday", [6] = "Friday", [7] = "Saturday"
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
            Monday = 8, Tuesday = 8, Wednesday = 8, Thursday = 8, Friday = 8,
            Saturday = 0, Sunday = 0
        }
        assert.are.same(expectedHours, data.hoursPerWeekday)
    end)

    it('should overwrite default hourPerWeekday', function()
        local data = maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = {
                Montag = 7,

                Wednesday = 6,
            },
        }).content

        assert.are.same({
            Montag = 7,

            Wednesday = 6,
        }, data.hoursPerWeekday)
    end)

    it('should initialize initial date', function()
        local data = maorunTime.setup({
            path = tempPath,
        }).content
        assert.are.same({
            [os.date('%Y')] = {
                [os.date('%W')] = {
                    summary = {
                        overhour = 0,
                    },
                    weekdays = {},
                },
            },
        }, data.data)
    end)
end)

it('should add/subtract time to a specific day', function()
    maorunTime.setup({
        path = tempPath,
    })
    local current_wday_numeric = os.date("*t", os.time()).wday
    local current_weekday = wdayToEngName[current_wday_numeric] -- Standardized English name

    local data = maorunTime.addTime({
        time = 2,
        weekday = current_weekday,
    })

    local year = os.date('%Y')
    local weekNum = os.date('%W')
    local week = data.content.data[year][weekNum]
    local configured_hours_day = data.content.hoursPerWeekday[current_weekday]

    local expected_daily_overhour_1st_add = 2 - configured_hours_day
    assert.are.same(expected_daily_overhour_1st_add, week.weekdays[current_weekday].summary.overhour, "Daily overhour for " .. current_weekday .. " after 1st add")
    assert.are.same(expected_daily_overhour_1st_add, week.summary.overhour, "Weekly overhour after 1st add")

    data = maorunTime.addTime({
        time = 2, -- Current test adds 2, not 3 as per original instruction example
        weekday = current_weekday,
    })
    week = data.content.data[year][weekNum]
    local total_logged_hours_after_2nd_add = 4 -- (2 from first add + 2 from second)
    local expected_daily_overhour_2nd_add = total_logged_hours_after_2nd_add - configured_hours_day
    assert.are.same(expected_daily_overhour_2nd_add, week.weekdays[current_weekday].summary.overhour, "Daily overhour for " .. current_weekday .. " after 2nd add")
    assert.are.same(expected_daily_overhour_2nd_add, week.summary.overhour, "Weekly overhour after 2nd add")

    data = maorunTime.subtractTime(2, current_weekday) -- Current test subtracts 2, not 1
    week = data.content.data[year][weekNum]
    local final_logged_hours_after_subtract = 2 -- (4 - 2)
    local expected_daily_overhour_after_subtract = final_logged_hours_after_subtract - configured_hours_day
    assert.are.same(expected_daily_overhour_after_subtract, week.weekdays[current_weekday].summary.overhour, "Daily overhour for " .. current_weekday .. " after subtract")
    assert.are.same(expected_daily_overhour_after_subtract, week.summary.overhour, "Weekly overhour after subtract")
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
        Monday = 1,
        Tuesday = 2,
        Wednesday = 3,
        Thursday = 4,
        Friday = 5,
        Saturday = 6,
        Sunday = 0,
    })
end)
