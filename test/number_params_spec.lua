local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

describe('Number Parameters Support', function()
    local maorunTime = require('maorun.time')
    local Path = require('plenary.path')
    local os_module = require('os')
    local tempPath

    before_each(function()
        -- Create temporary test file
        tempPath = os_module.tmpname()
        Path:new(tempPath):touch()

        -- Mock os.time and os.date for consistent testing
        local mock_time = 1678704000 -- Monday, Mar 13, 2023 12:00:00 PM GMT
        _G.original_os_time = os.time
        _G.original_os_date = os.date

        os.time = function()
            return mock_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_time
            return _G.original_os_date(format, time_val)
        end
    end)

    after_each(function()
        -- Restore original os functions
        if _G.original_os_time then
            os.time = _G.original_os_time
            _G.original_os_time = nil
        end
        if _G.original_os_date then
            os.date = _G.original_os_date
            _G.original_os_date = nil
        end

        -- Clean up temp file
        if tempPath then
            os_module.remove(tempPath)
        end
    end)

    describe('getWeeklySummary with number parameters', function()
        it('should accept year and week as numbers', function()
            maorunTime.setup({ path = tempPath })

            -- Add some test data for a specific week
            maorunTime.addManualTimeEntry({
                startTime = 1678704000, -- Monday, Mar 13, 2023
                endTime = 1678704000 + 3600 * 8, -- 8 hours later
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Test with number parameters
            local summary_numbers = maorunTime.getWeeklySummary({
                year = 2023, -- number
                week = 11, -- number
            })

            -- Test with string parameters (existing behavior)
            local summary_strings = maorunTime.getWeeklySummary({
                year = '2023', -- string
                week = '11', -- string
            })

            -- Both should return the same results
            assert.are.equal('2023', summary_numbers.year)
            assert.are.equal('11', summary_numbers.week)
            assert.are.equal(summary_strings.year, summary_numbers.year)
            assert.are.equal(summary_strings.week, summary_numbers.week)
            assert.are.equal(summary_strings.totals.totalHours, summary_numbers.totals.totalHours)
        end)

        it('should handle mixed number and string parameters', function()
            maorunTime.setup({ path = tempPath })

            -- Add test data
            maorunTime.addManualTimeEntry({
                startTime = 1678704000,
                endTime = 1678704000 + 3600 * 6,
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Test mixed parameters
            local summary_mixed1 = maorunTime.getWeeklySummary({
                year = 2023, -- number
                week = '11', -- string
            })

            local summary_mixed2 = maorunTime.getWeeklySummary({
                year = '2023', -- string
                week = 11, -- number
            })

            -- Both should work correctly
            assert.are.equal('2023', summary_mixed1.year)
            assert.are.equal('11', summary_mixed1.week)
            assert.are.equal('2023', summary_mixed2.year)
            assert.are.equal('11', summary_mixed2.week)
            assert.are.equal(summary_mixed1.totals.totalHours, summary_mixed2.totals.totalHours)
        end)

        it('should handle edge cases with number parameters', function()
            maorunTime.setup({ path = tempPath })

            -- Test with zero-padded week numbers
            local summary1 = maorunTime.getWeeklySummary({
                year = 2023,
                week = 1, -- Should work as single digit
            })

            local summary2 = maorunTime.getWeeklySummary({
                year = 2023,
                week = 52, -- Should work as double digit
            })

            assert.are.equal('2023', summary1.year)
            assert.are.equal('1', summary1.week)
            assert.are.equal('2023', summary2.year)
            assert.are.equal('52', summary2.week)
        end)
    end)

    describe('other functions with number parameters', function()
        it('should accept numbers in listTimeEntries', function()
            maorunTime.setup({ path = tempPath })

            -- Add some test data
            maorunTime.addManualTimeEntry({
                startTime = 1678704000,
                endTime = 1678704000 + 3600 * 4,
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Test with number parameters - need to match project and weekday
            local entries = maorunTime.listTimeEntries({
                year = 2023, -- number
                weeknumber = 11, -- number
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            assert.is_table(entries)
            assert.is_true(#entries > 0)
        end)

        it('should accept numbers in validateTimeData', function()
            maorunTime.setup({ path = tempPath })

            -- Test with number parameters (even if no data exists)
            local results = maorunTime.validateTimeData({
                year = 2023, -- number
                week = 11, -- number
            })

            assert.is_table(results)
            assert.is_table(results.summary)
        end)

        it('should accept numbers in calculate function', function()
            maorunTime.setup({ path = tempPath })

            -- Add test data first
            maorunTime.addManualTimeEntry({
                startTime = 1678704000,
                endTime = 1678704000 + 3600 * 5,
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Test calculate with number parameters
            local result = maorunTime.calculate({
                year = 2023, -- number
                weeknumber = 11, -- number
            })

            -- Should not error and should return result
            assert.is_table(result)
        end)
    end)
end)
