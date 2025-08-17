
# Timetracking in lua

Automatically starts on FocusGained, BufEnter and VimEnter.

Stops automatically on VimLeave

## CLI Integration

timeTrack.nvim now includes a standalone CLI tool for accessing and managing time tracking data without starting Neovim. This enables quick reporting, data entry, and maintenance tasks from the command line.

### Installation

The CLI tool is included with the plugin and requires:
- Lua interpreter
- `dkjson` library for JSON handling

To install the JSON library:
```bash
luarocks install --local dkjson
```

### Usage

The CLI provides a convenient wrapper script that handles dependencies automatically:

```bash
# Make the wrapper executable (one-time setup)
chmod +x timetrack

# Use the CLI
./timetrack <command> [options]
```

Alternatively, you can run the CLI directly with Lua:
```bash
lua timetrack-simple.lua <command> [options]
```

### Available Commands

#### Status
Show current time tracking status and weekly summary:
```bash
./timetrack status
```

#### Weekly Summary
Display a formatted weekly time summary:
```bash
./timetrack summary              # Current week
./timetrack summary 25 2024      # Week 25 of 2024
```

#### Add Time Entry
Add manual time entries:
```bash
./timetrack add "ProjectName" "filename.lua" 2.5        # Add 2.5 hours for current day
./timetrack add "ProjectName" "filename.lua" 2.5 Monday # Add 2.5 hours for Monday
```

#### List Entries
List all time entries for a specific week:
```bash
./timetrack list              # Current week
./timetrack list 25 2024      # Week 25 of 2024
```

#### Export Data
Export time data in various formats:
```bash
./timetrack export csv           # Export current week as CSV
./timetrack export markdown      # Export current week as Markdown table
./timetrack export csv 25 2024   # Export specific week
```

#### Validate Data
Check for data integrity issues:
```bash
./timetrack validate
```

### Examples

```bash
# Check current status
./timetrack status

# Add work on a project
./timetrack add "WebApp" "frontend.js" 3.5

# View this week's summary  
./timetrack summary

# Export last week's data
./timetrack export csv 51 2024 > timesheet-week51.csv

# Validate data for issues
./timetrack validate
```

The CLI tool uses the same data file as the Neovim plugin (`~/.local/share/nvim/maorun-time.json`), so all data remains synchronized between the CLI and plugin usage.

