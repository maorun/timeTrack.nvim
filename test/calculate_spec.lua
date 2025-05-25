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
        assert.are.same(
            2,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].summary.diffInHours
        )
        assert.are.same(
            -6,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].summary.overhour
        )
        assert.are.same(
            2,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].items[1].diffInHours
        )
    end)
end)

describe('setTime', function()
    it('should correctly set time on a day with no prior entries', function()
        maorunTime.setup({
            path = tempPath,
            -- Using default hoursPerWeekday which should include 'Montag' = 8
        })

        local testWeekday = 'Montag'
        local testHours = 5
        local expectedOverhour = testHours - 8 -- Assuming default 8 hours for Montag

        maorunTime.setTime(testHours, testWeekday)

        local year = os.date('%Y')
        local weekNum = os.date('%W')

        -- Ensure the week is initialized if it wasn't (setTime should handle this)
        -- We fetch the data via calculate() as it's the public way to get processed data
        local currentData = maorunTime.calculate().content.data[year][weekNum]

        -- Check if weekdays table and specific weekday entry exist
        assert.truthy(currentData.weekdays, 'Weekdays table should exist')
        local dayData = currentData.weekdays[testWeekday]
        assert.truthy(dayData, 'Data for ' .. testWeekday .. ' should exist')
        assert.truthy(dayData.items, testWeekday .. ' should have an items table')
        assert.are.same(1, #dayData.items, 'Should be exactly one entry for ' .. testWeekday)
        assert.are.same(
            testHours,
            dayData.items[1].diffInHours,
            'Incorrect diffInHours for the entry'
        )

        assert.truthy(dayData.summary, testWeekday .. ' should have a summary table')
        assert.are.same(
            testHours,
            dayData.summary.diffInHours,
            'Incorrect summary diffInHours for ' .. testWeekday
        )
        assert.are.same(
            expectedOverhour,
            dayData.summary.overhour,
            'Incorrect summary overhour for ' .. testWeekday
        )
    end)
end)

describe('setIllDay', function()
    it('should add the average time on a specific weekday', function()
        maorunTime.setup({
            path = tempPath,
        })

        local data = maorunTime.setIllDay(os.date('%A'))
        -- 8 because everyday is 8 hours
        assert.are.same(
            8,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].items[1].diffInHours
        )

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
        assert.are.same(
            7.2,
            data.content.data[os.date('%Y')][os.date('%W')].weekdays[os.date('%A')].items[1].diffInHours
        )
    end)
end)
