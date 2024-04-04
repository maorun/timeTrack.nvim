local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os = require('os')
local tempPath = os.tmpname()

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
            }
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
