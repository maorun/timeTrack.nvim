local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os = require('os')
local Path = require('plenary.path') -- Added for file manipulation
local tempPath

before_each(function()
    tempPath = os.tmpname()
end)
after_each(function()
    os.remove(tempPath)
end)

describe('calculate', function()
    it('should calculate correct', function()
        maorunTime.setup({
            path = tempPath,
        })
        local data = maorunTime.calculate()
        -- Check the nested structure for weekdays
        -- After setup and calculate on an empty file, the structure should include default project/file path
        -- and the weekdays table under it should be empty.
        local year_data = data.content.data[os.date('%Y')]
        local week_data = year_data and year_data[os.date('%W')]
        local project_data = week_data and week_data['default_project']
        local file_data = project_data and project_data['default_file']
        assert.are.same({}, file_data and file_data.weekdays or nil)

        local targetWeekday = 'Monday'
        maorunTime.addTime({ time = 2, weekday = targetWeekday })

        data = maorunTime.calculate()

        local year = os.date('%Y')
        local week = os.date('%W')

        assert.are.same(
            -6,
            data.content.data[year][week]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour,
            'Daily overhour for ' .. targetWeekday
        )
        assert.are.same(-6, data.content.data[year][week].summary.overhour, 'Weekly overhour') -- Week summary path is correct
        assert.are.same(
            2,
            data.content.data[year][week]['default_project']['default_file'].weekdays[targetWeekday].summary.diffInHours
        )
        assert.are.same(
            -6,
            data.content.data[year][week]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour
        )
        assert.are.same(
            2,
            data.content.data[year][week]['default_project']['default_file'].weekdays[targetWeekday].items[1].diffInHours
        )
    end)

    it('should calculate correctly with custom hoursPerWeekday', function()
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

        local targetWeekday = 'Tuesday' -- Hardcode for predictability
        local currentYear = os.date('%Y')
        local currentWeek = os.date('%W')

        maorunTime.addTime({ time = 7, weekday = targetWeekday })

        local data = maorunTime.calculate()

        -- Assertions
        assert.are.same(
            7,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[targetWeekday].summary.diffInHours
        )
        assert.are.same(
            1,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour
        )
        assert.are.same(1, data.content.data[currentYear][currentWeek].summary.overhour) -- Week summary path
    end)

    it('should sum multiple entries for a single day', function()
        maorunTime.setup({
            path = tempPath, -- Default hoursPerWeekday (8 hours per day)
        })

        local targetWeekday = 'Monday' -- Hardcode for predictability
        local currentYear = os.date('%Y')
        local currentWeek = os.date('%W')

        maorunTime.addTime({ time = 2, weekday = targetWeekday })
        maorunTime.addTime({ time = 3, weekday = targetWeekday })

        local data = maorunTime.calculate()

        -- Assertions for targetWeekday
        assert.are.same(
            5,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[targetWeekday].summary.diffInHours
        )
        assert.are.same(
            -3,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[targetWeekday].summary.overhour
        )
        -- Assertion for total summary
        assert.are.same(-3, data.content.data[currentYear][currentWeek].summary.overhour) -- Week summary path
    end)

    it('should calculate correctly with entries on multiple days', function()
        maorunTime.setup({
            path = tempPath, -- Default hoursPerWeekday (8 hours per day)
        })

        local weekday1 = 'Monday'
        local weekday2 = 'Tuesday'
        local currentYear = os.date('%Y')
        local currentWeek = os.date('%W')

        maorunTime.addTime({ time = 7, weekday = weekday1 }) -- Monday
        maorunTime.addTime({ time = 9, weekday = weekday2 }) -- Tuesday

        local data = maorunTime.calculate()

        -- Assertions for weekday1 (Monday)
        assert.are.same(
            7,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[weekday1].summary.diffInHours
        )
        assert.are.same(
            -1,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[weekday1].summary.overhour
        )

        -- Assertions for weekday2 (Tuesday)
        assert.are.same(
            9,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[weekday2].summary.diffInHours
        )
        assert.are.same(
            1,
            data.content.data[currentYear][currentWeek]['default_project']['default_file'].weekdays[weekday2].summary.overhour
        )

        -- Assertion for total summary
        assert.are.same(0, data.content.data[currentYear][currentWeek].summary.overhour) -- Week summary path
    end)

    it('should incorporate prevWeekOverhour into current week calculation', function()
        maorunTime.setup({ path = tempPath })
        local initialContentJson = Path:new(tempPath):read()
        if initialContentJson == '' then
            print(
                "Warning (prevWeekOverhour test): tempPath file was empty after setup. Using '{}'."
            )
            initialContentJson = '{}'
        end
        local initialContent = vim.json.decode(initialContentJson)

        local currentYear = os.date('%Y')
        local currentWeekNum = tonumber(os.date('%W'))
        local currentWeekString = os.date('%W')

        if currentWeekNum <= 1 then
            print(
                "Skipping 'prevWeekOverhour' test as current week is "
                    .. currentWeekString
                    .. ' in '
                    .. currentYear
                    .. '.'
            )
            return -- Skip the rest of this test
        end

        local prevWeekString = string.format('%02d', currentWeekNum - 1)
        local prevWeekOverhourValue = 5

        -- Prepare data for the previous week and write it to the file
        local fileData = vim.deepcopy(initialContent) -- Start with what setup wrote to preserve hoursConf etc.
        if not fileData.data then
            fileData.data = {}
        end
        if not fileData.data[currentYear] then
            fileData.data[currentYear] = {}
        end

        fileData.data[currentYear][prevWeekString] = {
            summary = { overhour = prevWeekOverhourValue },
            -- 'weekdays' is not strictly needed here for 'calculate' to read prevWeekOverhour
        }

        -- Ensure current week structure for default project/file exists for addTime to modify.
        -- addTime calls saveTime which initializes the project/file/weekday path.
        -- The week summary is handled by calculate.
        if not fileData.data[currentYear][currentWeekString] then
            fileData.data[currentYear][currentWeekString] = {
                -- summary will be created by calculate if it doesn't exist
                ['default_project'] = {
                    ['default_file'] = {
                        weekdays = {},
                    },
                },
            }
        elseif not fileData.data[currentYear][currentWeekString]['default_project'] then
            fileData.data[currentYear][currentWeekString]['default_project'] = {
                ['default_file'] = {
                    weekdays = {},
                },
            }
        elseif
            not fileData.data[currentYear][currentWeekString]['default_project']['default_file']
        then
            fileData.data[currentYear][currentWeekString]['default_project']['default_file'] =
                { weekdays = {} }
        end

        -- Ensure 'paused' key exists, copying from initialContent or defaulting.
        if initialContent.paused == nil then
            fileData.paused = false -- Default if not in initialContent
        else
            fileData.paused = initialContent.paused
        end

        Path:new(tempPath):write(vim.fn.json_encode(fileData), 'w')

        local dayToLog = 'Monday' -- Default hours for Monday is 8
        maorunTime.addTime({ time = 6, weekday = dayToLog }) -- This logs 6 hours -> -2 for the day

        local data = maorunTime.calculate() -- This uses os.date() for year/week

        local yearFromOS = os.date('%Y')
        local weekFromOS = os.date('%W')

        assert.are.same(
            -2,
            data.content.data[yearFromOS][weekFromOS]['default_project']['default_file'].weekdays[dayToLog].summary.overhour
        )
        assert.are.same(
            prevWeekOverhourValue - 2, -- 5 - 2 = 3
            data.content.data[yearFromOS][weekFromOS].summary.overhour
        )
    end)

    it('should calculate correctly for a specific year and weeknumber option', function()
        maorunTime.setup({ path = tempPath }) -- Initialize to create the file and get default configs
        local initialContentJson = Path:new(tempPath):read()
        if initialContentJson == '' then
            print(
                "Warning (specific year/week test): tempPath file was empty after setup. Using '{}'."
            )
            initialContentJson = '{}'
        end
        local fileContent = vim.json.decode(initialContentJson) -- Get hoursPerWeekday, paused status

        local testYear = '2022'
        local testWeek = '30' -- Corresponds to July 25-31, 2022. Wednesday is July 27th.
        local testWeekday = 'Wednesday'
        local loggedHours = 10

        -- Ensure hoursPerWeekday from setup is used. Default to 8 if somehow not found.
        local hoursForTestWeekday = 8
        if fileContent.hoursPerWeekday and fileContent.hoursPerWeekday[testWeekday] then
            hoursForTestWeekday = fileContent.hoursPerWeekday[testWeekday]
        end
        local expectedDailyOvertime = loggedHours - hoursForTestWeekday

        -- Prepare data for the specific year and week
        if not fileContent.data then
            fileContent.data = {}
        end
        if not fileContent.data[testYear] then
            fileContent.data[testYear] = {}
        end

        fileContent.data[testYear][testWeek] = {
            -- summary will be created by calculate
            ['default_project'] = {
                ['default_file'] = {
                    weekdays = {
                        [testWeekday] = {
                            -- summary for weekday will be created by calculate
                            items = {
                                {
                                    startTime = os.time({
                                        year = 2022,
                                        month = 7,
                                        day = 27,
                                        hour = 9,
                                        min = 0,
                                        sec = 0,
                                    }),
                                    endTime = os.time({
                                        year = 2022,
                                        month = 7,
                                        day = 27,
                                        hour = 9,
                                        min = 0,
                                        sec = 0,
                                    })
                                        + loggedHours * 3600,
                                    diffInHours = loggedHours,
                                },
                            },
                        },
                    },
                },
            },
        }
        Path:new(tempPath):write(vim.fn.json_encode(fileContent), 'w')

        -- Call calculate with options for the specific year and week
        local data = maorunTime.calculate({ year = testYear, weeknumber = testWeek })

        -- Assertions for the specific year and week data
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
            'weekData.weekdays should exist for ' .. testYear .. ' week ' .. testWeek -- Check project/file path
        )
        local weekdayData = weekData['default_project']['default_file'].weekdays[testWeekday]
        assert.is_not_nil(
            weekdayData,
            'Data for '
                .. testWeekday
                .. ' in '
                .. testYear
                .. ' week '
                .. testWeek
                .. ' should exist'
        )

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
        maorunTime.setup({ path = tempPath }) -- Basic setup

        local currentYear = os.date('%Y')
        local currentWeek = os.date('%W')

        -- No time is added. Call calculate directly.
        local data = maorunTime.calculate() -- Uses current year/week by default

        -- Assertions
        local weekData = data.content.data[currentYear][currentWeek]
        assert.is_not_nil(weekData, 'Week data should exist even if no time logged')
        assert.is_not_nil(weekData.summary, 'Week summary should exist')

        local projectData = weekData['default_project']
        assert.is_not_nil(projectData, 'Default project data should exist')
        local fileData = projectData['default_file']
        assert.is_not_nil(fileData, 'Default file data should exist')
        assert.is_not_nil(fileData.weekdays, 'Weekdays table should exist in default project/file')

        assert.are.same(
            0,
            weekData.summary.overhour, -- Week summary path
            'Weekly overhour should be 0 for an empty week with no prior history'
        )

        assert.are.same(0, vim.tbl_count(fileData.weekdays), 'Weekdays table should be empty')
    end)

    it('should treat all logged time as overtime if weekday configured for zero hours', function()
        local targetWeekday = 'Saturday' -- A day often configured for 0 hours
        local loggedHours = 2

        local customHours = {
            Monday = 8,
            Tuesday = 8,
            Wednesday = 8,
            Thursday = 8,
            Friday = 8,
            Saturday = 0, -- Target for this test
            Sunday = 0,
        }

        maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = customHours,
        })

        local currentYear = os.date('%Y')
        local currentWeek = os.date('%W')

        -- Add time to the target weekday
        maorunTime.addTime({ time = loggedHours, weekday = targetWeekday })

        local data = maorunTime.calculate()

        -- Assertions
        local weekData = data.content.data[currentYear][currentWeek]
        assert.is_not_nil(weekData, 'Week data should exist')

        local weekdayData = weekData['default_project']['default_file'].weekdays[targetWeekday]
        assert.is_not_nil(weekdayData, 'Data for ' .. targetWeekday .. ' should exist')
        assert.is_not_nil(weekdayData.summary, 'Summary for ' .. targetWeekday .. ' should exist')

        assert.are.same(
            loggedHours,
            weekdayData.summary.diffInHours,
            'Logged hours for ' .. targetWeekday
        )
        -- Expected overtime is loggedHours - 0 = loggedHours
        assert.are.same(
            loggedHours,
            weekdayData.summary.overhour,
            'Overtime for ' .. targetWeekday .. ' (configured for 0 hours)'
        )

        -- Assuming no other entries and no prevWeekOverhour
        assert.are.same(
            loggedHours,
            weekData.summary.overhour, -- Week summary path
            'Weekly overhour should reflect the ' .. targetWeekday .. ' overtime'
        )
    end)
