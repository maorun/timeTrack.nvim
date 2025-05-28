local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os') -- Use a different name to avoid conflict with global os

local tempPath

before_each(function()
    tempPath = os_module.tmpname()
    -- Ensure the file is created for setup, similar to calculate_spec
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os_module.remove(tempPath)
end)

describe('addTime', function()
    it('should add time to a specific weekday', function()
        maorunTime.setup({ path = tempPath })
        local targetWeekday = 'Monday'
        local hoursToAdd = 2
        maorunTime.addTime({ time = hoursToAdd, weekday = targetWeekday })
        local data = maorunTime.calculate({ year = os_module.date('%Y'), weeknumber = os_module.date('%W') })

        assert.are.same(hoursToAdd, data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].diffInHours)
        local endTimeTs = data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].endTime
        local endTimeInfo = os_module.date('*t', endTimeTs)
        assert.are.same(23, endTimeInfo.hour)
        assert.are.same(0, endTimeInfo.min)
        assert.are.same(0, endTimeInfo.sec)

        local startTimeTs = data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].startTime
        assert.are.same(hoursToAdd * 3600, endTimeTs - startTimeTs)
    end)

    it('should handle floating point time addition', function()
        maorunTime.setup({ path = tempPath })
        local targetWeekday = 'Tuesday'
        local hoursToAdd = 2.5
        maorunTime.addTime({ time = hoursToAdd, weekday = targetWeekday })
        local data = maorunTime.calculate({ year = os_module.date('%Y'), weeknumber = os_module.date('%W') })

        assert.are.same(hoursToAdd, data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].diffInHours)
        local endTimeTs = data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].endTime
        local endTimeInfo = os_module.date('*t', endTimeTs)
        assert.are.same(23, endTimeInfo.hour)
        assert.are.same(0, endTimeInfo.min)
        assert.are.same(0, endTimeInfo.sec)

        local startTimeTs = data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].startTime
        -- Using math.floor for comparison due to potential floating point inaccuracies with seconds
        assert.are.same(math.floor(hoursToAdd * 3600), math.floor(endTimeTs - startTimeTs))
    end)

    it('should add time to the current day if weekday is nil', function()
        maorunTime.setup({ path = tempPath })
        local hoursToAdd = 3
        local targetWeekday = os_module.date('%A') -- Get current weekday name

        maorunTime.addTime({ time = hoursToAdd })
        local data = maorunTime.calculate({ year = os_module.date('%Y'), weeknumber = os_module.date('%W') })

        assert.are.same(hoursToAdd, data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].diffInHours)
        local endTimeTs = data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].endTime
        local endTimeInfo = os_module.date('*t', endTimeTs)
        assert.are.same(23, endTimeInfo.hour)
        assert.are.same(0, endTimeInfo.min)
        assert.are.same(0, endTimeInfo.sec)

        local startTimeTs = data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].startTime
        assert.are.same(hoursToAdd * 3600, endTimeTs - startTimeTs)
    end)

    it('should add time correctly when tracking is paused', function()
        maorunTime.setup({ path = tempPath })
        maorunTime.TimePause()
        assert.is_true(maorunTime.isPaused())

        local targetWeekday = 'Wednesday'
        local hoursToAdd = 4
        maorunTime.addTime({ time = hoursToAdd, weekday = targetWeekday })
        local data = maorunTime.calculate({ year = os_module.date('%Y'), weeknumber = os_module.date('%W') })

        assert.are.same(hoursToAdd, data.content.data[os_module.date('%Y')][os_module.date('%W')].weekdays[targetWeekday].items[1].diffInHours)
        -- The problem description says "should resume and re-pause", implying isPaused should be true.
        -- However, addTime typically unpauses. Let's assume it should be unpaused after adding time.
        -- If the intention is that addTime itself re-pauses, the implementation of addTime or TimePause would need to reflect that.
        -- For now, asserting based on typical behavior of addTime unpausing.
        -- assert.is_false(maorunTime.isPaused())
        -- Update: Based on the subtask description "Assert maorunTime.isPaused() is true (should resume and re-pause)",
        -- we expect it to be true.
        assert.is_true(maorunTime.isPaused())
    end)

    it('should add to existing entries, not overwrite by default', function()
        maorunTime.setup({ path = tempPath })
        local targetWeekday = 'Thursday'
        local initialHours = 1
        local additionalHours = 2

        maorunTime.addTime({ time = initialHours, weekday = targetWeekday })
        maorunTime.addTime({ time = additionalHours, weekday = targetWeekday })
        local data = maorunTime.calculate({ year = os_module.date('%Y'), weeknumber = os_module.date('%W') })
        local yearKey = os_module.date('%Y')
        local weekKey = os_module.date('%W')

        assert.are.same(2, #data.content.data[yearKey][weekKey].weekdays[targetWeekday].items)
        assert.are.same(initialHours, data.content.data[yearKey][weekKey].weekdays[targetWeekday].items[1].diffInHours)
        assert.are.same(additionalHours, data.content.data[yearKey][weekKey].weekdays[targetWeekday].items[2].diffInHours)
    end)
end)
