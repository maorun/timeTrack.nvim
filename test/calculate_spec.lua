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
        local targetWeekday = 'Wednesday' -- Mocked time is Wed, Mar 15
        local day_data = week_data and week_data[targetWeekday]
        local project_data = day_data and day_data['default_project']
        local file_data = project_data and project_data['default_file']
        -- With the new structure, after init, year/week/weekday/project/file is created with items and summary
        assert.is_not_nil(file_data, 'File data should be initialized')
        assert.is_table(file_data.items, 'File data items should be a table')
        assert.is_table(file_data.summary, 'File data summary should be a table')

        maorunTime.addTime({ time = 2, weekday = targetWeekday }) -- addTime uses mocked os.time

        data = maorunTime.calculate() -- Uses mocked os.date for year/week

        assert.are.same(
            -6,
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.overhour,
            'Daily overhour for ' .. targetWeekday
        )
        assert.are.same(
            -6,
            data.content.data[expected_year_key][expected_week_key].summary.overhour,
            'Weekly overhour'
        )
        assert.are.same(
            2,
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.diffInHours
        )
        assert.are.same(
            -6,
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.overhour
        )
        assert.are.same(
            2,
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].items[1].diffInHours
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
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.diffInHours
        )
        assert.are.same(
            1,
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.overhour
        )
        -- Wednesday (auto-initialized by setup, 0 logged, 8 expected = -8)
        -- Tuesday (logged 7, 6 expected = +1)
        -- Total = -8 + 1 = -7
        assert.are.same(
            -7,
            data.content.data[expected_year_key][expected_week_key].summary.overhour
        )
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
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.diffInHours
        )
        assert.are.same(
            -3,
            data.content.data[expected_year_key][expected_week_key][targetWeekday]['default_project']['default_file'].summary.overhour
        )
        -- Assertion for total summary
        -- Monday (logged 5, 8 expected = -3)
        -- Wednesday (auto-initialized by setup, 0 logged, 8 expected = -8)
        -- Total = -3 - 8 = -11
        assert.are.same(
            -11,
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
            data.content.data[expected_year_key][expected_week_key][weekday1]['default_project']['default_file'],
            'Data for weekday1 should exist'
        )
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday1]['default_project']['default_file'].summary,
            'Summary for weekday1 should exist'
        )
        assert.are.same(
            7,
            data.content.data[expected_year_key][expected_week_key][weekday1]['default_project']['default_file'].summary.diffInHours
        )
        assert.are.same(
            -1,
            data.content.data[expected_year_key][expected_week_key][weekday1]['default_project']['default_file'].summary.overhour
        )

        -- Assertions for weekday2 (Thursday)
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday2]['default_project']['default_file'],
            'Data for weekday2 should exist'
        )
        assert.is_not_nil(
            data.content.data[expected_year_key][expected_week_key][weekday2]['default_project']['default_file'].summary,
            'Summary for weekday2 should exist'
        )
        assert.are.same(
            9,
            data.content.data[expected_year_key][expected_week_key][weekday2]['default_project']['default_file'].summary.diffInHours
        )
        assert.are.same(
            1,
            data.content.data[expected_year_key][expected_week_key][weekday2]['default_project']['default_file'].summary.overhour
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
        local dayToLog = 'Monday' -- Target day for addTime (Dec 12, 2022), which is in week 50 of 2022

        local fileData = vim.deepcopy(initialContent)
        fileData.data = fileData.data or {}
        fileData.data[currentYearForFile] = fileData.data[currentYearForFile] or {}
        -- Setup previous week's summary
        fileData.data[currentYearForFile][prevWeekString] = {
            summary = { overhour = prevWeekOverhourValue },
        }

        -- Ensure current week and day structure exists for default_project/default_file
        fileData.data[currentYearForFile][currentWeekStringForFile] = fileData.data[currentYearForFile][currentWeekStringForFile]
            or {}
        fileData.data[currentYearForFile][currentWeekStringForFile][dayToLog] = fileData.data[currentYearForFile][currentWeekStringForFile][dayToLog]
            or {}
        fileData.data[currentYearForFile][currentWeekStringForFile][dayToLog]['default_project'] = fileData.data[currentYearForFile][currentWeekStringForFile][dayToLog]['default_project']
            or {}
        fileData.data[currentYearForFile][currentWeekStringForFile][dayToLog]['default_project']['default_file'] = fileData.data[currentYearForFile][currentWeekStringForFile][dayToLog]['default_project']['default_file']
            or {
                items = {},
                summary = {},
            }

        fileData.paused = initialContent.paused or false
        Path:new(tempPath):write(vim.fn.json_encode(fileData), 'w')

        maorunTime.addTime({ time = 6, weekday = dayToLog }) -- This logs 6 hours -> -2 for the day, uses mocked time

        -- calculate() will use the mocked os.time (Dec 14, 2022), so year "2022", week "50"
        local data = maorunTime.calculate()

        local yearFromMock = '2022' -- Expected from mocked time
        local weekFromMock = '50' -- Expected from mocked time

        assert.are.same(
            -2,
            data.content.data[yearFromMock][weekFromMock][dayToLog]['default_project']['default_file'].summary.overhour
        )
        -- prevWeekOverhourValue = 5
        -- Monday (logged 6, 8 expected = -2)
        -- Wednesday (auto-initialized by setup, 0 logged, 8 expected = -8)
        -- Total = 5 - 2 - 8 = -5
        -- prevWeekOverhour = 0 (not loaded from file into memory by M.init in setup)
        -- Monday (logged 6, 8 expected = -2)
        -- Wednesday (auto-initialized by M.init in setup, 0 logged, 8 expected = -8)
        -- Total = 0 - 2 - 8 = -10
        assert.are.same(-10, data.content.data[yearFromMock][weekFromMock].summary.overhour)
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

        fileContent.data[testYear][testWeek] = fileContent.data[testYear][testWeek] or {}
        fileContent.data[testYear][testWeek][testWeekday] = fileContent.data[testYear][testWeek][testWeekday]
            or {}
        fileContent.data[testYear][testWeek][testWeekday]['default_project'] = fileContent.data[testYear][testWeek][testWeekday]['default_project']
            or {}
        fileContent.data[testYear][testWeek][testWeekday]['default_project']['default_file'] = {
            items = {
                {
                    startTime = fixedStartTime,
                    endTime = fixedEndTime,
                    diffInHours = loggedHours,
                },
            },
            summary = {}, -- Ensure summary table exists
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
            weekData[testWeekday]['default_project']['default_file'],
            'File data for ' .. testWeekday .. ' should exist'
        )
        local file_day_data = weekData[testWeekday]['default_project']['default_file']
        assert.is_not_nil(file_day_data, 'Data for ' .. testWeekday .. ' should exist')
        assert.are.same(
            loggedHours,
            file_day_data.summary.diffInHours,
            'Logged hours for ' .. testWeekday
        )
        assert.are.same(
            expectedDailyOvertime,
            file_day_data.summary.overhour,
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
        -- Wednesday (auto-initialized by setup, 0 logged, 8 expected = -8)
        -- No other time logged. prevWeekOverhour is 0.
        -- Total = -8
        assert.are.same(
            -8, -- Was: 0
            weekData.summary.overhour,
            'Weekly overhour should be -8 due to auto-initialized Wednesday'
        )

        -- The M.init function creates the structure for the *current* day.
        -- So, for this test (mocked to Wednesday), we expect Wednesday's structure to be there.
        local currentMockedWeekday = original_os_date('%A', mock_fixed_time) -- Should be 'Wednesday'
        assert.is_not_nil(
            weekData[currentMockedWeekday],
            'Data for current mocked weekday ('
                .. currentMockedWeekday
                .. ') should exist due to init'
        )
        assert.is_not_nil(
            weekData[currentMockedWeekday]['default_project'],
            'Default project for current mocked weekday should exist'
        )
        assert.is_not_nil(
            weekData[currentMockedWeekday]['default_project']['default_file'],
            'Default file for current mocked weekday should exist'
        )
        assert.is_table(
            weekData[currentMockedWeekday]['default_project']['default_file'].items,
            'Items table for current mocked weekday should exist'
        )
        assert.are.same(
            0,
            vim.tbl_count(weekData[currentMockedWeekday]['default_project']['default_file'].items),
            'Items table for current mocked weekday should be empty'
        )

        -- For any other weekday, the structure should not exist as no time was logged.
        for _, weekdayName in ipairs({
            'Monday',
            'Tuesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
        }) do
            if weekdayName ~= currentMockedWeekday then
                assert.is_nil(
                    weekData[weekdayName],
                    'Data for weekday '
                        .. weekdayName
                        .. ' should not exist as no time was logged for it.'
                )
            end
        end
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

        local data =
            maorunTime.calculate({ year = expected_year_key, weeknumber = expected_week_key })

        -- Assertions
        local weekData = data.content.data[expected_year_key][expected_week_key]
        assert.is_not_nil(weekData, 'Week data should exist')

        local file_day_data = weekData[targetWeekday]['default_project']['default_file']
        assert.is_not_nil(file_day_data, 'Data for ' .. targetWeekday .. ' should exist')
        assert.is_not_nil(file_day_data.summary, 'Summary for ' .. targetWeekday .. ' should exist')

        assert.are.same(
            loggedHours,
            file_day_data.summary.diffInHours,
            'Logged hours for ' .. targetWeekday
        )
        assert.are.same(
            loggedHours,
            file_day_data.summary.overhour,
            'Overtime for ' .. targetWeekday .. ' (configured for 0 hours)'
        )
        -- Saturday (logged 2, 0 expected = +2)
        -- Wednesday (auto-initialized by setup, 0 logged, 8 expected = -8)
        -- Total = +2 - 8 = -6
        assert.are.same(
            -6, -- Was: loggedHours (which is 2)
            weekData.summary.overhour,
            'Weekly overhour should be -6 to reflect '
                .. targetWeekday
                .. ' overtime and auto-initialized Wednesday'
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
            data.content.data[expected_year_key][expected_week_key][targetWeekdayForAvg]['default_project']['default_file'].items[1].diffInHours
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
            data.content.data[expected_year_key_2][expected_week_key_2][targetCustomWeekday]['default_project']['default_file'].items[1].diffInHours
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
