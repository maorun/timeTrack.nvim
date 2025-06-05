local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os = require('os')
local Path = require('plenary.path') -- Added for file manipulation
local tempPath

-- Store original os functions
local original_os_date = os.date
local original_os_time = os.time

before_each(function()
    tempPath = os.tmpname()
    -- Mock os.time and os.date for setup if needed, or rely on test-specific mocks
end)
after_each(function()
    os.remove(tempPath)
    -- Restore original os functions
    os.date = original_os_date
    os.time = original_os_time
end)

describe('calculate', function()
    it('should calculate correct', function()
        -- Mock os.time and os.date for this test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({
            path = tempPath,
        })
        local data = maorunTime.calculate() -- Uses mocked os.date for year/week

        local expected_year_key = '2023'
        local expected_week_key = '11'

        -- Check the nested structure for weekdays
        local year_data = data.content.data[expected_year_key]
        local week_data = year_data and year_data[expected_week_key]
        local project_data = week_data and week_data['default_project']
        local file_data = project_data and project_data['default_file']
        assert.are.same({}, file_data and file_data.weekdays or nil)

        local targetWeekday = 'Monday'
        maorunTime.addTime({ time = 2, weekday = targetWeekday }) -- addTime uses mocked os.time

        data = maorunTime.calculate() -- Uses mocked os.date for year/week

        assert.are.same(
            -6,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour,
            'Daily overhour for ' .. targetWeekday
        )
        assert.are.same(
            -6,
            data.content.data[expected_year_key][expected_week_key].summary.overhour,
            'Weekly overhour'
        )
        assert.are.same(
            2,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.diffInHours
        )
        assert.are.same(
            -6,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour
        )
        assert.are.same(
            2,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
    end)

    it('should calculate correctly with custom hoursPerWeekday', function()
        -- Mock os.time and os.date for this test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        local customHours = {
            Monday = 8,
            Tuesday = 6,
            Wednesday = 8,
            Thursday = 8,
            Friday = 4,
            Saturday = 0,
            Sunday = 0,
        }
        maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = customHours,
        })

        local targetWeekday = 'Tuesday'
        local expected_year_key = '2023'
        local expected_week_key = '11'

        maorunTime.addTime({ time = 7, weekday = targetWeekday }) -- addTime uses mocked os.time

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        -- Assertions
        assert.are.same(
            7,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.diffInHours
        )
        assert.are.same(
            1,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour
        )
        assert.are.same(1, data.content.data[expected_year_key][expected_week_key].summary.overhour)
    end)

    it('should sum multiple entries for a single day', function()
        -- Mock os.time and os.date for this test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({
            path = tempPath, -- Default hoursPerWeekday (8 hours per day)
        })

        local targetWeekday = 'Monday'
        local expected_year_key = '2023'
        local expected_week_key = '11'

        maorunTime.addTime({ time = 2, weekday = targetWeekday }) -- addTime uses mocked os.time
        maorunTime.addTime({ time = 3, weekday = targetWeekday }) -- addTime uses mocked os.time

        local data = maorunTime.calculate() -- calculate uses mocked os.time for default year/week

        -- Assertions for targetWeekday
        assert.are.same(
            5,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.diffInHours
        )
        assert.are.same(
            -3,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour
        )
        -- Assertion for total summary
        assert.are.same(
            -3,
            data.content.data[expected_year_key][expected_week_key].summary.overhour
        )
    end)

    it('should calculate correctly with entries on multiple days', function()
        -- Mock os.time and os.date for this test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({
            path = tempPath, -- Default hoursPerWeekday (8 hours per day)
        })

        local weekday1 = 'Wednesday'
        local weekday2 = 'Thursday'
        local expected_year_key = '2023'
        local expected_week_key = '11'

        maorunTime.addTime({ time = 7, weekday = weekday1 }) -- addTime uses mocked os.time
        maorunTime.addTime({ time = 9, weekday = weekday2 }) -- addTime uses mocked os.time

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        -- Assertions for weekday1 (Wednesday)
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday1],
            'Data for weekday1 should exist'
        )
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday1].summary,
            'Summary for weekday1 should exist'
        )
        assert.are.same(
            7,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday1].summary.diffInHours
        )
        assert.are.same(
            -1,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday1].summary.overhour
        )

        -- Assertions for weekday2 (Thursday)
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday2],
            'Data for weekday2 should exist'
        )
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday2].summary,
            'Summary for weekday2 should exist'
        )
        assert.are.same(
            9,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday2].summary.diffInHours
        )
        assert.are.same(
            1,
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[weekday2].summary.overhour
        )

        -- Assertion for total summary
        assert.are.same(0, data.content.data[expected_year_key][expected_week_key].summary.overhour)
    end)

    it('should incorporate prevWeekOverhour into current week calculation', function()
        -- Mock os.time and os.date for addTime call
        local mock_time_for_addTime = 1671022800 -- Wed, Dec 14, 2022 12:00:00 PM GMT (Year 2022, Week 50)
        os.time = function()
            return mock_time_for_addTime
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_time_for_addTime
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath }) -- setup uses mocked time for its internal os.date calls if any
        local initialContentJson = Path:new(tempPath):read()
        initialContentJson = initialContentJson == '' and '{}' or initialContentJson
        local initialContent = vim.json.decode(initialContentJson)

        local currentYearForFile = '2022' -- Year of the mocked time for addTime
        local currentWeekNumForFile = tonumber(original_os_date('%W', mock_time_for_addTime)) -- Week 50
        local currentWeekStringForFile = original_os_date('%W', mock_time_for_addTime) -- "50"

        -- Modify skip condition to use original_os_date with the mocked time
        if currentWeekNumForFile <= 1 then
            print(
                "Skipping 'prevWeekOverhour' test as current week is "
                    .. currentWeekStringForFile
                    .. ' in '
                    .. currentYearForFile
                    .. '.'
            )
            return -- Skip the rest of this test
        end

        local prevWeekString = string.format('%02d', currentWeekNumForFile - 1) -- "49"
        local prevWeekOverhourValue = 5

        local fileData = vim.deepcopy(initialContent)
        fileData.data = fileData.data or {}
        fileData.data[currentYearForFile] = fileData.data[currentYearForFile] or {}
        fileData.data[currentYearForFile][prevWeekString] = {
            summary = { overhour = prevWeekOverhourValue },
        }

        if not fileData.data[currentYearForFile][currentWeekStringForFile] then
            fileData.data[currentYearForFile][currentWeekStringForFile] = {
                ['default_project'] = { ['default_file'] = { weekdays = {} } },
            }
        elseif
            not fileData.data[currentYearForFile][currentWeekStringForFile]['default_project']
        then
            fileData.data[currentYearForFile][currentWeekStringForFile]['default_project'] = {
                ['default_file'] = { weekdays = {} },
            }
        elseif
            not fileData.data[currentYearForFile][currentWeekStringForFile]['default_project']['default_file']
        then
            fileData.data[currentYearForFile][currentWeekStringForFile]['default_project']['default_file'] =
                { weekdays = {} }
        end
        fileData.paused = initialContent.paused or false
        Path:new(tempPath):write(vim.fn.json_encode(fileData), 'w')

        local dayToLog = 'Monday' -- Target day for addTime (Dec 12, 2022)
        maorunTime.addTime({ time = 6, weekday = dayToLog }) -- This logs 6 hours -> -2 for the day, uses mocked time

        -- calculate() will use the mocked os.time (Dec 14, 2022), so year "2022", week "50"
        local data = maorunTime.calculate()

        local yearFromMock = '2022' -- Expected from mocked time
        local weekFromMock = '50' -- Expected from mocked time

        assert.are.same(
            -2,
            data.content.data[yearFromMock][weekFromMock]['default_project']['default_file'].weekdays[dayToLog].summary.overhour
        )
        assert.are.same(
            prevWeekOverhourValue - 2, -- 5 - 2 = 3
            data.content.data[yearFromMock][weekFromMock].summary.overhour
        )
    end)

    it('should calculate correctly for a specific year and weeknumber option', function()
        -- This test does not need os.time mocking for addTime, as it writes data directly.
        -- os.time/os.date for calculate are overridden by options.
        maorunTime.setup({ path = tempPath })
        local initialContentJson = Path:new(tempPath):read()
        initialContentJson = initialContentJson == '' and '{}' or initialContentJson
        local fileContent = vim.json.decode(initialContentJson)

        local testYear = '2022'
        local testWeek = '30' -- July 27, 2022 is a Wednesday in Week 30
        local testWeekday = 'Wednesday'
        local loggedHours = 10

        local hoursForTestWeekday = (
            fileContent.hoursPerWeekday and fileContent.hoursPerWeekday[testWeekday]
        ) or 8
        local expectedDailyOvertime = loggedHours - hoursForTestWeekday

        fileContent.data = fileContent.data or {}
        fileContent.data[testYear] = fileContent.data[testYear] or {}

        -- Use fixed timestamps for startTime and endTime
        local fixedStartTime = 1658905200 -- July 27, 2022 09:00:00 GMT
        local fixedEndTime = fixedStartTime + loggedHours * 3600

        fileContent.data[testYear][testWeek] = {
            ['default_project'] = {
                ['default_file'] = {
                    weekdays = {
                        [testWeekday] = {
                            items = {
                                {
                                    startTime = fixedStartTime,
                                    endTime = fixedEndTime,
                                    diffInHours = loggedHours,
                                },
                            },
                        },
                    },
                },
            },
        }
        Path:new(tempPath):write(vim.fn.json_encode(fileContent), 'w')

        local data = maorunTime.calculate({ year = testYear, weeknumber = testWeek })

        -- Assertions
        assert.is_not_nil(data.content.data, 'data.content.data should exist')
        assert.is_not_nil(
            data.content.data[testYear],
            'Data for year ' .. testYear .. ' should exist'
        )
        local weekData = data.content.data[testYear][testWeek]
        assert.is_not_nil(
            weekData,
            'Data for ' .. testYear .. ' week ' .. testWeek .. ' should exist'
        )
        assert.is_not_nil(
            weekData['default_project']['default_file'].weekdays,
            'weekData.weekdays should exist'
        )
        local weekdayData = weekData['default_project']['default_file'].weekdays[testWeekday]
        assert.is_not_nil(weekdayData, 'Data for ' .. testWeekday .. ' should exist')
        assert.are.same(
            loggedHours,
            weekdayData.summary.diffInHours,
            'Logged hours for ' .. testWeekday
        )
        assert.are.same(
            expectedDailyOvertime,
            weekdayData.summary.overhour,
            'Overtime for ' .. testWeekday
        )
        assert.are.same(expectedDailyOvertime, weekData.summary.overhour, 'Total weekly overtime')
    end)

    it('should return zero totals for a week with no logged time', function()
        -- Mock os.time and os.date for this test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })

        local expected_year_key = '2023'
        local expected_week_key = '11'

        local data = maorunTime.calculate() -- Uses mocked os.date for year/week

        -- Assertions
        local weekData = data.content.data[expected_year_key][expected_week_key]
        assert.is_not_nil(weekData, 'Week data should exist even if no time logged')
        assert.is_not_nil(weekData.summary, 'Week summary should exist')

        local projectData = weekData['default_project']
        assert.is_not_nil(projectData, 'Default project data should exist')
        local fileData = projectData['default_file']
        assert.is_not_nil(fileData, 'Default file data should exist')
        assert.is_not_nil(fileData.weekdays, 'Weekdays table should exist in default project/file')

        assert.are.same(
            0,
            weekData.summary.overhour,
            'Weekly overhour should be 0 for an empty week with no prior history'
        )
        assert.are.same(0, vim.tbl_count(fileData.weekdays), 'Weekdays table should be empty')
    end)

    it('should treat all logged time as overtime if weekday configured for zero hours', function()
        -- Mock os.time and os.date for this test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        local targetWeekday = 'Saturday'
        local loggedHours = 2

        local customHours = {
            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 8,
            Saturday = 0,
            Sunday = 0,
        }

        maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = customHours,
        })

        local expected_year_key = '2023'
        -- Saturday, Mar 18, 2023 is in week 11 (mocked time is Wed, Mar 15)
        local expected_week_key = '11'

        maorunTime.addTime({ time = loggedHours, weekday = targetWeekday }) -- addTime uses mocked os.time
        
        -- Assertions
        local weekData = data.content.data[expected_year_key][expected_week_key]
        assert.is_not_nil(weekData, 'Week data should exist')

        local weekdayData = weekData['default_project']['default_file'].weekdays[targetWeekday]
        assert.is_not_nil(weekdayData, 'Data for ' .. targetWeekday .. ' should exist')
        assert.is_not_nil(weekdayData.summary, 'Summary for ' .. targetWeekday .. ' should exist')

        assert.are.same(
            loggedHours,
            weekdayData.summary.diffInHours,
            'Logged hours for ' .. targetWeekday
        )
        assert.are.same(
            loggedHours,
            weekdayData.summary.overhour,
            'Overtime for ' .. targetWeekday .. ' (configured for 0 hours)'
        )
        assert.are.same(
            loggedHours,
            weekData.summary.overhour,
            'Weekly overhour should reflect the ' .. targetWeekday .. ' overtime'
        )
    end)
