local helper = require('test.helper')
helper.plenary_dep()
helper.notify_dep()

local maorunTime = require('maorun.time')
local Path = require('plenary.path')
local os_module = require('os')

local tempPath

before_each(function()
    tempPath = os_module.tmpname()
    -- Clear notification state by reloading the core module
    package.loaded['maorun.time.core'] = nil
    package.loaded['maorun.time'] = nil
    maorunTime = require('maorun.time')
end)

after_each(function()
    os_module.remove(tempPath)
end)

describe('Daily Goal Notifications', function()
    it('should notify when daily goal is reached (8 hours)', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400 -- Wednesday, March 15, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Setup with notifications enabled
        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = true,
                    oncePerDay = true,
                },
            },
        })

        -- Mock vim.notify to capture notifications
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add exactly 8 hours (the default daily goal)
        maorunTime.addTime({
            time = 8,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Check that a notification was sent
        assert.are.equal(1, #notifications, 'Expected exactly one notification')
        assert.is_true(
            string.find(notifications[1].msg, 'Daily goal reached') ~= nil,
            'Expected goal reached notification'
        )
        assert.is_true(
            string.find(notifications[1].msg, '8.0h worked') ~= nil,
            'Expected to show 8 hours worked'
        )
        assert.are.equal(vim.log.levels.INFO, notifications[1].level)
        assert.are.equal('TimeTracking - Daily Goal', notifications[1].opts.title)

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should notify when daily goal is exceeded', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Setup with notifications enabled
        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = true,
                    oncePerDay = true,
                },
            },
        })

        -- Mock vim.notify
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add 9.5 hours (exceeding the 8 hour goal)
        maorunTime.addTime({
            time = 9.5,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Check that a notification was sent
        assert.are.equal(1, #notifications, 'Expected exactly one notification')
        assert.is_true(
            string.find(notifications[1].msg, 'Daily goal exceeded') ~= nil,
            'Expected goal exceeded notification'
        )
        assert.is_true(
            string.find(notifications[1].msg, '9.5h worked') ~= nil,
            'Expected to show 9.5 hours worked'
        )
        assert.is_true(
            string.find(notifications[1].msg, '+1.5h over') ~= nil,
            'Expected to show 1.5 hours over'
        )
        assert.are.equal(vim.log.levels.INFO, notifications[1].level)

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should not notify when goal is not reached', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Setup with notifications enabled
        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = true,
                    oncePerDay = true,
                },
            },
        })

        -- Mock vim.notify
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add only 6 hours (less than 8 hour goal)
        maorunTime.addTime({
            time = 6,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Check that no notification was sent
        assert.are.equal(0, #notifications, 'Expected no notifications for unmet goal')

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should not notify when notifications are disabled', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Setup with notifications disabled
        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = false,
                    oncePerDay = true,
                },
            },
        })

        -- Mock vim.notify
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add 8 hours (should meet goal but notifications disabled)
        maorunTime.addTime({
            time = 8,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Check that no notification was sent
        assert.are.equal(0, #notifications, 'Expected no notifications when disabled')

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should only notify once per day when oncePerDay is true', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Setup with notifications enabled and oncePerDay = true
        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = true,
                    oncePerDay = true,
                },
            },
        })

        -- Mock vim.notify
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add 8 hours first time
        maorunTime.addTime({
            time = 8,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Add more time same day
        maorunTime.addTime({
            time = 2,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Should only have one notification despite multiple additions
        assert.are.equal(
            1,
            #notifications,
            'Expected exactly one notification when oncePerDay is true'
        )

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should not notify for weekdays with 0 expected hours', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        -- Set to Sunday (default 0 hours expected)
        local mock_time = 1678752000 -- Sunday, March 12, 2023 12:00:00 PM GMT
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = true,
                    oncePerDay = true,
                },
            },
        })

        -- Mock vim.notify
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add time on Sunday (0 expected hours)
        maorunTime.addTime({
            time = 4,
            weekday = 'Sunday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Should not notify for days with 0 expected hours
        assert.are.equal(
            0,
            #notifications,
            'Expected no notifications for days with 0 expected hours'
        )

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)

    it('should support recurring notifications when oncePerDay is false', function()
        local original_os_date = os_module.date
        local original_os_time = os_module.time

        local mock_time = 1678886400
        os_module.time = function()
            return mock_time
        end
        os_module.date = function(format, time)
            time = time or mock_time
            return original_os_date(format, time)
        end

        -- Setup with recurring notifications every 1 minute (for testing)
        maorunTime.setup({
            path = tempPath,
            notifications = {
                dailyGoal = {
                    enabled = true,
                    oncePerDay = false,
                    recurringMinutes = 1,
                },
            },
        })

        -- Mock vim.notify
        local notifications = {}
        local original_vim_notify = vim.notify
        vim.notify = function(msg, level, opts)
            table.insert(notifications, { msg = msg, level = level, opts = opts })
        end

        -- Add 9 hours (exceeding goal)
        maorunTime.addTime({
            time = 9,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Simulate time passing - add 2 minutes (120 seconds) to mock time
        mock_time = mock_time + 120
        os_module.time = function()
            return mock_time
        end

        -- Add more time to trigger recalculation
        maorunTime.addTime({
            time = 0.5,
            weekday = 'Wednesday',
            project = 'TestProject',
            file = 'test.lua',
        })

        -- Restore vim.notify
        vim.notify = original_vim_notify

        -- Should have two notifications (initial + recurring after 2 minutes)
        assert.are.equal(2, #notifications, 'Expected two notifications with recurring enabled')

        os_module.date = original_os_date
        os_module.time = original_os_time
    end)
end)
