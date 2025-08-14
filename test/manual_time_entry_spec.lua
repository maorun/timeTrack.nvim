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

describe('Manual Time Entry Management', function()
    describe('addManualTimeEntry', function()
        it('should add a manual time entry with specified start and end times', function()
            -- Mock specific time: Wednesday, March 15, 2023 13:20:00 UTC
            local mock_time = 1678886400
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add manual entry: 10:20 to 13:20 (3 hours)
            local start_time = mock_time - (3 * 60 * 60) -- 10:20
            local end_time = mock_time -- 13:20

            maorunTime.addManualTimeEntry({
                startTime = start_time,
                endTime = end_time,
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })

            local expected_year = '2023'
            local expected_week = '11'
            local data = maorunTime.calculate({ year = expected_year, weeknumber = expected_week })

            local entries =
                data.content.data[expected_year][expected_week]['Wednesday']['TestProject']['test.lua'].items
            assert.are.equal(1, #entries)
            assert.are.equal(start_time, entries[1].startTime)
            assert.are.equal(end_time, entries[1].endTime)
            assert.is_near(3.0, entries[1].diffInHours, 0.001)
            assert.are.equal('10:20', entries[1].startReadable)
            assert.are.equal('13:20', entries[1].endReadable)
        end)

        it('should auto-detect weekday from startTime if not provided', function()
            local mock_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            local start_time = mock_time - (1 * 60 * 60) -- 11:00 AM
            local end_time = mock_time -- 12:00 PM

            maorunTime.addManualTimeEntry({
                startTime = start_time,
                endTime = end_time,
                -- weekday not provided - should auto-detect as Wednesday
            })

            local data = maorunTime.calculate({ year = '2023', weeknumber = '11' })
            local entries =
                data.content.data['2023']['11']['Wednesday']['default_project']['default_file'].items
            assert.are.equal(1, #entries)
            assert.is_near(1.0, entries[1].diffInHours, 0.001)
        end)

        it('should reject invalid time ranges', function()
            assert.has_error(function()
                maorunTime.addManualTimeEntry({
                    startTime = 1678886400, -- 12:00 PM
                    endTime = 1678886400 - 3600, -- 11:00 AM (before start)
                })
            end, 'startTime must be before endTime')

            assert.has_error(function()
                maorunTime.addManualTimeEntry({
                    startTime = 1678886400, -- 12:00 PM
                    endTime = 1678886400, -- Same time
                })
            end, 'startTime must be before endTime')
        end)

        it('should require startTime and endTime parameters', function()
            assert.has_error(function()
                maorunTime.addManualTimeEntry({})
            end, 'addManualTimeEntry requires startTime and endTime parameters')

            assert.has_error(function()
                maorunTime.addManualTimeEntry({ startTime = 1678886400 })
            end, 'addManualTimeEntry requires startTime and endTime parameters')
        end)
    end)

    describe('listTimeEntries', function()
        it('should list time entries for a specific day', function()
            local mock_time = 1678886400 -- Wednesday, March 15, 2023
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add some test entries
            maorunTime.addTime({
                time = 2,
                weekday = 'Wednesday',
                project = 'Project1',
                file = 'file1.lua',
            })
            maorunTime.addTime({
                time = 1.5,
                weekday = 'Wednesday',
                project = 'Project1',
                file = 'file2.lua',
            })
            maorunTime.addTime({
                time = 3,
                weekday = 'Thursday',
                project = 'Project1',
                file = 'file1.lua',
            })

            local entries = maorunTime.listTimeEntries({
                year = '2023',
                weeknumber = '11',
                weekday = 'Wednesday',
                project = 'Project1',
                file = 'file1.lua',
            })

            assert.are.equal(1, #entries)
            assert.are.equal('Wednesday', entries[1].weekday)
            assert.are.equal('Project1', entries[1].project)
            assert.are.equal('file1.lua', entries[1].file)
            assert.are.equal(1, entries[1].index)
            assert.is_near(2.0, entries[1].entry.diffInHours, 0.001)
        end)

        it('should list all entries for a week when weekday not specified', function()
            local mock_time = 1678886400 -- Wednesday, March 15, 2023
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add entries for different days
            maorunTime.addTime({
                time = 2,
                weekday = 'Monday',
                project = 'Project1',
                file = 'file1.lua',
            })
            maorunTime.addTime({
                time = 1.5,
                weekday = 'Wednesday',
                project = 'Project1',
                file = 'file1.lua',
            })
            maorunTime.addTime({
                time = 3,
                weekday = 'Friday',
                project = 'Project1',
                file = 'file1.lua',
            })

            local entries = maorunTime.listTimeEntries({
                year = '2023',
                weeknumber = '11',
                project = 'Project1',
                file = 'file1.lua',
            })

            assert.are.equal(3, #entries)

            -- Should have entries for Monday, Wednesday, and Friday
            local weekdays = {}
            for _, entry in ipairs(entries) do
                weekdays[entry.weekday] = true
            end

            assert.is_true(weekdays['Monday'])
            assert.is_true(weekdays['Wednesday'])
            assert.is_true(weekdays['Friday'])
        end)

        it('should return empty list when no entries exist', function()
            maorunTime.setup({ path = tempPath })

            local entries = maorunTime.listTimeEntries({
                weekday = 'Monday',
                project = 'NonExistentProject',
                file = 'nonexistent.lua',
            })

            assert.are.equal(0, #entries)
        end)
    end)

    describe('editTimeEntry', function()
        local function setup_test_entry()
            local mock_time = 1678886400 -- Wednesday, March 15, 2023 13:20:00 UTC
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add a test entry: 10:20 to 13:20 (3 hours)
            local start_time = mock_time - (3 * 60 * 60) -- 10:20
            local end_time = mock_time -- 13:20

            maorunTime.addManualTimeEntry({
                startTime = start_time,
                endTime = end_time,
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })

            return {
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
                index = 1,
            }
        end

        it('should edit start time of an entry', function()
            local entry_info = setup_test_entry()
            local mock_time = 1678886400

            -- Change start time to 09:20
            local new_start_time = mock_time - (4 * 60 * 60) -- 09:20

            maorunTime.editTimeEntry(vim.tbl_extend('force', entry_info, {
                startTime = new_start_time,
            }))

            local data =
                maorunTime.calculate({ year = entry_info.year, weeknumber = entry_info.week })
            local entries =
                data.content.data[entry_info.year][entry_info.week][entry_info.weekday][entry_info.project][entry_info.file].items

            assert.are.equal(new_start_time, entries[1].startTime)
            assert.are.equal('09:20', entries[1].startReadable)
            assert.is_near(4.0, entries[1].diffInHours, 0.001) -- Now 09:20 to 13:20 = 4 hours
        end)

        it('should edit end time of an entry', function()
            local entry_info = setup_test_entry()
            local mock_time = 1678886400

            -- Change end time to 15:20
            local new_end_time = mock_time + (2 * 60 * 60) -- 15:20

            maorunTime.editTimeEntry(vim.tbl_extend('force', entry_info, {
                endTime = new_end_time,
            }))

            local data =
                maorunTime.calculate({ year = entry_info.year, weeknumber = entry_info.week })
            local entries =
                data.content.data[entry_info.year][entry_info.week][entry_info.weekday][entry_info.project][entry_info.file].items

            assert.are.equal(new_end_time, entries[1].endTime)
            assert.are.equal('15:20', entries[1].endReadable)
            assert.is_near(5.0, entries[1].diffInHours, 0.001) -- Now 10:20 to 15:20 = 5 hours
        end)

        it('should edit duration directly', function()
            local entry_info = setup_test_entry()

            maorunTime.editTimeEntry(vim.tbl_extend('force', entry_info, {
                diffInHours = 5.5,
            }))

            local data =
                maorunTime.calculate({ year = entry_info.year, weeknumber = entry_info.week })
            local entries =
                data.content.data[entry_info.year][entry_info.week][entry_info.weekday][entry_info.project][entry_info.file].items

            assert.is_near(5.5, entries[1].diffInHours, 0.001)
        end)

        it('should require valid entry parameters', function()
            assert.has_error(function()
                maorunTime.editTimeEntry({})
            end, 'editTimeEntry requires year, week, weekday, project, file, and index parameters')

            -- Setup a test entry first to test invalid index
            local entry_info = setup_test_entry()

            assert.has_error(function()
                maorunTime.editTimeEntry({
                    year = entry_info.year,
                    week = entry_info.week,
                    weekday = entry_info.weekday,
                    project = entry_info.project,
                    file = entry_info.file,
                    index = 999, -- Invalid index
                })
            end, 'Invalid entry index: 999')
        end)
    end)

    describe('deleteTimeEntry', function()
        it('should delete a specific time entry', function()
            local mock_time = 1678886400 -- Wednesday, March 15, 2023
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add multiple entries
            maorunTime.addTime({
                time = 2,
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })
            maorunTime.addTime({
                time = 1.5,
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })
            maorunTime.addTime({
                time = 3,
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
            })

            -- Verify we have 3 entries
            local data_before = maorunTime.calculate({ year = '2023', weeknumber = '11' })
            local entries_before =
                data_before.content.data['2023']['11']['Wednesday']['TestProject']['test.lua'].items
            assert.are.equal(3, #entries_before)

            -- Delete the second entry (index 2)
            maorunTime.deleteTimeEntry({
                year = '2023',
                week = '11',
                weekday = 'Wednesday',
                project = 'TestProject',
                file = 'test.lua',
                index = 2,
            })

            -- Verify we now have 2 entries and the middle one was removed
            local data_after = maorunTime.calculate({ year = '2023', weeknumber = '11' })
            local entries_after =
                data_after.content.data['2023']['11']['Wednesday']['TestProject']['test.lua'].items
            assert.are.equal(2, #entries_after)

            -- The remaining entries should be the 1st and 3rd original entries
            assert.is_near(2.0, entries_after[1].diffInHours, 0.001) -- Original first entry
            assert.is_near(3.0, entries_after[2].diffInHours, 0.001) -- Original third entry
        end)

        it('should require valid parameters', function()
            assert.has_error(
                function()
                    maorunTime.deleteTimeEntry({})
                end,
                'deleteTimeEntry requires year, week, weekday, project, file, and index parameters'
            )

            assert.has_error(function()
                maorunTime.deleteTimeEntry({
                    year = '2023',
                    week = '11',
                    weekday = 'Wednesday',
                    project = 'NonExistent',
                    file = 'test.lua',
                    index = 1,
                })
            end, 'No entries found for the specified day/project/file')
        end)
    end)

    describe('integration with existing functionality', function()
        it('should maintain data consistency after manual edits', function()
            local mock_time = 1678886400 -- Wednesday, March 15, 2023
            os_module.time = function()
                return mock_time
            end
            os_module.date = function(format, time_val)
                time_val = time_val or mock_time
                return original_os_date(format, time_val)
            end

            maorunTime.setup({ path = tempPath })

            -- Add some automatic entries
            maorunTime.addTime({
                time = 8,
                weekday = 'Monday',
                project = 'WorkProject',
                file = 'main.lua',
            })
            maorunTime.addTime({
                time = 6,
                weekday = 'Tuesday',
                project = 'WorkProject',
                file = 'main.lua',
            })

            -- Add manual entries
            maorunTime.addManualTimeEntry({
                startTime = mock_time - (4 * 60 * 60), -- 8:00 AM
                endTime = mock_time, -- 12:00 PM (4 hours)
                weekday = 'Wednesday',
                project = 'WorkProject',
                file = 'main.lua',
            })

            -- Calculate and verify summaries
            local data = maorunTime.calculate({ year = '2023', weeknumber = '11' })

            -- Check individual day summaries
            local monday_summary =
                data.content.data['2023']['11']['Monday']['WorkProject']['main.lua'].summary
            local tuesday_summary =
                data.content.data['2023']['11']['Tuesday']['WorkProject']['main.lua'].summary
            local wednesday_summary =
                data.content.data['2023']['11']['Wednesday']['WorkProject']['main.lua'].summary

            assert.is_near(8.0, monday_summary.diffInHours, 0.001)
            assert.is_near(6.0, tuesday_summary.diffInHours, 0.001)
            assert.is_near(4.0, wednesday_summary.diffInHours, 0.001)

            -- Check week summary (assuming 8 hours per weekday)
            local week_summary = data.content.data['2023']['11'].summary
            local expected_total = 8 + 6 + 4 -- 18 hours
            local expected_overhour = expected_total - (8 * 3) -- 18 - 24 = -6
            assert.is_near(expected_overhour, week_summary.overhour, 0.001)
        end)
    end)
end)
