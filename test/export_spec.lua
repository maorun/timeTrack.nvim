local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os')

local tempPath

-- Store original os functions
local original_os_date = os_module.date
local original_os_time = os_module.time

before_each(function()
    tempPath = os_module.tmpname()
    maorunTime.setup({ path = tempPath })
end)

after_each(function()
    os_module.remove(tempPath)
    -- Restore original os functions
    os_module.date = original_os_date
    os_module.time = original_os_time
end)

describe('Time Export Functionality', function()
    describe('exportTimeData', function()
        it('should export CSV format for weekly data', function()
            -- Mock time: Monday, March 13, 2023 (week 11)
            local mock_time = 1678704000 -- Monday 10:00 AM
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add some test data
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600, -- 1 hour later
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = mock_time + 7200, -- 2 hours later
                endTime = mock_time + 10800, -- 3 hours total
                weekday = 'Monday',
                project = 'TestProject',
                file = 'main.lua',
            })

            local csv_export = maorunTime.exportTimeData({
                format = 'csv',
                range = 'week',
                year = '2023',
                week = '11',
            })

            -- Check CSV header
            assert.is_not_nil(
                csv_export:find('Date,Weekday,Project,File,Start Time,End Time,Duration %(Hours%)')
            )

            -- Check CSV data rows
            assert.is_not_nil(csv_export:find('2023%-03%-13,Monday,TestProject,test%.lua'))
            assert.is_not_nil(csv_export:find('2023%-03%-13,Monday,TestProject,main%.lua'))

            -- Check duration values
            assert.is_not_nil(csv_export:find('1%.00'))
        end)

        it('should export Markdown format for weekly data', function()
            -- Mock time: Monday, March 13, 2023 (week 11)
            local mock_time = 1678704000
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add test data
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 7200, -- 2 hours
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            local md_export = maorunTime.exportTimeData({
                format = 'markdown',
                range = 'week',
                year = '2023',
                week = '11',
            })

            -- Check Markdown structure
            assert.is_not_nil(md_export:find('Time Tracking Export'))
            assert.is_not_nil(md_export:find('Week 11'))
            assert.is_not_nil(md_export:find('## Summary'))
            assert.is_not_nil(md_export:find('Total Time'))
            assert.is_not_nil(md_export:find('Time by Project'))
            assert.is_not_nil(md_export:find('TestProject'))
            assert.is_not_nil(md_export:find('## Detailed Entries'))
            assert.is_not_nil(md_export:find('| Date | Weekday | Project'))
        end)

        it('should export monthly data correctly', function()
            -- Mock time for March 2023
            local march_1_time = 1677628800 -- March 1, 2023
            local march_15_time = 1678838400 -- March 15, 2023

            os_module.time = function()
                return march_1_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or march_1_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add entries from different weeks in March
            maorunTime.addManualTimeEntry({
                startTime = march_1_time,
                endTime = march_1_time + 3600, -- 1 hour
                project = 'ProjectA',
                file = 'file1.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = march_15_time,
                endTime = march_15_time + 7200, -- 2 hours
                project = 'ProjectB',
                file = 'file2.lua',
            })

            local csv_export = maorunTime.exportTimeData({
                format = 'csv',
                range = 'month',
                year = '2023',
                month = '3', -- March
            })

            -- Should include both entries from March
            assert.is_not_nil(csv_export:find('ProjectA'))
            assert.is_not_nil(csv_export:find('ProjectB'))
            assert.is_not_nil(csv_export:find('file1%.lua'))
            assert.is_not_nil(csv_export:find('file2%.lua'))
        end)

        it('should handle empty data gracefully', function()
            local csv_export = maorunTime.exportTimeData({
                format = 'csv',
                range = 'week',
                year = '2025',
                week = '50',
            })

            -- Should return just the header for CSV
            assert.are.equal(
                'Date,Weekday,Project,File,Start Time,End Time,Duration (Hours)\n',
                csv_export
            )

            local md_export = maorunTime.exportTimeData({
                format = 'markdown',
                range = 'week',
                year = '2025',
                week = '50',
            })

            -- Should return a "no data" message for Markdown
            assert.is_not_nil(
                md_export:find('No time tracking data found for the specified period')
            )
        end)

        it('should validate input parameters', function()
            assert.has_error(function()
                maorunTime.exportTimeData({ format = 'invalid' })
            end, 'Invalid format. Supported formats: csv, markdown')

            assert.has_error(function()
                maorunTime.exportTimeData({ range = 'invalid' })
            end, 'Invalid range. Supported ranges: week, month')
        end)

        it('should use default parameters when not specified', function()
            -- Mock current date
            local current_year = '2023'
            local current_week = '11'

            os_module.date = function(format)
                if format == '%Y' then
                    return current_year
                elseif format == '%W' then
                    return current_week
                elseif format == '%m' then
                    return '03'
                else
                    return original_os_date(format)
                end
            end

            -- Should not error with no parameters (using defaults)
            local result = maorunTime.exportTimeData()
            assert.is_string(result)
            assert.is_not_nil(
                result:find('Date,Weekday,Project,File,Start Time,End Time,Duration %(Hours%)')
            )
        end)

        it('should sort entries chronologically', function()
            -- Mock time base
            local base_time = 1678704000 -- Monday morning
            os_module.time = function()
                return base_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or base_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add entries in non-chronological order
            maorunTime.addManualTimeEntry({
                startTime = base_time + 7200, -- Later entry
                endTime = base_time + 10800,
                weekday = 'Monday',
                project = 'ProjectB',
                file = 'file2.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = base_time, -- Earlier entry
                endTime = base_time + 3600,
                weekday = 'Monday',
                project = 'ProjectA',
                file = 'file1.lua',
            })

            local csv_export = maorunTime.exportTimeData({
                format = 'csv',
                range = 'week',
                year = '2023',
                week = '11',
            })

            local lines = {}
            for line in csv_export:gmatch('[^\n]+') do
                table.insert(lines, line)
            end

            -- ProjectA (earlier time) should come before ProjectB (later time)
            local projectA_line = nil
            local projectB_line = nil
            for i, line in ipairs(lines) do
                if line:find('ProjectA') then
                    projectA_line = i
                elseif line:find('ProjectB') then
                    projectB_line = i
                end
            end

            assert.is_not_nil(projectA_line)
            assert.is_not_nil(projectB_line)
            assert.is_true(
                projectA_line < projectB_line,
                'Entries should be sorted chronologically'
            )
        end)

        it('should properly escape CSV fields containing special characters', function()
            -- Mock time
            local mock_time = 1678704000
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add entries with special characters that need CSV escaping
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600,
                weekday = 'Monday',
                project = 'Project, with comma',
                file = 'file"with"quotes.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = mock_time + 3600,
                endTime = mock_time + 7200,
                weekday = 'Monday',
                project = 'Project with\nnewline',
                file = 'normal_file.lua',
            })

            local csv_export = maorunTime.exportTimeData({
                format = 'csv',
                range = 'week',
                year = '2023',
                week = '11',
            })

            -- Check that fields with commas are properly quoted
            assert.is_not_nil(csv_export:find('"Project, with comma"'))

            -- Check that fields with quotes have escaped quotes and are quoted
            assert.is_not_nil(csv_export:find('"file""with""quotes%.lua"'))

            -- Check that fields with newlines are properly quoted
            assert.is_not_nil(csv_export:find('"Project with\nnewline"'))

            -- Verify that special characters don't break CSV structure
            -- The output should be valid CSV format regardless of content
            assert.is_true(csv_export:len() > 0)
            assert.is_not_nil(
                csv_export:find('Date,Weekday,Project,File,Start Time,End Time,Duration %(Hours%)')
            )
        end)
    end)

    describe('Global Time.export function', function()
        it('should be accessible through the global Time object', function()
            -- Mock basic time
            os_module.time = function()
                return 1678704000
            end
            os_module.date = function(format, time_val)
                return original_os_date(format, time_val or 1678704000)
            end

            maorunTime.setup({ path = tempPath })

            -- Test that Time.export exists and works
            assert.is_function(Time.export)
            local result = Time.export({ format = 'csv', range = 'week' })
            assert.is_string(result)
            assert.is_not_nil(result:find('Date,Weekday,Project,File'))
        end)
    end)
end)
