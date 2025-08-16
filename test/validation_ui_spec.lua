local maorunTime = require('maorun.time')
local Path = require('plenary.path')

describe('Validation UI Integration', function()
    local tempPath = '/tmp/maorun-time-validation-ui-test.json'
    local original_os_date, original_os_time

    before_each(function()
        -- Clean up any existing temp file
        local temp_file = Path:new(tempPath)
        if temp_file:exists() then
            temp_file:rm()
        end

        -- Mock os.time and os.date for consistent testing
        original_os_date = os.date
        original_os_time = os.time

        local mock_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_time
        end
        os.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Initialize with test path
        maorunTime.setup({ path = tempPath })
    end)

    after_each(function()
        -- Restore original functions
        os.date = original_os_date
        os.time = original_os_time

        -- Clean up temp file
        local temp_file = Path:new(tempPath)
        if temp_file:exists() then
            temp_file:rm()
        end
    end)

    describe('validation function access', function()
        it('should expose validateTimeData function', function()
            assert.is_function(maorunTime.validateTimeData)

            local results = maorunTime.validateTimeData()
            assert.is_table(results)
            assert.is_table(results.summary)
            assert.is_table(results.overlaps)
            assert.is_table(results.duplicates)
            assert.is_table(results.errors)
        end)

        it('should expose validateAndCorrect function', function()
            assert.is_function(maorunTime.validateAndCorrect)
        end)

        it('should expose showValidationResults function', function()
            assert.is_function(maorunTime.showValidationResults)
        end)

        it('should expose validate function in global Time object', function()
            assert.is_function(Time.validate)

            local results = Time.validate()
            assert.is_table(results)
        end)

        it('should expose validateAndCorrect function in global Time object', function()
            assert.is_function(Time.validateAndCorrect)
        end)
    end)

    describe('validation workflow integration', function()
        it('should detect and format validation issues', function()
            local base_time = 1678886400 -- Wednesday, March 15, 2023

            -- Add overlapping entries
            maorunTime.addManualTimeEntry({
                startTime = base_time,
                endTime = base_time + (2 * 3600), -- 2 hours
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = base_time + (1 * 3600), -- 1 hour later
                endTime = base_time + (3 * 3600), -- 3 hours total
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Test validation
            local results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
            })

            assert.are.equal(1, results.summary.total_overlaps)
            assert.are.equal(0, results.summary.total_duplicates)
            assert.are.equal(0, results.summary.total_errors)

            -- Test that the UI formatting function works (indirectly)
            -- We can't easily test the UI display without mocking vim.ui.select
            -- But we can verify the functions are callable
            assert.has_no_error(function()
                maorunTime.showValidationResults(results)
            end)
        end)
    end)
end)
