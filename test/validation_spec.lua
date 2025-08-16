local maorunTime = require('maorun.time')
local Path = require('plenary.path')

describe('Time Validation & Correction Mode', function()
    local tempPath = '/tmp/maorun-time-validation-test.json'
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

    describe('detectOverlappingEntries', function()
        it('should detect overlapping time entries in the same day/project/file', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add overlapping entries: 10:00-12:00 and 11:00-13:00
            maorunTime.addManualTimeEntry({
                startTime = base_time - (2 * 3600), -- 10:00 AM
                endTime = base_time, -- 12:00 PM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })
            
            maorunTime.addManualTimeEntry({
                startTime = base_time - (1 * 3600), -- 11:00 AM
                endTime = base_time + (1 * 3600), -- 13:00 PM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(1, validation_results.summary.total_overlaps)
            assert.are.equal(1, #validation_results.overlaps)
            assert.are.equal('overlap', validation_results.overlaps[1].type)
            assert.are.equal('TestProject', validation_results.overlaps[1].project)
            assert.are.equal('test.lua', validation_results.overlaps[1].file)
        end)

        it('should not detect non-overlapping time entries', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add non-overlapping entries: 10:00-11:00 and 12:00-13:00
            maorunTime.addManualTimeEntry({
                startTime = base_time - (2 * 3600), -- 10:00 AM
                endTime = base_time - (1 * 3600), -- 11:00 AM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })
            
            maorunTime.addManualTimeEntry({
                startTime = base_time, -- 12:00 PM
                endTime = base_time + (1 * 3600), -- 13:00 PM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(0, validation_results.summary.total_overlaps)
            assert.are.equal(0, #validation_results.overlaps)
        end)
    end)

    describe('detectDuplicateEntries', function()
        it('should detect duplicate time entries (same start/end times)', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add identical entries
            maorunTime.addManualTimeEntry({
                startTime = base_time - (2 * 3600), -- 10:00 AM
                endTime = base_time, -- 12:00 PM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })
            
            maorunTime.addManualTimeEntry({
                startTime = base_time - (2 * 3600), -- 10:00 AM
                endTime = base_time, -- 12:00 PM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(1, validation_results.summary.total_duplicates)
            assert.are.equal(1, #validation_results.duplicates)
            assert.are.equal('duplicate', validation_results.duplicates[1].type)
        end)

        it('should not detect non-duplicate entries with different times', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add different entries
            maorunTime.addManualTimeEntry({
                startTime = base_time - (2 * 3600), -- 10:00 AM
                endTime = base_time - (1 * 3600), -- 11:00 AM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })
            
            maorunTime.addManualTimeEntry({
                startTime = base_time, -- 12:00 PM
                endTime = base_time + (1 * 3600), -- 13:00 PM
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(0, validation_results.summary.total_duplicates)
            assert.are.equal(0, #validation_results.duplicates)
        end)
    end)

    describe('detectErroneousEntries', function()
        it('should detect entries with unrealistic durations (>24 hours)', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add entry with 25-hour duration
            maorunTime.addManualTimeEntry({
                startTime = base_time,
                endTime = base_time + (25 * 3600), -- 25 hours later
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(1, validation_results.summary.total_errors)
            assert.are.equal(1, #validation_results.errors)
            assert.are.equal('error', validation_results.errors[1].type)
            
            -- Check that the error message mentions unrealistic duration
            local found_duration_error = false
            for _, issue in ipairs(validation_results.errors[1].issues) do
                if string.find(issue, 'Unrealistische Dauer') then
                    found_duration_error = true
                    break
                end
            end
            assert.is_true(found_duration_error, 'Should detect unrealistic duration')
        end)

        it('should detect entries with negative durations', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add a valid entry first
            maorunTime.addManualTimeEntry({
                startTime = base_time,
                endTime = base_time + 3600,
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })
            
            -- Manually corrupt the data to create an entry with negative duration
            local config_module = require('maorun.time.config')
            local entries = config_module.obj.content.data['2023']['11']['Wednesday']['TestProject']['test.lua'].items
            
            -- Add an entry with end before start (this creates negative duration)
            table.insert(entries, {
                startTime = base_time,
                endTime = base_time - 3600, -- 1 hour before start
                diffInHours = -1, -- Negative duration
                startReadable = '12:00',
                endReadable = '11:00'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(1, validation_results.summary.total_errors)
            assert.are.equal(1, #validation_results.errors)
            
            -- Check that the error message mentions start time after end time or negative duration
            local found_time_error = false
            for _, issue in ipairs(validation_results.errors[1].issues) do
                if string.find(issue, 'Startzeit nach Endzeit') or string.find(issue, 'Negative') then
                    found_time_error = true
                    break
                end
            end
            assert.is_true(found_time_error, 'Should detect start time after end time or negative duration')
        end)

        it('should detect normal entries as valid', function()
            local base_time = 1678886400 -- 12:00 PM
            
            -- Add normal 2-hour entry
            maorunTime.addManualTimeEntry({
                startTime = base_time,
                endTime = base_time + (2 * 3600), -- 2 hours later
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua'
            })

            assert.are.equal(0, validation_results.summary.total_errors)
            assert.are.equal(0, #validation_results.errors)
        end)
    end)

    describe('validateTimeData full workflow', function()
        it('should scan all entries for a week and provide summary', function()
            local base_time = 1678886400 -- Wednesday, March 15, 2023
            
            -- Add duplicate entries only (to isolate the issue)
            maorunTime.addManualTimeEntry({
                startTime = base_time + (5 * 3600),
                endTime = base_time + (6 * 3600),
                weekday = 'Wednesday',
                project = 'Project2',
                file = 'file2.lua'
            })
            
            maorunTime.addManualTimeEntry({
                startTime = base_time + (5 * 3600),
                endTime = base_time + (6 * 3600),
                weekday = 'Wednesday',
                project = 'Project2',
                file = 'file2.lua'
            })

            local validation_results = maorunTime.validateTimeData({
                year = '2023',
                week = '11'
            })

            assert.are.equal(2, validation_results.summary.scanned_entries)
            assert.are.equal(0, validation_results.summary.total_overlaps) 
            -- If this fails with "expected 1, got 2", then the algorithm is counting each duplicate twice
            assert.are.equal(1, validation_results.summary.total_duplicates) -- Should be 1 duplicate pair
            assert.are.equal(0, validation_results.summary.total_errors)
        end)

        it('should return empty results for non-existent data', function()
            local validation_results = maorunTime.validateTimeData({
                year = '2025',
                week = '01'
            })

            assert.are.equal(0, validation_results.summary.scanned_entries)
            assert.are.equal(0, validation_results.summary.total_overlaps)
            assert.are.equal(0, validation_results.summary.total_duplicates)
            assert.are.equal(0, validation_results.summary.total_errors)
        end)
    end)
end)