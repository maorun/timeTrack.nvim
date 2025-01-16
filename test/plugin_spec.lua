local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os = require('os')
local tempPath

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
        assert.are.same({
            Montag = 8,
            Dienstag = 8,
            Mittwoch = 8,
            Donnerstag = 8,
            Freitag = 8,

            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 8,
        }, data.hoursPerWeekday)
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
            Dienstag = 8,
            Mittwoch = 8,
            Donnerstag = 8,
            Freitag = 8,

            Monday = 8,
            Tuesday = 8,
            Wednesday = 6,
            Thursday = 8,
            Friday = 8,
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
    local data = maorunTime.addTime({
        time = 2,
        weekday = os.date('%A')
    })

    local week = data.content.data[os.date('%Y')][os.date('%W')]
    assert.are.same(-6, week.summary.overhour)

    data = maorunTime.addTime({
        time = 2,
        weekday = os.date('%A')
    })
    week = data.content.data[os.date('%Y')][os.date('%W')]
    assert.are.same(-4, week.summary.overhour)

    data = maorunTime.subtractTime(2, os.date('%A'))
    week = data.content.data[os.date('%Y')][os.date('%W')]
    assert.are.same(-6, week.summary.overhour)
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
