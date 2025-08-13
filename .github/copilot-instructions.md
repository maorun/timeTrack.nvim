# timeTrack.nvim Development Instructions

timeTrack.nvim is a Neovim plugin written in Lua for automated time tracking. It tracks time spent in different projects and files, with automatic start/stop functionality based on Neovim events.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap and Setup Development Environment

Run the following commands to set up the complete development environment:

```bash
# Navigate to project root
cd /path/to/timeTrack.nvim

# Run setup script - NEVER CANCEL: Takes 10-15 minutes. Set timeout to 30+ minutes.
./install.sh
```

The install script will:
- Detect OS (Linux/macOS) and install Neovim if missing
- Install Luarocks package manager 
- Install vusted (Lua testing framework) for Lua 5.1
- Install stylua (Lua formatter) from GitHub releases
- Install inspect (Lua pretty-printing library)

**Windows users**: The install script provides manual installation guidance for Windows systems.

### Set Up Environment Variables

Before running any Lua tools, always set up the proper LUA_PATH:

```bash
# CRITICAL: Always run this before vusted or other Lua tools
eval "$(luarocks path)"
```

### Testing

Run the test suite using vusted:

```bash
# Set up environment first
eval "$(luarocks path)"

# Run tests - Takes ~0.3 seconds normally. Set timeout to 5+ minutes for safety.
vusted ./test
```

Expected output: 64 tests passing (some UI tests may fail but core functionality passes).

### Code Formatting and Linting

Check code formatting with stylua:

```bash
# Check formatting - Takes ~0.2 seconds
stylua --check .

# Auto-format code 
stylua .
```

## Validation

### Always Run Before Committing

Execute this validation sequence before making any pull request:

```bash
# 1. Set up environment
eval "$(luarocks path)"

# 2. Run tests - NEVER CANCEL: Set timeout to 5+ minutes
vusted ./test

# 3. Check formatting
stylua --check .

# 4. If formatting check fails, auto-format
stylua .
```

### Manual Testing Scenarios

Since this is a Neovim plugin that requires a complete Neovim environment with dependencies, manual testing requires:

1. **Neovim with plugin loaded**: The plugin requires plenary.nvim and nvim-notify dependencies
2. **Test time tracking**: Use TimeStart/TimeStop commands to verify basic functionality
3. **Data storage**: Verify JSON file is created at `~/.local/share/nvim/maorun-time.json`

**Note**: The automated test suite provides comprehensive validation of plugin functionality without requiring a full Neovim setup.

#### Functional Testing Workflow

When making changes to plugin functionality, always validate using this sequence:

```bash
# 1. Run full test suite to catch regressions
eval "$(luarocks path)"
vusted ./test

# 2. Look for specific test results
# - Expected: "# Success: 64" (or current test count)
# - Some UI tests may fail without interactive environment
# - Core functionality tests should all pass

# 3. Check for new test failures after your changes
# If tests fail that previously passed, investigate immediately
```

## Development Workflow

### Project Structure

```
timeTrack.nvim/
├── lua/maorun/time/          # Main plugin code
│   ├── init.lua             # Plugin entry point
│   ├── core.lua             # Core time tracking logic  
│   ├── config.lua           # Configuration management
│   ├── utils.lua            # Utility functions
│   ├── ui.lua               # User interface components
│   ├── autocmds.lua         # Neovim autocommands
│   └── weekday_select.lua   # Weekday selection helpers
├── test/                    # Test files (vusted framework)
├── doc/                     # Generated documentation
├── install.sh               # Development environment setup
├── .stylua.toml            # Stylua configuration
├── .luacov                 # Code coverage configuration
└── README.md               # Project documentation
```

### Important Files to Check When Making Changes

- **Always check `lua/maorun/time/core.lua`** after making changes to time calculation logic
- **Always check `lua/maorun/time/config.lua`** after making changes to configuration handling
- **Always check corresponding test files** in `test/` directory after making changes to any module

### CI/CD Pipeline

The repository uses GitHub Actions with these jobs:

1. **lint**: Runs stylua formatting check
2. **test**: Runs vusted test suite on Ubuntu and macOS  
3. **docs**: Generates documentation using panvimdoc
4. **coverage**: Generates code coverage reports using luacov

All jobs must pass for pull requests to be merged.

## Common Commands Reference

```bash
# Development setup (one-time)
./install.sh

# Before any development work
eval "$(luarocks path)"

# Run tests
vusted ./test

# Check formatting  
stylua --check .

# Auto-format code
stylua .

# Check Neovim version
nvim --version

# Check installed Lua tools
luarocks list --local
```

## Timing and Timeouts

- **Install script**: 10-15 minutes - NEVER CANCEL. Set timeout to 30+ minutes.
- **Test suite**: ~0.3 seconds normally - Set timeout to 5+ minutes for safety.
- **Stylua check**: ~0.2 seconds - Set timeout to 2+ minutes for safety.

**CRITICAL**: DO NOT cancel long-running operations. The install script especially may appear to hang during package installation but is working correctly. Always wait for completion.

## Troubleshooting

### Common Issues

1. **vusted command not found**: Run `eval "$(luarocks path)"` first
2. **Module not found errors**: Ensure luarocks dependencies are installed via `./install.sh`
3. **Test failures**: Some UI tests may fail without full Neovim environment, but core tests should pass
4. **Windows compatibility**: Use manual installation guidance provided by install script

### Plugin Dependencies

The plugin requires these Neovim plugins at runtime:
- `nvim-lua/plenary.nvim` (required)
- `rcarriga/nvim-notify` (required) 
- `nvim-telescope/telescope.nvim` (optional)

Tests automatically clone required dependencies to avoid external dependency issues.

## Expected Development Patterns

- **Test-driven development**: Write tests in `test/` directory using vusted framework
- **Formatting consistency**: Always run stylua before committing
- **Modular architecture**: Keep functionality separated in appropriate modules under `lua/maorun/time/`
- **Documentation**: Update README.md when adding new features or changing functionality

## Complete Development Checklist

Use this checklist for any code changes:

```bash
# Pre-work setup
cd /path/to/timeTrack.nvim
eval "$(luarocks path)"

# Development cycle
# 1. Make your changes
# 2. Run tests (NEVER CANCEL - wait for completion)
vusted ./test
# Expected output: "# Success: 64" (or current test count)

# 3. Check formatting 
stylua --check .
# If this fails, run: stylua .

# 4. Verify changes are ready
stylua --check .  # Should pass after auto-format

# 5. Double-check tests still pass
vusted ./test

# Ready for commit!
```

**Success criteria**: 
- All tests pass (64+ successful tests)
- No formatting violations
- No new test failures introduced