end)

describe('setIllDay', function()
    it('should add the average time on a specific weekday', function()
        -- Mock os.time and os.date for the entire test
        local mock_fixed_time = 1678886400 -- Wed, Mar 15, 2023 12:00:00 PM GMT
        os.time = function()
            return mock_fixed_time
        end
        os.date = function(format, time_val)
            time_val = time_val or mock_fixed_time
            return original_os_date(format, time_val)
        end

        maorunTime.setup({ path = tempPath })

        local targetWeekdayForAvg = 'Monday'
        local expected_year_key = '2023'
        local expected_week_key = '11' -- Monday, Mar 13, 2023 is in week 11

        maorunTime.setIllDay(targetWeekdayForAvg) -- Uses mocked os.time

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })
        local expected_avg = 40 / 7
        local actual_avg =
            data.content.data[expected_year_key][expected_week_key]['default_project']['default_file'].weekdays[targetWeekdayForAvg].items[1].diffInHours
        assert(
            math.abs(expected_avg - actual_avg) < 0.001,
            string.format(
                'Average hours for default config on %s. Expected close to %s, got %s',
                targetWeekdayForAvg,
                expected_avg,
                actual_avg
            )
        )

        -- Re-setup for custom hours, mocked time still applies
        maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = {
                Monday = 8,
                Tuesday = 8,
                Wednesday = 8,
                Thursday = 7,
                Friday = 5, -- Sum = 36, Count = 5, Avg = 7.2
            },
        })

        local targetCustomWeekday = 'Friday'
        local expected_year_key_2 = '2023'
        local expected_week_key_2 = '11' -- Friday, Mar 17, 2023 is in week 11

        maorunTime.setIllDay(targetCustomWeekday) -- Uses mocked os.time

        data =
            maorunTime.calculate({ year = expected_year_key_2, weeknumber = expected_week_key_2 })
        local actual_value_custom =
            data.content.data[expected_year_key_2][expected_week_key_2]['default_project']['default_file'].weekdays[targetCustomWeekday].items[1].diffInHours
        assert(
            math.abs(7.2 - actual_value_custom) < 0.001,
            string.format(
                'Expected hours for %s to be close to 7.2, got %s',
                targetCustomWeekday,
                actual_value_custom
            )
        )
    end)
end)
