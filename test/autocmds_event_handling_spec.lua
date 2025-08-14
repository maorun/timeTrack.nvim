local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local os_module = require('os')

describe('autocmds event handling', function()
    local autocmds_module
    local tempPath

    before_each(function()
        tempPath = os_module.tmpname()
        package.loaded['maorun.time.autocmds'] = nil
        package.loaded['maorun.time'] = nil
        maorunTime = require('maorun.time')
        autocmds_module = require('maorun.time.autocmds')
        maorunTime.setup({ path = tempPath })
    end)

    after_each(function()
        os_module.remove(tempPath)
    end)

    describe('intelligent event handling', function()
        it('should not start multiple times for the same project/file context', function()
            local original_os_date = os_module.date
            local original_os_time = os_module.time

            local start_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
            os_module.time = function()
                return start_time
            end
            os_module.date = function(format, time)
                time = time or start_time
                return original_os_date(format, time)
            end

            -- Mock buffer info to return same project/file
            local utils_module = require('maorun.time.utils')
            local original_get_info = utils_module.get_project_and_file_info
            utils_module.get_project_and_file_info = function()
                return { project = 'test_project', file = 'test_file.lua' }
            end

            -- Start tracking manually first
            maorunTime.TimeStart({ project = 'test_project', file = 'test_file.lua' })

            -- Now call TimeStart again with same context - should not create duplicate entry
            maorunTime.TimeStart({ project = 'test_project', file = 'test_file.lua' })

            local year = os_module.date('%Y', start_time)
            local week = os_module.date('%W', start_time)
            local data = maorunTime.calculate({ year = year, weeknumber = week })

            local entries =
                data.content.data[year][week]['Wednesday']['test_project']['test_file.lua'].items

            -- Should have only one entry, not multiple
            assert.are.equal(
                1,
                #entries,
                'Should have only one entry, not multiple for same context'
            )
            assert.is_not_nil(entries[1].startTime, 'Should have a start time')
            assert.is_nil(entries[1].endTime, 'Should not have end time yet')

            -- Restore original functions
            utils_module.get_project_and_file_info = original_get_info
            os_module.date = original_os_date
            os_module.time = original_os_time
        end)

        it('should properly switch contexts when project/file changes', function()
            -- This test demonstrates that manual context switching works correctly.
            -- The TimeStart function already prevents multiple starts for same context,
            -- and TimeStop properly ends entries.
            local original_os_date = os_module.date
            local original_os_time = os_module.time

            local start_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
            local switch_time = start_time + 1800 -- 30 minutes later

            os_module.time = function()
                return start_time
            end
            os_module.date = function(format, time)
                time = time or start_time
                return original_os_date(format, time)
            end

            -- Start with first project/file
            maorunTime.TimeStart({ project = 'project1', file = 'file1.lua' })

            -- Change time and stop first, then start second (simulating proper context switch)
            os_module.time = function()
                return switch_time
            end
            os_module.date = function(format, time)
                time = time or switch_time
                return original_os_date(format, time)
            end

            maorunTime.TimeStop({ project = 'project1', file = 'file1.lua' })
            maorunTime.TimeStart({ project = 'project2', file = 'file2.lua' })

            local year = os_module.date('%Y', start_time)
            local week = os_module.date('%W', start_time)
            local data = maorunTime.calculate({ year = year, weeknumber = week })

            -- Check first project/file has ended
            local entries1 =
                data.content.data[year][week]['Wednesday']['project1']['file1.lua'].items
            assert.are.equal(1, #entries1, 'Should have one entry for project1')
            assert.is_not_nil(entries1[1].startTime, 'Should have start time for project1')
            assert.is_not_nil(
                entries1[1].endTime,
                'Should have end time for project1 after context switch'
            )

            -- Check second project/file has started
            local entries2 =
                data.content.data[year][week]['Wednesday']['project2']['file2.lua'].items
            assert.are.equal(1, #entries2, 'Should have one entry for project2')
            assert.is_not_nil(entries2[1].startTime, 'Should have start time for project2')
            assert.is_nil(entries2[1].endTime, 'Should not have end time for project2 yet')

            -- Restore original functions
            os_module.date = original_os_date
            os_module.time = original_os_time
        end)

        it('should handle rapid buffer switches gracefully', function()
            local original_os_date = os_module.date
            local original_os_time = os_module.time

            local base_time = 1678886400
            local time_counter = 0

            os_module.time = function()
                time_counter = time_counter + 1
                return base_time + time_counter
            end
            os_module.date = function(format, time)
                time = time or (base_time + time_counter)
                return original_os_date(format, time)
            end

            -- Simulate rapid buffer switches
            for i = 1, 5 do
                maorunTime.TimeStart({ project = 'same_project', file = 'same_file.lua' })
            end

            local year = os_module.date('%Y', base_time)
            local week = os_module.date('%W', base_time)
            local data = maorunTime.calculate({ year = year, weeknumber = week })

            local entries =
                data.content.data[year][week]['Wednesday']['same_project']['same_file.lua'].items

            -- Should have only one entry despite multiple TimeStart calls
            assert.are.equal(1, #entries, 'Should have only one entry despite rapid switches')
            assert.is_not_nil(entries[1].startTime, 'Should have a start time')
            assert.is_nil(entries[1].endTime, 'Should not have end time yet')

            -- Restore original functions
            os_module.date = original_os_date
            os_module.time = original_os_time
        end)

        it('should properly handle VimLeave stopping all tracking', function()
            local original_os_date = os_module.date
            local original_os_time = os_module.time

            local start_time = 1678886400
            os_module.time = function()
                return start_time
            end
            os_module.date = function(format, time)
                time = time or start_time
                return original_os_date(format, time)
            end

            -- Start tracking multiple projects
            maorunTime.TimeStart({ project = 'project1', file = 'file1.lua' })
            maorunTime.TimeStart({ project = 'project2', file = 'file2.lua' })

            -- Simulate VimLeave by calling TimeStop on all contexts
            maorunTime.TimeStop({ project = 'project1', file = 'file1.lua' })
            maorunTime.TimeStop({ project = 'project2', file = 'file2.lua' })

            local year = os_module.date('%Y', start_time)
            local week = os_module.date('%W', start_time)
            local data = maorunTime.calculate({ year = year, weeknumber = week })

            -- Both projects should have completed entries
            local entries1 =
                data.content.data[year][week]['Wednesday']['project1']['file1.lua'].items
            local entries2 =
                data.content.data[year][week]['Wednesday']['project2']['file2.lua'].items

            assert.are.equal(1, #entries1, 'Should have one entry for project1')
            assert.is_not_nil(entries1[1].endTime, 'Project1 should be stopped')

            assert.are.equal(1, #entries2, 'Should have one entry for project2')
            assert.is_not_nil(entries2[1].endTime, 'Project2 should be stopped')

            -- Restore original functions
            os_module.date = original_os_date
            os_module.time = original_os_time
        end)
    end)
end)
