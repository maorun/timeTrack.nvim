local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os') -- Use a different name to avoid conflict with global os

local tempPath

before_each(function()
    tempPath = os_module.tmpname()
    -- Ensure the file is created for setup
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os_module.remove(tempPath)
end)

describe('TimeStart', function()
    it('should record start time for the current day and time', function()
        -- Mock os.date and os.time
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        maorunTime.TimeStart({ time = mock_time }) -- Pass opts table
        local data =
            maorunTime.calculate({ year = os_module.date('%Y'), weeknumber = os_module.date('%W') })

        local current_weekday = os_module.date('%A')
        local year = os_module.date('%Y')
        local week_number = os_module.date('%W')

        assert.is_not_nil(
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1],
            'Time entry not found for current day'
        )
        assert.are.same(
            mock_time,
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1].startTime
        )
        assert.is_nil(
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1].endTime
        )

        -- Restore original functions
        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should record start time for a specific weekday and time', function()
        local target_weekday = 'Monday'
        local specific_time = 1678694400 -- Monday, March 13, 2023 08:00:00 AM GMT

        -- Mock os.date and os.time to control the "current" date if TimeStart uses it for year/week determination
        local original_os_date = os_module.date
        local original_os_time = os_module.time
        os_module.time = function()
            return specific_time
        end -- Ensure os.time() returns the specific time
        os_module.date = function(format, time)
            time = time or specific_time -- Default to specific_time if no time is provided
            return original_os_date(format, time) -- Call original os.date with potentially mocked time
        end

        maorunTime.TimeStart({ weekday = target_weekday, time = specific_time }) -- Pass opts table

        -- Determine year and week number from the specific_time
        local year = original_os_date('%Y', specific_time)
        local week_number = original_os_date('%W', specific_time)

        local data = maorunTime.calculate({ year = year, weeknumber = week_number })

        assert.is_not_nil(
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[target_weekday].items[1],
            'Time entry not found for target day'
        )
        assert.are.same(
            specific_time,
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[target_weekday].items[1].startTime
        )
        assert.is_nil(
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[target_weekday].items[1].endTime
        )

        -- Restore original functions
        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should not add a new entry if an unstopped entry exists for the current day', function()
        -- Mock os.date and os.time
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local initial_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return initial_time
        end
        os_module.date = function(format, time)
            time = time or initial_time
            return original_os_date(format, time)
        end

        -- Start an initial entry
        maorunTime.TimeStart({ time = initial_time }) -- Pass opts table

        local year = os_module.date('%Y')
        local week_number = os_module.date('%W')
        local current_weekday = os_module.date('%A')

        -- Attempt to start another entry without stopping the first one
        local later_time = initial_time + 3600 -- One hour later
        os_module.time = function()
            return later_time
        end
        os_module.date = function(format, time) -- Ensure date also reflects this later time if needed
            time = time or later_time
            return original_os_date(format, time)
        end

        maorunTime.TimeStart({ time = later_time }) -- This call should be ignored, pass opts

        local data = maorunTime.calculate({ year = year, weeknumber = week_number })
        assert.are.same(
            1,
            #data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items,
            'Should only have one entry'
        )
        assert.are.same(
            initial_time,
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1].startTime
        )
        assert.is_nil(
            data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1].endTime
        )

        -- Restore original functions
        os_module.date = original_os_date
        os_module.time = original_os_time
    end)
end)

