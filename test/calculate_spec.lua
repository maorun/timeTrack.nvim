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

describe('calculate', function()
    it('should calculate correct', function()
        maorunTime.setup({
            path = tempPath,
        })
        local data = maorunTime.calculate()
        assert.are.same({}, data.content.data[os.date('%Y')][os.date('%W')].weekdays)

        maorunTime.addTime({ time = 2, weekday = os.date('%A') })

        data = maorunTime.calculate()

        assert.are.same(-6, data.content.data[os.date('%Y')][os.date('%W')].summary.overhour)
        assert.are.same(2,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].summary
            .diffInHours)
        assert.are.same(-6,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].summary.overhour)
        assert.are.same(2,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].items[1]
            .diffInHours)
    end)
end)

describe('setIllDay', function()
    it('should add the average time on a specific weekday', function()
        maorunTime.setup({
            path = tempPath,
        })

        local data = maorunTime.setIllDay(os.date('%A'))
        -- 8 because everyday is 8 hours
        assert.are.same(8,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].items[1]
            .diffInHours)

        maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = {
                Monday = 8,
                Tuesday = 8,
                Wednesday = 8,
                Thursday = 7,
                Friday = 5,
            },
        })

        local data = maorunTime.setIllDay(os.date('%A'))
        assert.are.same(7.2,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].items[1]
            .diffInHours)
    end)
end)