end)

describe('setIllDay', function()
    it('should add the average time on a specific weekday', function()
        maorunTime.setup({
            path = tempPath,
        })

        local targetWeekdayForAvg = 'Monday'
        local data = maorunTime.setIllDay(targetWeekdayForAvg) -- Uses default project/file
        local expected_avg = 40 / 7
        local actual_avg =
            data.content.data[os.date('%Y')][os.date('%W')]['default_project']['default_file'].weekdays[targetWeekdayForAvg].items[1].diffInHours
        assert(
            math.abs(expected_avg - actual_avg) < 0.001,
            string.format(
                'Average hours for default config on %s. Expected close to %s, got %s',
                targetWeekdayForAvg,
                expected_avg,
                actual_avg
            )
        )

        maorunTime.setup({
            path = tempPath,
            hoursPerWeekday = {
                Monday = 8,
                Tuesday = 8,
                Wednesday = 8,
                Thursday = 7,
                Friday = 5,
            },
        })

        local targetCustomWeekday = 'Friday' -- Using Friday as it has a unique value (5) in this custom map
        local data = maorunTime.setIllDay(targetCustomWeekday) -- Uses default project/file
        assert.are.same(
            7.2, -- This average ( (8+8+8+7+5) / 5 = 36/5 = 7.2 ) should still be correct
            data.content.data[os.date('%Y')][os.date('%W')]['default_project']['default_file'].weekdays[targetCustomWeekday].items[1].diffInHours
        )
    end)
end)