describe('TimeStop', function()
    it('should record end time for the current day and time and calculate diffInHours', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local start_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return start_time
        end
        os_module.date = function(format, time)
            time = time or start_time
            return original_os_date(format, time)
        end
        maorunTime.TimeStart({ time = start_time }) -- Pass opts table

        local stop_time = start_time + 3600 -- Stop 1 hour later
        os_module.time = function()
            return stop_time
        end
        os_module.date = function(format, time)
            time = time or stop_time
            return original_os_date(format, time)
        end
        maorunTime.TimeStop({time = stop_time}) -- Pass opts table

        local year = original_os_date('%Y', start_time)
        local week_number = original_os_date('%W', start_time)
        local current_weekday = original_os_date('%A', start_time)
        local data = maorunTime.calculate({ year = year, weeknumber = week_number })
        local item = data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1]

        assert.is_not_nil(item, 'Time entry not found')
        assert.are.same(stop_time, item.endTime)
        assert.are.same(1, item.diffInHours) -- 3600 seconds = 1 hour

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it(
        'should record end time for a specific weekday and time and calculate diffInHours',
        function()
            local original_os_date = os_module.date
            local original_os_time = os_module.time

            local target_weekday = 'Monday'
            local start_time = 1678694400 -- Monday, March 13, 2023 08:00:00 AM GMT
            local stop_time = start_time + (2 * 3600) -- Stop 2 hours later

            -- Mock time for TimeStart
            os_module.time = function()
                return start_time
            end
            os_module.date = function(format, time)
                time = time or start_time
                return original_os_date(format, time)
            end
        maorunTime.TimeStart({ weekday = target_weekday, time = start_time }) -- Pass opts table

            -- Mock time for TimeStop
            os_module.time = function()
                return stop_time
            end
            os_module.date = function(format, time)
                time = time or stop_time
                return original_os_date(format, time)
            end
        maorunTime.TimeStop({ weekday = target_weekday, time = stop_time }) -- Pass opts table

            local year = original_os_date('%Y', start_time)
            local week_number = original_os_date('%W', start_time)
            local data = maorunTime.calculate({ year = year, weeknumber = week_number })
        local item = data.content.data[year][week_number]["default_project"]["default_file"].weekdays[target_weekday].items[1]

            assert.is_not_nil(item, 'Time entry not found for target day')
            assert.are.same(stop_time, item.endTime)
            assert.are.same(2, item.diffInHours)

            os_module.date = original_os_date
            os_module.time = original_os_time
        end
    )

    it('should handle TimeStop call without a preceding TimeStart for the day', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local stop_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return stop_time
        end
        os_module.date = function(format, time)
            time = time or stop_time
            return original_os_date(format, time)
        end

        -- No TimeStart call for this day
        maorunTime.TimeStop({time = stop_time}) -- Attempt to stop, pass opts table

        local year = original_os_date('%Y', stop_time)
        local week_number = original_os_date('%W', stop_time)
        local current_weekday = original_os_date('%A', stop_time)
        local data = maorunTime.calculate({ year = year, weeknumber = week_number })

        -- Check that no item was created or that items list is empty/nil
        local weekday_data = data.content.data[year]
            and data.content.data[year][week_number]
            and data.content.data[year][week_number]["default_project"]
            and data.content.data[year][week_number]["default_project"]["default_file"]
            and data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday]
        if weekday_data and weekday_data.items then
            assert.are.same(
                0,
                #weekday_data.items,
                'No items should exist if TimeStart was not called'
            )
        else
            -- If weekday_data or items is nil, it also means no entry, which is correct
            assert.is_true(true)
        end
        -- We are also implicitly testing that no error occurred.
        -- Testing for notifications is complex and depends on the notification mock setup,
        -- which might be beyond simple unit test scope here. The lua/maorun/time/init.lua
        -- already has a notify call for this case.

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should not alter an already stopped entry', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local start_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        local first_stop_time = start_time + 3600 -- Stop 1 hour later
        local second_stop_time = first_stop_time + 1800 -- Attempt to stop again 30 mins later

        -- Initial Start
        os_module.time = function()
            return start_time
        end
        os_module.date = function(format, time)
            time = time or start_time
            return original_os_date(format, time)
        end
        maorunTime.TimeStart({time = start_time}) -- Pass opts table

        -- First Stop
        os_module.time = function()
            return first_stop_time
        end
        os_module.date = function(format, time)
            time = time or first_stop_time
            return original_os_date(format, time)
        end
        maorunTime.TimeStop({time = first_stop_time}) -- Pass opts table

        -- Attempt Second Stop
        os_module.time = function()
            return second_stop_time
        end
        os_module.date = function(format, time)
            time = time or second_stop_time
            return original_os_date(format, time)
        end
        maorunTime.TimeStop({time = second_stop_time}) -- Pass opts table, this call should not change the existing entry

        local year = original_os_date('%Y', start_time)
        local week_number = original_os_date('%W', start_time)
        local current_weekday = original_os_date('%A', start_time)
        local data = maorunTime.calculate({ year = year, weeknumber = week_number })
        local item = data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items[1]

        assert.is_not_nil(item, 'Time entry not found')
        assert.are.same(first_stop_time, item.endTime, 'endTime should remain from the first stop')
        assert.are.same(1, item.diffInHours, 'diffInHours should remain from the first stop')
        assert.are.same(
            1,
            #data.content.data[year][week_number]["default_project"]["default_file"].weekdays[current_weekday].items,
            'Should still only have one entry'
        )

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)
end)