## Installation
eg:
[packer.nvim](https://github.com/wbthomason/packer.nvim)
```vim
use {
    'maorun/timeTrack.nvim',
    requires = {
        'nvim-telescope/telescope.nvim', -- optional
        'nvim-lua/plenary.nvim',
        {
            'rcarriga/nvim-notify',
            config = function()
                vim.opt.termguicolors = true
                vim.api.nvim_set_hl(0, "NotifyBackground", { bg="#000000", ctermbg=0})
            end
        }
    }
}
```

## Usage

```lua
require('maorun.time').setup({
    -- Use a predefined work model preset
    workModel = 'fourDayWeek',  -- 'standard', 'fourDayWeek', 'partTime', or 'flexibleCore'
    
    -- OR manually configure hours per weekday
    hoursPerWeekday = {
        Monday = 6,
    },
    
    -- Define core working hours (optional)
    coreWorkingHours = {
        Monday = { start = 10, finish = 16 },    -- 10 AM to 4 PM
        Tuesday = { start = 9, finish = 17 },    -- 9 AM to 5 PM
        -- ... other weekdays
    },
    
    -- Configure notifications
    notifications = {
        dailyGoal = {
            enabled = true,        -- Enable/disable daily goal notifications
            oncePerDay = true,     -- If true, notify only once when goal is reached
            recurringMinutes = 30, -- If oncePerDay is false, notify every X minutes after exceeding goal
        },
        coreHoursCompliance = {
            enabled = true,        -- Enable/disable core hours notifications
            warnOutsideCoreHours = true,  -- Warn when working outside core hours
            oncePerDay = true,     -- Only warn once per day per weekday
        },
    },
})
```

## Work Model Presets

The plugin supports predefined work models to quickly configure common working patterns:

- **`standard`**: Traditional 40-hour week (Monday-Friday, 8h/day, 9 AM-5 PM core hours)
- **`fourDayWeek`**: 4-day work week (Monday-Thursday, 8h/day, Friday off)
- **`partTime`**: Part-time schedule (Monday-Friday, 4h/day, 10 AM-2 PM core hours)
- **`flexibleCore`**: Flexible schedule with core hours (Monday-Friday, 8h/day, 10 AM-4 PM core hours)

```lua
-- Apply a work model preset
require('maorun.time').setup({ workModel = 'fourDayWeek' })

-- Or apply dynamically
Time.applyWorkModelPreset('partTime')

-- List available models
local models = Time.getAvailableWorkModels()
```

## Core Working Hours

Define specific time ranges when you're expected to be working. The plugin can notify you when time is tracked outside these core hours:

```lua
require('maorun.time').setup({
    coreWorkingHours = {
        Monday = { start = 10, finish = 16 },    -- 10 AM to 4 PM
        Tuesday = { start = 9, finish = 17 },    -- 9 AM to 5 PM
        Wednesday = nil,                         -- No core hours (flexible day)
        -- ... configure other weekdays as needed
    },
    notifications = {
        coreHoursCompliance = { enabled = true },
    },
})

-- Check if a timestamp falls within core hours
local is_core_time = Time.isWithinCoreHours(timestamp, 'Monday')
```

## Daily Goal Notifications

The plugin can show notifications when you reach or exceed your daily time goals. This feature integrates with `nvim-notify` for beautiful popup notifications.

### Configuration Options

- **`notifications.dailyGoal.enabled`** (boolean, default: `true`): Enable or disable daily goal notifications
- **`notifications.dailyGoal.oncePerDay`** (boolean, default: `true`): 
  - If `true`: Show notification only once when the daily goal is first reached
  - If `false`: Show recurring notifications based on `recurringMinutes`
- **`notifications.dailyGoal.recurringMinutes`** (number, default: `30`): When `oncePerDay` is false, show notifications every X minutes after exceeding the goal

### Notification Types

- **Goal Reached**: Shows when you complete your daily time goal (e.g., "Daily goal reached! Monday: 8.0h worked (8.0h goal)")
- **Goal Exceeded**: Shows when you work more than your daily goal (e.g., "Daily goal exceeded! Monday: 9.5h worked (8.0h goal, +1.5h over)")

### Examples

```lua
-- Minimal setup - notifications enabled by default
require('maorun.time').setup({})

-- Disable notifications
require('maorun.time').setup({
    notifications = {
        dailyGoal = {
            enabled = false,
        },
    },
})

-- Recurring notifications every 15 minutes
require('maorun.time').setup({
    notifications = {
        dailyGoal = {
            enabled = true,
            oncePerDay = false,
            recurringMinutes = 15,
        },
    },
})
```

**Note**: Notifications are only shown for weekdays with expected hours > 0 (working days).

## Core Hours Compliance Notifications

When core working hours are configured, the plugin can notify you when time is tracked outside these designated hours:

### Configuration Options

- **`notifications.coreHoursCompliance.enabled`** (boolean, default: `false`): Enable or disable core hours notifications
- **`notifications.coreHoursCompliance.warnOutsideCoreHours`** (boolean, default: `true`): Show warnings when working outside core hours
- **`notifications.coreHoursCompliance.oncePerDay`** (boolean, default: `true`): Only show one notification per day per weekday

### Notification Examples

- **Outside core hours**: "Work time outside core hours! Monday 07:00-09:00 (core: 09:00-17:00)"
- **No notification**: When all work time falls within the defined core hours

### Examples

```lua
-- Enable core hours notifications with custom hours
require('maorun.time').setup({
    coreWorkingHours = {
        Monday = { start = 10, finish = 16 },  -- 10 AM - 4 PM core hours
    },
    notifications = {
        coreHoursCompliance = {
            enabled = true,
            warnOutsideCoreHours = true,
        },
    },
})

-- Use a preset with core hours notifications
require('maorun.time').setup({
    workModel = 'flexibleCore',  -- Has 10 AM - 4 PM core hours
    notifications = {
        coreHoursCompliance = { enabled = true },
    },
})
```

## Weekly Overview (Wöchentliche Übersicht)

The plugin provides a comprehensive weekly overview command that displays a compressed summary of your time tracking data. This feature shows worked hours per day, overtime calculation, and weekly totals in an easy-to-read format.

### Basic Usage

```lua
-- Show current week overview in floating window
Time.weeklyOverview()

-- Or using the module directly
require('maorun.time').showWeeklyOverview()
```

### Display Options

The weekly overview supports multiple display modes:

```lua
-- Floating window (default)
Time.weeklyOverview({ display_mode = 'floating' })

-- New buffer
Time.weeklyOverview({ display_mode = 'buffer' })

-- Quickfix list
Time.weeklyOverview({ display_mode = 'quickfix' })
```

### Filtering Options

Filter the overview by project, file, or both:

```lua
-- Filter by specific project
Time.weeklyOverview({ project = 'MyProject' })

-- Filter by specific file
Time.weeklyOverview({ file = 'main.lua' })

-- Filter by both project and file
Time.weeklyOverview({ 
    project = 'MyProject', 
    file = 'main.lua' 
})
```

### Different Time Periods

View data for specific weeks or years:

```lua
-- Specific week and year
Time.weeklyOverview({ 
    year = '2023', 
    week = '10' 
})

-- Current year, different week
Time.weeklyOverview({ week = '45' })
```

### Interactive Features

When using the floating window (default), you can:

- Press `q` or `Esc` to close the window
- Press `f` to open filter options dialog
- Navigate through the display with arrow keys

### Sample Output

```
═══ Wöchentliche Übersicht - KW 11/2023 ═══

┌─ Tägliche Übersicht ─────────────────────────────────────┐
│ Tag        │ Gearbeitet │ Soll │ Überstunden │ Status   │
├────────────┼────────────┼──────┼─────────────┼──────────┤
│ Montag     │     8.00h │   8h │      0.00h │ 🟡 Ziel  │
│ Dienstag   │     9.00h │   8h │     +1.00h │ 🟢 Über  │
│ Mittwoch   │     7.00h │   8h │     -1.00h │ 🔴 Unter │
│ Donnerstag │     0.00h │   8h │     -8.00h │ ⚪ Frei   │
│ Freitag    │     6.00h │   8h │     -2.00h │ 🔴 Unter │
│ Samstag    │     0.00h │   0h │      0.00h │ ⚪ Frei   │
│ Sonntag    │     0.00h │   0h │      0.00h │ ⚪ Frei   │
└────────────┴────────────┴──────┴─────────────┴──────────┘

┌─ Wochenzusammenfassung ──────────────────────────────────┐
│ Gesamtarbeitszeit:    30.00 Stunden                     │
│ Soll-Arbeitszeit:     40.00 Stunden                     │
│ Überstunden:         -10.00 Stunden                     │
└──────────────────────────────────────────────────────────┘

┌─ Projekte ───────────────────────────────────────────────┐
│ WorkProject                              20.00h (66.7%) │
│ PersonalProject                          10.00h (33.3%) │
└──────────────────────────────────────────────────────────┘
```

### Status Indicators

- 🟢 **Über**: Overtime hours worked (above expected)
- 🟡 **Ziel**: Goal achieved (exactly expected hours)
- 🔴 **Unter**: Under target (below expected hours) 
- ⚪ **Frei**: No work logged (typically weekends or days off)

### Getting Raw Data

For programmatic access to the summary data:

```lua
-- Get structured summary data
local summary = require('maorun.time').getWeeklySummary({
    year = '2023',
    week = '11',
    project = 'MyProject'  -- optional filter
})

-- Access the data
print(summary.totals.totalHours)     -- Total hours worked
print(summary.totals.totalOvertime) -- Total overtime
print(summary.weekdays.Monday.workedHours) -- Monday's hours
```

## Time Export

The plugin supports exporting time tracking data in CSV and Markdown formats for weekly or monthly periods. This is useful for billing, reporting, or personal analysis.

### Export Formats

#### CSV Format
Export time entries as comma-separated values:

```lua
-- Export current week as CSV
local csv_data = require('maorun.time').exportTimeData({
    format = 'csv',
    range = 'week',
    year = '2023',
    week = '11'
})

-- Or using the global Time object
local csv_data = Time.export({
    format = 'csv',
    range = 'week'  -- defaults to current week
})
```

#### Markdown Format
Export with summary statistics and formatted tables:

```lua
-- Export current month as Markdown
local md_data = require('maorun.time').exportTimeData({
    format = 'markdown',
    range = 'month',
    year = '2023',
    month = '3'
})
```

### Export Parameters

- `format`: `'csv'` or `'markdown'` (default: `'csv'`)
- `range`: `'week'` or `'month'` (default: `'week'`)
- `year`: Year as string (default: current year)
- `week`: Week number as string (required for weekly exports, default: current week)
- `month`: Month number as string (required for monthly exports, default: current month)

### Example Output

**CSV format:**
```csv
Date,Weekday,Project,File,Start Time,End Time,Duration (Hours)
2023-03-13,Monday,WorkProject,main.lua,10:00,12:00,2.00
2023-03-13,Monday,PersonalProject,learning.md,14:00,16:00,2.00
```

**Markdown format:**
```markdown
# Time Tracking Export - Week 11

## Summary

**Total Time:** 4.00 hours

**Time by Project:**
- WorkProject: 2.00 hours
- PersonalProject: 2.00 hours

## Detailed Entries

| Date | Weekday | Project | File | Start | End | Duration |
|------|---------|---------|------|-------|-----|----------|
| 2023-03-13 | Monday | WorkProject | main.lua | 10:00 | 12:00 | 2.00 h |
| 2023-03-13 | Monday | PersonalProject | learning.md | 14:00 | 16:00 | 2.00 h |
```

## Data Storage Format
The data is stored in a JSON file. The default path is `~/.local/share/nvim/maorun-time.json` (or equivalent `vim.fn.stdpath('data') .. '/maorun-time.json'`).

The structure of the JSON file is as follows:
The `summary` object within each weekday (e.g., `Monday.summary`) now contains the total `diffInHours` for that day and the daily `overhour`. The `summary` for individual files (e.g., `feature-task.lua.summary`) only contains `diffInHours` for that specific file.

```json
{
  "hoursPerWeekday": {
    "Monday": 8,
    "Tuesday": 8,
    "Wednesday": 8,
    "Thursday": 8,
    "Friday": 8,
    "Saturday": 0,
    "Sunday": 0
  },
  "paused": false,
  "data": {
    "YYYY": {
      "WW": {
        "summary": {
          "overhour": -1.0
        },
        "Monday": {
          "summary": {
            "diffInHours": 8.5,
            "overhour": 0.5
          },
          "WorkProject": {
            "feature-task.lua": {
              "summary": {
                "diffInHours": 6.5
              },
              "items": [
                {
                  "startTime": 1678886400,
                  "startReadable": "10:00",
                  "endTime": 1678890000,
                  "endReadable": "11:00",
                  "diffInHours": 1.0
                },
                {
                  "startTime": 1678893600,
                  "startReadable": "12:00",
                  "endTime": 1678913100,
                  "endReadable": "17:30",
                  "diffInHours": 5.5
                }
              ]
            }
          },
          "PersonalProject": {
            "learning.md": {
              "summary": {
                "diffInHours": 2.0
              },
              "items": [
                {
                  "startTime": 1678915200,
                  "startReadable": "18:00",
                  "endTime": 1678922400,
                  "endReadable": "20:00",
                  "diffInHours": 2.0
                }
              ]
            }
          }
        },
        "Tuesday": {
          "summary": {
            "diffInHours": 6.5,
            "overhour": -1.5
          },
          "WorkProject": {
            "bug-fix.lua": {
              "summary": {
                "diffInHours": 6.5
              },
              "items": [
                {
                  "startTime": 1678963200,
                  "startReadable": "09:00",
                  "endTime": 1678988100,
                  "endReadable": "15:30",
                  "diffInHours": 6.5
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

## Suggested keymapping with [which-key](https://github.com/folke/which-key.nvim)
```lua
local wk = require("which-key")
wk.register({
    t = {
        name = "Time",
        s = {"<cmd>lua Time.TimeStop()<cr>", "TimeStop", noremap = true},
        a = {"<cmd>lua Time.add()<cr>", "add hours to a day", noremap = true},
        r = {"<cmd>lua Time.subtract()<cr>", "subtract hours from a day", noremap = true},
        f = {"<cmd>lua Time.set()<cr>", "set hours of a day (clears all entries)", noremap = true},
    },
}, { prefix = "<leader>" })
```

## Development

### Development Environment Setup

This project uses `stylua` for formatting and `vusted` for testing. The `install.sh` script helps install these tools using Luarocks. The script also attempts to install necessary dependencies like Luarocks if they are missing (on supported systems like Linux/macOS).

**Prerequisites:**

*   **Luarocks:** Used for installing `vusted` and `stylua`. The `install.sh` script will attempt to install Luarocks if it's not found on your system (for Linux and macOS). For other operating systems, or if the automatic installation fails, you might need to install it manually from [https://luarocks.org/wiki/rock/Installation](https://luarocks.org/wiki/rock/Installation).

**Installation:**

**For Windows users:** The `install.sh` script is primarily designed for Linux and macOS. If you run it on Windows, it will detect the OS and print a message with guidance for manual installation of Luarocks and the other development dependencies, as automatic installation is not supported for Windows via this script.

1.  Run the script:
    ```sh
    ./install.sh
    ```
    This will check for Luarocks and then install `stylua` and `vusted`.

### Running Tests

After setting up the environment and installing `vusted`, you can run tests using:
```sh
vusted ./test
```

## Test Coverage
The code coverage report is automatically generated by our CI workflow using `luacov` after tests are run with `vusted`.
The latest summary is:

```markdown
File                                                                         Hits Missed Coverage
-------------------------------------------------------------------------------------------------
/home/runner/work/timeTrack.nvim/timeTrack.nvim/lua/maorun/time/autocmds.lua 16   28     36.36%
/home/runner/work/timeTrack.nvim/timeTrack.nvim/lua/maorun/time/config.lua   17   0      100.00%
/home/runner/work/timeTrack.nvim/timeTrack.nvim/lua/maorun/time/core.lua     315  19     94.31%
/home/runner/work/timeTrack.nvim/timeTrack.nvim/lua/maorun/time/init.lua     34   32     51.52%
/home/runner/work/timeTrack.nvim/timeTrack.nvim/lua/maorun/time/ui.lua       31   24     56.36%
/home/runner/work/timeTrack.nvim/timeTrack.nvim/lua/maorun/time/utils.lua    49   4      92.45%
-------------------------------------------------------------------------------------------------
Total                                                                        462  107    81.20%
```
