-- CLI Tests for timeTrack.nvim
local helper = require('test.helper')

describe('CLI Integration', function()
    local cli
    local original_time
    local test_data_file = '/tmp/timetrack-cli-test.json'

    before_each(function()
        -- Mock os.time to return predictable values
        original_time = os.time
        os.time = function()
            return 1640995200 -- 2022-01-01 00:00:00 UTC (Saturday)
        end

        -- Mock os.date for predictable output
        _G.original_os_date = os.date
        os.date = function(format, time)
            if format == '%Y' then
                return '2022'
            end
            if format == '%W' then
                return '52'
            end -- Week 52 of 2021 (Saturday Jan 1 2022)
            if format == '%A' then
                return 'Saturday'
            end
            if format == '%H:%M' then
                return '00:00'
            end
            return _G.original_os_date(format, time)
        end

        -- Set up CLI module path
        package.path = './cli/?.lua;' .. package.path

        -- Remove any cached modules
        package.loaded['cli.simple'] = nil

        -- Load CLI module
        cli = require('cli.simple')

        -- Clean up test file
        os.remove(test_data_file)
    end)

    after_each(function()
        -- Restore original functions
        os.time = original_time
        os.date = _G.original_os_date

        -- Clean up
        package.loaded['cli.simple'] = nil
        os.remove(test_data_file)
    end)

    describe('CLI Basic Operations', function()
        it('should initialize with default configuration', function()
            local obj = cli.init()

            assert.is_not_nil(obj)
            assert.is_not_nil(obj.path)
            assert.is_table(obj.content)
            assert.is_table(obj.content.hoursPerWeekday)
            assert.are.equal(8, obj.content.hoursPerWeekday.Monday)
        end)

        it('should add manual time entry', function()
            local success = cli.add_time_entry({
                project = 'TestProject',
                file = 'test.lua',
                hours = 3.5,
                weekday = 'Saturday',
            })

            assert.is_true(success)

            -- Verify the data was saved
            local obj = cli.init()
            local year_data = obj.content.data['2022']
            local week_data = year_data['52']
            local day_data = week_data['Saturday']
            local project_data = day_data['TestProject']
            local file_data = project_data['test.lua']

            assert.are.equal(3.5, file_data.summary.diffInHours)
            assert.are.equal(1, #file_data.items)
            assert.are.equal(3.5, file_data.items[1].diffInHours)
        end)

        it('should get weekly summary', function()
            -- Add some test data
            cli.add_time_entry({
                project = 'Project A',
                file = 'file1.lua',
                hours = 2.0,
                weekday = 'Saturday',
            })

            cli.add_time_entry({
                project = 'Project B',
                file = 'file2.lua',
                hours = 1.5,
                weekday = 'Saturday',
            })

            local summary = cli.get_weekly_summary({
                year = '2022',
                week = '52',
            })

            assert.is_not_nil(summary.Saturday)
            assert.are.equal(3.5, summary.Saturday.total_hours)
            assert.is_not_nil(summary.Saturday.projects['Project A'])
            assert.is_not_nil(summary.Saturday.projects['Project B'])
            assert.are.equal(2.0, summary.Saturday.projects['Project A']['file1.lua'])
            assert.are.equal(1.5, summary.Saturday.projects['Project B']['file2.lua'])
        end)

        it('should list time entries', function()
            -- Add test data
            cli.add_time_entry({
                project = 'TestProject',
                file = 'test.lua',
                hours = 2.0,
                weekday = 'Saturday',
            })

            local entries = cli.list_entries({
                year = '2022',
                week = '52',
            })

            assert.are.equal(1, #entries)
            assert.are.equal('Saturday', entries[1].weekday)
            assert.are.equal('TestProject', entries[1].project)
            assert.are.equal('test.lua', entries[1].file)
            assert.are.equal(2.0, entries[1].diffInHours)
        end)

        it('should export data in CSV format', function()
            -- Add test data
            cli.add_time_entry({
                project = 'TestProject',
                file = 'test.lua',
                hours = 1.5,
                weekday = 'Saturday',
            })

            local csv_data = cli.export_data({
                format = 'csv',
                year = '2022',
                week = '52',
            })

            assert.is_string(csv_data)
            assert.is_true(csv_data:find('Weekday,Project,File,Hours,Start,End') ~= nil)
            assert.is_true(csv_data:find('Saturday,TestProject,test.lua,1.5') ~= nil)
        end)

        it('should export data in Markdown format', function()
            -- Add test data
            cli.add_time_entry({
                project = 'TestProject',
                file = 'test.lua',
                hours = 1.5,
                weekday = 'Saturday',
            })

            local md_data = cli.export_data({
                format = 'markdown',
                year = '2022',
                week = '52',
            })

            assert.is_string(md_data)
            assert.is_true(
                md_data:find('| Weekday | Project | File | Hours | Start | End |') ~= nil
            )
            assert.is_true(md_data:find('| Saturday | TestProject | test.lua | 1.5 |') ~= nil)
        end)

        it('should validate time data', function()
            -- Add valid test data
            cli.add_time_entry({
                project = 'TestProject',
                file = 'test.lua',
                hours = 2.0,
                weekday = 'Saturday',
            })

            local results = cli.validate_data()

            assert.is_table(results)
            assert.is_table(results.summary)
            assert.are.equal(0, results.summary.total_issues)
            assert.are.equal(0, results.summary.total_errors)
        end)

        it('should get status information', function()
            local status = cli.get_status()

            assert.is_table(status)
            assert.is_string(status.data_file)
            assert.are.equal('2022', status.current_year)
            assert.are.equal('52', status.current_week)
            assert.are.equal('Saturday', status.current_weekday)
            assert.is_table(status.hours_per_weekday)
            assert.is_table(status.current_week_summary)
        end)
    end)

    describe('CLI Error Handling', function()
        it('should handle missing parameters for add_time_entry', function()
            assert.has_error(function()
                cli.add_time_entry({
                    project = 'TestProject',
                    -- missing file and hours
                })
            end, 'project, file, and hours are required')
        end)

        it('should handle invalid export format', function()
            assert.has_error(function()
                cli.export_data({ format = 'invalid' })
            end, 'Unsupported format: invalid')
        end)
    end)
end)
