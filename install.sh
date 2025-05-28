#!/bin/bash

# OS detection
CURRENT_OS="unknown"
if [[ "$(uname)" == "Linux" ]]; then
    CURRENT_OS="linux"
elif [[ "$(uname)" == "Darwin" ]]; then
    CURRENT_OS="macos"
elif [[ -n "${OS}" && "${OS}" == "Windows_NT" ]]; then # Check common env var for Windows
    CURRENT_OS="windows"
elif [[ -n "${OSTYPE}" && "${OSTYPE}" == "msys" ]]; then # Check for Git Bash
    CURRENT_OS="windows"
elif [[ -n "${OSTYPE}" && "${OSTYPE}" == "cygwin" ]]; then # Check for Cygwin
    CURRENT_OS="windows"
fi

if [[ "${CURRENT_OS}" == "windows" ]]; then
    echo "Automatic installation of Cargo and Luarocks is not supported on Windows. Please install them manually from https://rustup.rs/ and https://luarocks.org/wiki/rock/Installation"
    exit 0
fi

echo "Starting development environment setup..."

# Check for Cargo
if ! command -v cargo &> /dev/null
then
    if [[ "${CURRENT_OS}" == "linux" ]] || [[ "${CURRENT_OS}" == "macos" ]]; then
        echo "Cargo not found. Attempting to install via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # Source the cargo environment script to make cargo available in the current session
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
        else
            # Fallback if .cargo/env doesn't exist, though rustup should create it.
            # Attempt to add to PATH directly, common for non-login shells or if .profile/.bashrc isn't sourced.
            export PATH="$HOME/.cargo/bin:$PATH"
        fi

        if ! command -v cargo &> /dev/null; then
            echo "Cargo installation failed. Please check the output above or install manually from https://rustup.rs/"
            exit 1
        else
            echo "Cargo installed successfully."
            cargo --version # Print version for confirmation
        fi
    else
        # Fallback for other OSes (though Windows is handled earlier)
        echo "Cargo not found. Please install Rust and Cargo from https://rustup.rs/"
        exit 1
    fi
fi

echo "Installing stylua..."
cargo install stylua

# Check for Luarocks
if ! command -v luarocks &> /dev/null
then
    if [[ "${CURRENT_OS}" == "linux" ]]; then
        echo "Luarocks not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y luarocks
        elif command -v yum &> /dev/null; then
            sudo yum install -y luarocks
            # Add a note about potential package name variations for yum
            if ! command -v luarocks &> /dev/null; then
                 echo "Luarocks installation with 'yum install luarocks' may have failed due to package name variations (e.g., lua-luarocks). Trying 'sudo yum install -y lua-luarocks'."
                 sudo yum install -y lua-luarocks
            fi
        else
            echo "Could not find apt-get or yum. Please install Luarocks manually from https://luarocks.org/wiki/rock/Installation"
            exit 1
        fi

        if ! command -v luarocks &> /dev/null; then
            echo "Luarocks installation failed. Please install manually from https://luarocks.org/wiki/rock/Installation"
            exit 1
        else
            echo "Luarocks installed successfully."
        fi
    elif [[ "${CURRENT_OS}" == "macos" ]]; then
        echo "Luarocks not found. Attempting to install via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Please install Homebrew first (see https://brew.sh/) and then install Luarocks manually or re-run this script."
            exit 1
        fi
        brew install luarocks
        if ! command -v luarocks &> /dev/null; then
            echo "Luarocks installation via Homebrew failed. Please install manually from https://luarocks.org/wiki/rock/Installation"
            exit 1
        else
            echo "Luarocks installed successfully."
        fi
    else
        # Fallback for other OSes (though Windows is handled earlier)
        echo "Luarocks not found. Please install Luarocks from https://luarocks.org/wiki/rock/Installation"
        exit 1
    fi
fi

echo "Installing vusted..."
luarocks install vusted

echo "Development environment setup complete!"
