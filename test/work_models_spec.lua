local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local config_module = require('maorun.time.config')
local Path = require('plenary.path')
local os_module = require('os')

local tempPath

before_each(function()
    tempPath = vim.fn.tempname()
end)

after_each(function()
    os_module.remove(tempPath)
end)

describe('Work Model Support', function()
    describe('Work Model Presets', function()
        it('should provide available work model presets', function()
            maorunTime.setup({ path = tempPath })

            local models = maorunTime.getAvailableWorkModels()

            assert.is_not_nil(models.standard)
            assert.is_not_nil(models.fourDayWeek)
            assert.is_not_nil(models.partTime)
            assert.is_not_nil(models.flexibleCore)

            assert.are.equal('Standard 40-hour week', models.standard)
            assert.are.equal('4-day work week (32 hours)', models.fourDayWeek)
            assert.are.equal('Part-time (20 hours)', models.partTime)
            assert.are.equal('Flexible with core hours (10-16)', models.flexibleCore)
        end)

        it('should apply 4-day work week preset correctly', function()
            maorunTime.setup({ path = tempPath })

            local success = maorunTime.applyWorkModelPreset('fourDayWeek')
            assert.is_true(success)

            local current_model = maorunTime.getCurrentWorkModel()
            assert.are.equal('fourDayWeek', current_model.workModel)
            assert.are.equal(8, current_model.hoursPerWeekday.Monday)
            assert.are.equal(8, current_model.hoursPerWeekday.Tuesday)
            assert.are.equal(8, current_model.hoursPerWeekday.Wednesday)
            assert.are.equal(8, current_model.hoursPerWeekday.Thursday)
            assert.are.equal(0, current_model.hoursPerWeekday.Friday)
            assert.are.equal(0, current_model.hoursPerWeekday.Saturday)
            assert.are.equal(0, current_model.hoursPerWeekday.Sunday)

            -- Check core hours
            assert.is_not_nil(current_model.coreWorkingHours.Monday)
            assert.are.equal(9, current_model.coreWorkingHours.Monday.start)
            assert.are.equal(17, current_model.coreWorkingHours.Monday.finish)
            assert.is_nil(current_model.coreWorkingHours.Friday)
        end)

        it('should apply part-time preset correctly', function()
            maorunTime.setup({ path = tempPath })

            local success = maorunTime.applyWorkModelPreset('partTime')
            assert.is_true(success)

            local current_model = maorunTime.getCurrentWorkModel()
            assert.are.equal('partTime', current_model.workModel)
            assert.are.equal(4, current_model.hoursPerWeekday.Monday)
            assert.are.equal(4, current_model.hoursPerWeekday.Tuesday)
            assert.are.equal(4, current_model.hoursPerWeekday.Wednesday)
            assert.are.equal(4, current_model.hoursPerWeekday.Thursday)
            assert.are.equal(4, current_model.hoursPerWeekday.Friday)

            -- Check core hours for part-time (10 AM to 2 PM)
            assert.is_not_nil(current_model.coreWorkingHours.Monday)
            assert.are.equal(10, current_model.coreWorkingHours.Monday.start)
            assert.are.equal(14, current_model.coreWorkingHours.Monday.finish)
        end)

        it('should apply flexible core hours preset correctly', function()
            maorunTime.setup({ path = tempPath })

            local success = maorunTime.applyWorkModelPreset('flexibleCore')
            assert.is_true(success)

            local current_model = maorunTime.getCurrentWorkModel()
            assert.are.equal('flexibleCore', current_model.workModel)
            assert.are.equal(8, current_model.hoursPerWeekday.Monday)

            -- Check flexible core hours (10 AM to 4 PM)
            assert.is_not_nil(current_model.coreWorkingHours.Monday)
            assert.are.equal(10, current_model.coreWorkingHours.Monday.start)
            assert.are.equal(16, current_model.coreWorkingHours.Monday.finish)
        end)

        it('should handle invalid work model preset', function()
            maorunTime.setup({ path = tempPath })

            local notifications = {}
            local original_vim_notify = vim.notify
            vim.notify = function(message, level, opts)
                table.insert(notifications, { message = message, level = level, opts = opts })
            end

            local success = maorunTime.applyWorkModelPreset('invalidModel')
            assert.is_false(success)

            -- Should have received an error notification
            assert.are.equal(1, #notifications)
            assert.is_true(string.find(notifications[1].message, 'not found') ~= nil)

            vim.notify = original_vim_notify
        end)

        it('should persist work model configuration', function()
            maorunTime.setup({ path = tempPath })
            maorunTime.applyWorkModelPreset('fourDayWeek')

            -- Create new instance to test persistence
            package.loaded['maorun.time.config'] = nil
            package.loaded['maorun.time.core'] = nil
            package.loaded['maorun.time'] = nil
            local newMaorunTime = require('maorun.time')

            newMaorunTime.setup({ path = tempPath })
            local current_model = newMaorunTime.getCurrentWorkModel()

            assert.are.equal('fourDayWeek', current_model.workModel)
            assert.are.equal(0, current_model.hoursPerWeekday.Friday)
        end)
    end)

    describe('Work Model Setup Configuration', function()
        it('should apply work model preset during setup', function()
            maorunTime.setup({
                path = tempPath,
                workModel = 'fourDayWeek',
            })

            local current_model = maorunTime.getCurrentWorkModel()
            assert.are.equal('fourDayWeek', current_model.workModel)
            assert.are.equal(0, current_model.hoursPerWeekday.Friday)
        end)

        it('should allow manual override of preset values', function()
            maorunTime.setup({
                path = tempPath,
                workModel = 'fourDayWeek',
                hoursPerWeekday = {
                    Monday = 10, -- Override preset value
                    Friday = 4, -- Override preset value
                },
            })

            local current_model = maorunTime.getCurrentWorkModel()
            assert.are.equal('fourDayWeek', current_model.workModel)
            assert.are.equal(10, current_model.hoursPerWeekday.Monday) -- Overridden
            assert.are.equal(4, current_model.hoursPerWeekday.Friday) -- Overridden
            assert.are.equal(8, current_model.hoursPerWeekday.Tuesday) -- From preset
        end)

        it('should warn about invalid work model preset during setup', function()
            local notifications = {}
            local original_vim_notify = vim.notify
            vim.notify = function(message, level, opts)
                table.insert(notifications, { message = message, level = level, opts = opts })
            end

            maorunTime.setup({
                path = tempPath,
                workModel = 'invalidPreset',
            })

            -- Should have received a warning
            assert.are.equal(1, #notifications)
            assert.is_true(
                string.find(notifications[1].message, 'Unknown work model preset') ~= nil
            )

            vim.notify = original_vim_notify
        end)
    end)

    describe('Core Working Hours', function()
        it('should validate core working hours configuration', function()
            local valid, error_msg = config_module.validateCoreWorkingHours({
                Monday = { start = 9, finish = 17 },
                Tuesday = { start = 10, finish = 16 },
                Friday = nil, -- No core hours for Friday
            })

            assert.is_true(valid)
            assert.are.equal('', error_msg)
        end)

        it('should reject invalid core working hours', function()
            -- Invalid: start >= finish
            local valid, error_msg = config_module.validateCoreWorkingHours({
                Monday = { start = 17, finish = 9 },
            })
            assert.is_false(valid)
            assert.is_true(string.find(error_msg, 'start time must be before finish time') ~= nil)

            -- Invalid: time out of range
            valid, error_msg = config_module.validateCoreWorkingHours({
                Monday = { start = -1, finish = 25 },
            })
            assert.is_false(valid)
            assert.is_true(string.find(error_msg, 'times must be between 0 and 24') ~= nil)

            -- Invalid: non-numeric times
            valid, error_msg = config_module.validateCoreWorkingHours({
                Monday = { start = '9', finish = 17 },
            })
            assert.is_false(valid)
            assert.is_true(
                string.find(error_msg, 'must have numeric start and finish times') ~= nil
            )
        end)

        it('should check if timestamp is within core hours', function()
            -- Create a timestamp for 2:30 PM on a Monday (within 9-17 core hours)
            local monday_230pm = os.time({
                year = 2023,
                month = 3,
                day = 13, -- Monday, March 13, 2023
                hour = 14,
                min = 30,
                sec = 0,
            })

            -- Create a timestamp for 7:30 PM on a Monday (outside 9-17 core hours)
            local monday_730pm = os.time({
                year = 2023,
                month = 3,
                day = 13, -- Monday, March 13, 2023
                hour = 19,
                min = 30,
                sec = 0,
            })

            maorunTime.setup({ path = tempPath })

            assert.is_true(maorunTime.isWithinCoreHours(monday_230pm, 'Monday'))
            assert.is_false(maorunTime.isWithinCoreHours(monday_730pm, 'Monday'))
        end)

        it('should handle weekdays with no core hours defined', function()
            maorunTime.setup({
                path = tempPath,
                coreWorkingHours = {
                    Monday = { start = 9, finish = 17 },
                    -- Saturday and Sunday have no core hours
                },
            })

            local saturday_time = os.time({
                year = 2023,
                month = 3,
                day = 18, -- Saturday, March 18, 2023
                hour = 14,
                min = 30,
                sec = 0,
            })

            -- Should return true when no core hours are defined
            assert.is_true(maorunTime.isWithinCoreHours(saturday_time, 'Saturday'))
        end)
    end)

    describe('Core Hours Compliance Notifications', function()
        it('should not notify when core hours notifications are disabled', function()
            local notifications = {}
            local original_vim_notify = vim.notify
            vim.notify = function(message, level, opts)
                table.insert(notifications, { message = message, level = level, opts = opts })
            end

            maorunTime.setup({
                path = tempPath,
                workModel = 'flexibleCore', -- Has core hours 10-16
                notifications = {
                    coreHoursCompliance = {
                        enabled = false, -- Disabled
                    },
                },
            })

            -- Add time outside core hours (early morning)
            local early_start = os.time() - (4 * 3600) -- 4 hours ago
            local early_end = os.time() - (2 * 3600) -- 2 hours ago

            maorunTime.addManualTimeEntry({
                startTime = early_start,
                endTime = early_end,
                weekday = 'Monday',
            })

            -- Should not have any core hours notifications
            local core_notifications = {}
            for _, notif in ipairs(notifications) do
                if notif.opts and notif.opts.title == 'TimeTracking - Core Hours' then
                    table.insert(core_notifications, notif)
                end
            end

            assert.are.equal(0, #core_notifications)

            vim.notify = original_vim_notify
        end)

        it('should notify when work time is outside core hours', function()
            local notifications = {}
            local original_vim_notify = vim.notify
            vim.notify = function(message, level, opts)
                table.insert(notifications, { message = message, level = level, opts = opts })
            end

            maorunTime.setup({
                path = tempPath,
                workModel = 'flexibleCore', -- Has core hours 10-16
                notifications = {
                    coreHoursCompliance = {
                        enabled = true,
                        warnOutsideCoreHours = true,
                    },
                },
            })

            -- Create timestamps for work outside core hours (early morning)
            local early_start = os.time({
                year = 2023,
                month = 3,
                day = 13, -- Monday
                hour = 7,
                min = 0,
                sec = 0,
            })
            local early_end = os.time({
                year = 2023,
                month = 3,
                day = 13, -- Monday
                hour = 9,
                min = 0,
                sec = 0,
            })

            maorunTime.addManualTimeEntry({
                startTime = early_start,
                endTime = early_end,
                weekday = 'Monday',
            })

            -- Should have received a core hours compliance notification
            local core_notifications = {}
            for _, notif in ipairs(notifications) do
                if notif.opts and notif.opts.title == 'TimeTracking - Core Hours' then
                    table.insert(core_notifications, notif)
                end
            end

            assert.are.equal(1, #core_notifications)
            assert.is_true(
                string.find(core_notifications[1].message, 'Work time outside core hours') ~= nil
            )
            assert.is_true(string.find(core_notifications[1].message, 'Monday') ~= nil)
            assert.is_true(string.find(core_notifications[1].message, '07:00%-09:00') ~= nil)

            vim.notify = original_vim_notify
        end)
    end)
end)
