local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os_module = require('os')
local Path = require('plenary.path')

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

describe('Weekly Overview Functionality', function()
    describe('getWeeklySummary', function()
        it('should return empty summary for week with no data', function()
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

            local summary = maorunTime.getWeeklySummary()

            assert.are.equal('2023', summary.year)
            assert.are.equal('11', summary.week)
            assert.are.equal(0, summary.totals.totalHours)
            assert.are.equal(40, summary.totals.expectedHours) -- 5 * 8 hours default
            assert.are.equal(-40, summary.totals.totalOvertime)

            -- Check all weekdays are present with correct structure
            local weekdays =
                { 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' }
            for _, weekday in ipairs(weekdays) do
                assert.is_not_nil(summary.weekdays[weekday])
                assert.are.equal(0, summary.weekdays[weekday].workedHours)
                local expected = (weekday == 'Saturday' or weekday == 'Sunday') and 0 or 8
                assert.are.equal(expected, summary.weekdays[weekday].expectedHours)
                assert.are.equal(-expected, summary.weekdays[weekday].overtime)
                assert.is_table(summary.weekdays[weekday].projects)
            end
        end)

        it('should calculate summary correctly with actual time data', function()
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

            -- Add test data for Monday
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600 * 6, -- 6 hours
                weekday = 'Monday',
                project = 'TestProject',
                file = 'main.lua',
            })

            -- Add test data for Tuesday
            maorunTime.addManualTimeEntry({
                startTime = mock_time + 86400, -- Next day
                endTime = mock_time + 86400 + 3600 * 9, -- 9 hours
                weekday = 'Tuesday',
                project = 'TestProject',
                file = 'test.lua',
            })

            local summary = maorunTime.getWeeklySummary()

            assert.are.equal('2023', summary.year)
            assert.are.equal('11', summary.week)
            assert.are.equal(15, summary.totals.totalHours) -- 6 + 9
            assert.are.equal(40, summary.totals.expectedHours)
            assert.are.equal(-25, summary.totals.totalOvertime) -- 15 - 40

            -- Check Monday
            assert.are.equal(6, summary.weekdays.Monday.workedHours)
            assert.are.equal(8, summary.weekdays.Monday.expectedHours)
            assert.are.equal(-2, summary.weekdays.Monday.overtime) -- 6 - 8

            -- Check Tuesday
            assert.are.equal(9, summary.weekdays.Tuesday.workedHours)
            assert.are.equal(8, summary.weekdays.Tuesday.expectedHours)
            assert.are.equal(1, summary.weekdays.Tuesday.overtime) -- 9 - 8

            -- Check project data
            assert.is_not_nil(summary.weekdays.Monday.projects.TestProject)
            assert.are.equal(6, summary.weekdays.Monday.projects.TestProject.hours)
            assert.are.equal(6, summary.weekdays.Monday.projects.TestProject.files['main.lua'])

            assert.is_not_nil(summary.weekdays.Tuesday.projects.TestProject)
            assert.are.equal(9, summary.weekdays.Tuesday.projects.TestProject.hours)
            assert.are.equal(9, summary.weekdays.Tuesday.projects.TestProject.files['test.lua'])
        end)

        it('should filter by project correctly', function()
            local mock_time = 1678704000
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add data for two different projects
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600 * 4, -- 4 hours
                weekday = 'Monday',
                project = 'ProjectA',
                file = 'main.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = mock_time + 3600 * 4,
                endTime = mock_time + 3600 * 8, -- 4 more hours
                weekday = 'Monday',
                project = 'ProjectB',
                file = 'test.lua',
            })

            -- Test filtering by ProjectA
            local summary = maorunTime.getWeeklySummary({ project = 'ProjectA' })

            assert.are.equal(4, summary.totals.totalHours)
            assert.are.equal(4, summary.weekdays.Monday.workedHours)
            assert.are.equal(-4, summary.weekdays.Monday.overtime) -- 4 - 8

            -- Should only have ProjectA
            assert.is_not_nil(summary.weekdays.Monday.projects.ProjectA)
            assert.is_nil(summary.weekdays.Monday.projects.ProjectB)
        end)

        it('should filter by file correctly', function()
            local mock_time = 1678704000
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add data for same project, different files
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600 * 3, -- 3 hours
                weekday = 'Monday',
                project = 'TestProject',
                file = 'main.lua',
            })

            maorunTime.addManualTimeEntry({
                startTime = mock_time + 3600 * 3,
                endTime = mock_time + 3600 * 6, -- 3 more hours
                weekday = 'Monday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Test filtering by main.lua
            local summary = maorunTime.getWeeklySummary({ file = 'main.lua' })

            assert.are.equal(3, summary.totals.totalHours)
            assert.are.equal(3, summary.weekdays.Monday.workedHours)
            assert.are.equal(-5, summary.weekdays.Monday.overtime) -- 3 - 8

            -- Should only have main.lua
            assert.is_not_nil(summary.weekdays.Monday.projects.TestProject)
            assert.are.equal(3, summary.weekdays.Monday.projects.TestProject.files['main.lua'])
            assert.is_nil(summary.weekdays.Monday.projects.TestProject.files['test.lua'])
        end)

        it('should handle specific year and week parameters', function()
            local mock_time = 1678704000 -- March 13, 2023, week 11
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add data for current week
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600 * 8,
                weekday = 'Monday',
                project = 'TestProject',
                file = 'main.lua',
            })

            -- Test getting summary for a different week (should be empty)
            local summary = maorunTime.getWeeklySummary({ year = '2023', week = '10' })

            assert.are.equal('2023', summary.year)
            assert.are.equal('10', summary.week)
            assert.are.equal(0, summary.totals.totalHours)
            assert.are.equal(40, summary.totals.expectedHours)

            -- Test getting summary for current week explicitly
            local current_summary = maorunTime.getWeeklySummary({ year = '2023', week = '11' })

            assert.are.equal('2023', current_summary.year)
            assert.are.equal('11', current_summary.week)
            assert.are.equal(8, current_summary.totals.totalHours)
        end)

        it('should handle custom hoursPerWeekday configuration', function()
            local mock_time = 1678704000
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            -- Setup with custom hours per weekday
            maorunTime.setup({
                path = tempPath,
                hoursPerWeekday = {
                    Monday = 6,
                    Tuesday = 7,
                    Wednesday = 8,
                    Thursday = 8,
                    Friday = 5,
                    Saturday = 0,
                    Sunday = 0,
                },
            })

            -- Add 8 hours on Monday
            maorunTime.addManualTimeEntry({
                startTime = mock_time,
                endTime = mock_time + 3600 * 8,
                weekday = 'Monday',
                project = 'TestProject',
                file = 'main.lua',
            })

            local summary = maorunTime.getWeeklySummary()

            assert.are.equal(8, summary.totals.totalHours)
            assert.are.equal(34, summary.totals.expectedHours) -- 6+7+8+8+5+0+0
            assert.are.equal(-26, summary.totals.totalOvertime) -- 8 - 34

            -- Monday should show 2 hours overtime (8 worked - 6 expected)
            assert.are.equal(8, summary.weekdays.Monday.workedHours)
            assert.are.equal(6, summary.weekdays.Monday.expectedHours)
            assert.are.equal(2, summary.weekdays.Monday.overtime)

            -- Tuesday should show negative overtime (0 worked - 7 expected)
            assert.are.equal(0, summary.weekdays.Tuesday.workedHours)
            assert.are.equal(7, summary.weekdays.Tuesday.expectedHours)
            assert.are.equal(-7, summary.weekdays.Tuesday.overtime)
        end)
    end)

    describe('showWeeklyOverview integration', function()
        it('should expose weeklyOverview function in Time global object', function()
            maorunTime.setup({ path = tempPath })

            assert.is_function(Time.weeklyOverview)
        end)

        it('should expose showWeeklyOverview function in module', function()
            maorunTime.setup({ path = tempPath })

            assert.is_function(maorunTime.showWeeklyOverview)
        end)

        it('should expose getWeeklySummary function in module', function()
            maorunTime.setup({ path = tempPath })

            assert.is_function(maorunTime.getWeeklySummary)
        end)
    end)
end)
