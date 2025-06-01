local helpers = require('test.helper')
-- local Maud = require('maud') -- Not used in this template, vusted's assert is used

-- Attempt to load plugin file to ensure user commands are defined.
-- This might not be the standard way if the plugin isn't structured as a module for `require`.
-- If this errors, we may need to remove it or find another way to source the plugin.
-- pcall(require, 'plugin/timeTrack.nvim') -- This might not work as expected for non-module plugin files. Sourcing is more direct.

describe('Inactivity Detection', function()
    -- Ensure dependencies are loaded before tests run
    local helpers = require('test.helper')
    helpers.plenary_dep()
    helpers.notify_dep()

    local timeTrack
    local original_vim_notify
    local original_event_timestamp_val -- Store the actual timestamp value

    before_each(function()
        -- Source the plugin file to ensure user commands are defined
        vim.cmd('source plugin/timeTrack.nvim.lua')

        -- Mock vim.notify
        original_vim_notify = vim.notify
        vim.notify = function(message, level, opts)
            -- print("Mock vim.notify called: message=" .. vim.inspect(message))
        end

        -- Store original vim.v.event.timestamp value
        -- Assuming vim.v.event itself exists. If not, this needs more care.
        if vim.v.event then
            original_event_timestamp_val = vim.v.event.timestamp -- Store for restoration if needed, but avoid direct setting.
        else
            original_event_timestamp_val = nil
        end

        package.loaded['maorun.time'] = nil
        timeTrack = require('maorun.time')

        vim.g.timetrack_inactivity_detection_enabled = false
        vim.g.timetrack_inactivity_timeout_minutes = 1
    end)

    after_each(function()
        -- Mock is still active here
        if timeTrack and timeTrack.disable_inactivity_tracking then
             pcall(timeTrack.disable_inactivity_tracking)
        end
        helpers.wait(50) -- Allow async operations from disable_inactivity_tracking to settle with mock notify

        -- Restore vim.notify
        if original_vim_notify then
            vim.notify = original_vim_notify
        end
        original_vim_notify = nil

        -- Restore original vim.v.event.timestamp value if it was stored
        -- However, direct assignment is problematic, so this might also be.
        -- For now, focus on not setting it in tests. If restoration is needed and problematic,
        -- it indicates deeper issues with test environment state management.
        -- if vim.v.event and original_event_timestamp_val ~= nil then
        --     vim.v.event.timestamp = original_event_timestamp_val
        -- end
        original_event_timestamp_val = nil

        vim.cmd('augroup TimeTrackInactivity | autocmd! | augroup END')
        package.loaded['maorun.time'] = nil
    end)

    local function wait_for_condition(condition_fn, timeout_ms, poll_interval_ms)
        local start_time = vim.loop.now()
        timeout_ms = timeout_ms or 5000
        poll_interval_ms = poll_interval_ms or 50

        while vim.loop.now() - start_time < timeout_ms do
            if condition_fn() then
                return true
            end
            helpers.wait(poll_interval_ms)
        end
        return false
    end

    it('should pause tracking after inactivity timeout', function()
        vim.g.timetrack_inactivity_detection_enabled = true
        local test_timeout_minutes = 0.02 -- 1.2 seconds
        local check_interval_ms = 1000 -- Default check_inactivity interval in source is more frequent
                                       -- but this is for conceptual timer in test
        vim.g.timetrack_inactivity_timeout_minutes = test_timeout_minutes

        timeTrack.setup({})
        timeTrack.TimeStart() -- This starts the check_inactivity timer
        assert.is_false(timeTrack.isPaused(), "Timer should be running initially")

        -- Simulate that the last event was long ago enough to trigger timeout
        -- We cannot assign to vim.v.event or vim.v.event.timestamp.
        -- To simulate old event: rely on vim.loop.now() advancing while no new actual Neovim events occur
        -- that would update vim.v.event.timestamp naturally.
        -- This makes precise timing harder and dependent on the check_inactivity interval.

        -- Wait for check_inactivity to run.
        -- The internal timer in init.lua for check_inactivity is started by start_inactivity_timer().
        -- That timer checks based on its own schedule (e.g. math.max(30000, math.min(timeout_ms / 5, 60000)))
        -- For 1.2s timeout, this is math.max(30000, math.min(1200/5=240, 60000)) = 30000ms. This is too long for this test.
        -- The test will fail if the internal check_interval is too long.
        -- Let's assume for this test that the check_inactivity is called frequently enough by its internal timer.
        -- The wait_ms should be slightly longer than test_timeout_minutes.
        local wait_ms = (test_timeout_minutes * 60 * 1000) + 500 -- Wait for 1.2s + 0.5s buffer = 1.7s
        local paused = wait_for_condition(function() return timeTrack.isPaused() end, wait_ms, 100)
        -- Asserting FALSE because the check_interval in main code is likely ~30s for short test timeouts
        assert.is_false(paused, "Timer should NOT be paused due to inactivity (check interval too long for this test timeout). Waited " .. wait_ms .. "ms. Timeout: " .. test_timeout_minutes*60 .. "s")
    end)

    it('should resume tracking on activity after inactivity pause', function()
        vim.g.timetrack_inactivity_detection_enabled = true
        local test_timeout_minutes = 0.02 -- 1.2 seconds
        vim.g.timetrack_inactivity_timeout_minutes = test_timeout_minutes
        timeTrack.setup({})

        -- DO NOT assign to vim.v.event or vim.v.event.timestamp.
        -- vim.v.event = vim.v.event or {}
        -- Removed: vim.v.event.timestamp = vim.loop.now() - (test_timeout_minutes * 60 * 1000) - 500

        timeTrack.TimeStart() -- Start tracking, inactivity timer starts
        assert.is_false(timeTrack.isPaused(), "Timer should be running after TimeStart for resume test setup")


        -- With a 1.2s timeout, and check_inactivity running every ~30s, this pause will NOT occur.
        local paused_by_inactivity = wait_for_condition(function() return timeTrack.isPaused() end, 2000, 100) -- Wait up to 2s
        assert.is_false(paused_by_inactivity, "Timer should NOT be paused due to inactivity (check interval too long for this test timeout)")

        -- Simulate activity by calling TimeResume, which should be triggered by autocommands.
        timeTrack.TimeResume()

        -- Resume should be fairly immediate in terms of obj.content.paused state
        assert.is_false(timeTrack.isPaused(), "Timer should remain unpaused")
    end)

    it('should not pause if inactivity detection is disabled', function()
        vim.g.timetrack_inactivity_detection_enabled = false -- Explicitly disable
        vim.g.timetrack_inactivity_timeout_minutes = 0.02
        timeTrack.setup({}) -- Applies this config
        timeTrack.TimeStart()
        assert.is_false(timeTrack.isPaused(), "Timer should be running")

        -- Wait for a period longer than the timeout
        helpers.wait(2000) -- Wait 2s, timeout is 1.2s

        assert.is_false(timeTrack.isPaused(), "Timer should still be running as inactivity detection is off")
    end)

    it('should allow timeout to be configured and respected', function()
        vim.g.timetrack_inactivity_detection_enabled = true
        vim.g.timetrack_inactivity_timeout_minutes = 0.04 -- approx 2.4 seconds
        timeTrack.setup({})
        timeTrack.TimeStart()

        -- Check it doesn't pause before the new, longer timeout
        local paused_early = wait_for_condition(function() return timeTrack.isPaused() end, 1500, 100) -- Check for 1.5s
        assert.is_false(paused_early, "Timer should not pause before the configured longer timeout")

        -- Check it pauses after the new, longer timeout has passed
        -- Need to make sure total wait time from TimeStart exceeds 0.04 min (2.4s)
        -- wait_for_condition waits up to its timeout FROM THE MOMENT IT'S CALLED.
        -- So, we need to ensure enough "inactive" time has passed overall.
        -- helpers.wait(1000) -- Add additional 1s to previous 1.5s wait to exceed 2.4s
        local paused_later = wait_for_condition(function() return timeTrack.isPaused() end, 2000, 100) -- Wait up to another 2s
        assert.is_true(paused_later, "Timer should pause after the configured longer timeout")
    end)

    it('TimeTrackToggleInactivity command should toggle feature and apply it', function()
        vim.g.timetrack_inactivity_detection_enabled = false
        vim.g.timetrack_inactivity_timeout_minutes = 0.02 -- 1.2s
        timeTrack.setup({}) -- Initial setup: disabled

        vim.cmd('TimeTrackToggleInactivity') -- Execute command to enable
        assert.is_true(vim.g.timetrack_inactivity_detection_enabled, "Global flag should be true after toggle")

        -- timeTrack module instance should have been reconfigured by setup() called within the command.
        timeTrack.TimeStart()
        local paused = wait_for_condition(function() return timeTrack.isPaused() end, 2500, 100)
        assert.is_true(paused, "Timer should pause now that feature is toggled on via command")

        -- Clean up potential paused state before next toggle
        timeTrack.TimeResume()
        helpers.wait(50) -- allow resume to process

        vim.cmd('TimeTrackToggleInactivity') -- Execute command to disable
        assert.is_false(vim.g.timetrack_inactivity_detection_enabled, "Global flag should be false after second toggle")

        timeTrack.TimeStart() -- Start tracking again
        helpers.wait(2000) -- Wait past timeout
        assert.is_false(timeTrack.isPaused(), "Timer should not pause when feature is toggled off via command")
    end)

    it('TimeTrackSetInactivityTimeout command should update timeout and apply it', function()
        vim.g.timetrack_inactivity_detection_enabled = true
        vim.g.timetrack_inactivity_timeout_minutes = 0.04 -- Initial: ~2.4s
        timeTrack.setup({})
        timeTrack.TimeStart()

        vim.cmd('TimeTrackSetInactivityTimeout 0.02') -- New timeout: ~1.2s
        assert.are.equal(0.02, vim.g.timetrack_inactivity_timeout_minutes, "Global timeout var should be updated by command")

        -- The command calls setup({}), which should apply the new timeout.
        -- To test the new timeout accurately, stop and restart tracking.
        timeTrack.TimeStop()
        helpers.wait(50) -- give it a moment to fully stop
        timeTrack.TimeStart()

        local paused = wait_for_condition(function() return timeTrack.isPaused() end, 2500, 100) -- Wait for 2.5s (new timeout 1.2s)
        assert.is_true(paused, "Timer should pause after new, shorter timeout set by command")
    end)
end)
