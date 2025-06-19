
# Timetracking in lua

Automatically starts on FocusGained, BufEnter and VimEnter.

Stops automatically on VimLeave

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
    -- every weekday is 8 hours on default. If you wish to reduce it: set it here
    hoursPerWeekday = {
        Monday = 6,
    }
})
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
