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

This project uses a Luarocks rockspec file (`timeTrack.nvim-scm-1.rockspec`) to manage development and build dependencies, including `stylua` for formatting and `vusted` for testing.

The `install.sh` script in the root of this repository automates the setup process by using `luarocks make` with the rockspec file.

**Prerequisites:**

*   **Neovim:** Ensure you have Neovim installed. You can find installation instructions at [Installing Neovim](https://github.com/neovim/neovim/wiki/Installing-Neovim).
*   **Luarocks:** This is essential for installing dependencies via the rockspec. If you don't have Luarocks, install it from [https://luarocks.org/wiki/rock/Installation](https://luarocks.org/wiki/rock/Installation).
*   **Rust/Cargo:** `stylua` is written in Rust. While Luarocks will handle its installation as a dependency, having Rust/Cargo installed can be beneficial for troubleshooting or direct use. Install them from [https://rustup.rs/](https://rustup.rs/).

**Installation:**

1.  Run the script:
    ```sh
    ./install.sh
    ```
    This script will use Luarocks to install all necessary dependencies as defined in the `timeTrack.nvim-scm-1.rockspec` file.

### Running Tests

After setting up the environment and installing `vusted`, you can run tests using:
```sh
vusted ./test
```
