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
