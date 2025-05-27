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

This project uses `stylua` for formatting Lua code and `vusted` for running tests.
The `install.sh` script in the root of this repository will help you install these tools.

**Prerequisites:**

*   **Neovim:** Ensure you have Neovim installed. You can find installation instructions at [Installing Neovim](https://github.com/neovim/neovim/wiki/Installing-Neovim).
*   **Rust/Cargo:** `stylua` is installed via Cargo. If you don't have Rust and Cargo, install them from [https://rustup.rs/](https://rustup.rs/).
*   **Luarocks:** `vusted` is installed via Luarocks. If you don't have Luarocks, install it from [https://luarocks.org/wiki/rock/Installation](https://luarocks.org/wiki/rock/Installation).

**Installation:**

1.  Run the script:
    ```sh
    ./install.sh
    ```
    This will check for Cargo and Luarocks, then install `stylua` and `vusted`.

### Running Tests

After setting up the environment and installing `vusted`, you can run tests using:
```sh
vusted ./test
```
