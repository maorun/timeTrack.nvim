# Work Model Examples for timeTrack.nvim

## Example: 4-Day Work Week

```lua
require('maorun.time').setup({
    workModel = 'fourDayWeek',
    notifications = {
        coreHoursCompliance = {
            enabled = true,
        },
    },
})

-- Check available models
local models = Time.getAvailableWorkModels()
print(vim.inspect(models))
-- Output:
-- {
--   fourDayWeek = "4-day work week (32 hours)",
--   partTime = "Part-time (20 hours)", 
--   standard = "Standard 40-hour week",
--   flexibleCore = "Flexible with core hours (10-16)"
-- }

-- Check current configuration
local current = Time.getCurrentWorkModel()
print("Work model:", current.workModel)
print("Friday hours:", current.hoursPerWeekday.Friday) -- 0 (day off)
print("Core hours Monday:", vim.inspect(current.coreWorkingHours.Monday)) -- {start=9, finish=17}
```

## Example: Custom Part-Time with Core Hours

```lua
require('maorun.time').setup({
    workModel = 'partTime',
    -- Override specific days
    hoursPerWeekday = {
        Friday = 0,  -- Take Friday off too
    },
    notifications = {
        coreHoursCompliance = {
            enabled = true,
            warnOutsideCoreHours = true,
        },
    },
})

-- Working outside core hours (before 10 AM) will trigger notification:
-- "Work time outside core hours! Monday 08:00-10:00 (core: 10:00-14:00)"
```

## Example: Custom Core Hours

```lua
require('maorun.time').setup({
    coreWorkingHours = {
        Monday = { start = 10, finish = 16 },    -- 10 AM - 4 PM
        Tuesday = { start = 9, finish = 17 },    -- 9 AM - 5 PM
        Wednesday = { start = 11, finish = 15 }, -- 11 AM - 3 PM
        Thursday = { start = 9, finish = 17 },
        Friday = { start = 10, finish = 14 },    -- Short Friday
        -- Weekend: no core hours
    },
    notifications = {
        coreHoursCompliance = {
            enabled = true,
            oncePerDay = true, -- Only warn once per day per weekday
        },
    },
})

-- Check if a specific time is within core hours
local monday_2pm = os.time({year=2023, month=3, day=13, hour=14, min=0})
local is_core_time = Time.isWithinCoreHours(monday_2pm, 'Monday')
print("2 PM Monday is core time:", is_core_time) -- true (within 10-16)
```

## Example: Apply Work Model Dynamically

```lua
-- Setup with standard model first
require('maorun.time').setup({})

-- Later, switch to 4-day week
Time.applyWorkModelPreset('fourDayWeek')
-- Notification: "Applied work model: 4-day work week (32 hours)"

-- Check what changed
local current = Time.getCurrentWorkModel() 
print("Friday hours after switch:", current.hoursPerWeekday.Friday) -- 0
```

## Notifications

When core hours compliance is enabled, you'll receive notifications like:

- **Within core hours**: No notification
- **Outside core hours**: "Work time outside core hours! Monday 07:00-09:00 (core: 09:00-17:00)"
- **Daily goal reached**: "Daily goal reached! Monday: 8.0h worked (8.0h goal)" 
- **Daily goal exceeded**: "Daily goal exceeded! Monday: 9.5h worked (8.0h goal, +1.5h over)"

All notifications respect the `oncePerDay` setting to avoid spam.