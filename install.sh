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

echo "Installing stylua from GitHub release..."
# Ensure curl and unzip are installed
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y curl unzip
elif command -v yum &> /dev/null; then
    sudo yum install -y curl unzip
else
    echo "apt-get or yum not found. Cannot install curl and unzip. Please install them manually."
fi

STYLUA_VERSION="v2.1.0"
STYLUA_ARTIFACT_NAME="stylua-linux-x86_64.zip"
STYLUA_DOWNLOAD_URL="https://github.com/JohnnyMorganz/StyLua/releases/download/${STYLUA_VERSION}/${STYLUA_ARTIFACT_NAME}"
STYLUA_BIN_DIR="$HOME/.luarocks/bin" # Using this as it's already added to PATH by luarocks setup

# Create the target bin directory if it doesn't exist
mkdir -p "${STYLUA_BIN_DIR}"

echo "Downloading stylua from ${STYLUA_DOWNLOAD_URL}..."
if curl -L "${STYLUA_DOWNLOAD_URL}" -o "/tmp/${STYLUA_ARTIFACT_NAME}"; then
    echo "Unzipping stylua..."
    if unzip -o "/tmp/${STYLUA_ARTIFACT_NAME}" -d "/tmp"; then
        echo "Making stylua executable and moving to ${STYLUA_BIN_DIR}..."
        chmod +x "/tmp/stylua"
        if mv "/tmp/stylua" "${STYLUA_BIN_DIR}/stylua"; then
            echo "stylua installed successfully to ${STYLUA_BIN_DIR}/stylua"
        else
            echo "Failed to move stylua to ${STYLUA_BIN_DIR}."
        fi
    else
        echo "Failed to unzip stylua."
    fi
    rm -f "/tmp/${STYLUA_ARTIFACT_NAME}" # Clean up zip
    rm -f "/tmp/stylua" # Clean up extracted binary if mv failed or it's the same location
else
    echo "Failed to download stylua."
fi

echo "Verifying stylua installation..."
if command -v stylua &> /dev/null; then
    stylua --version
else
    echo "stylua command not found after installation attempt."
fi

echo "Installing vusted for Lua 5.1..."
if ! luarocks install --local vusted --lua-version=5.1; then
    echo "Failed to install vusted for Lua 5.1."
    echo "Checking if vusted is available for other Lua versions..."
    # Note: --local might not be compatible with --check-lua-versions for some luarocks versions or packages.
    # We'll try without --local for the check command.
    if ! luarocks install vusted --check-lua-versions; then
        echo "Failed to check other Lua versions for vusted."
    fi
    echo "Please check the output above and the Luarocks website (luarocks.org) for vusted compatibility."
    # Decide if exiting here is the best course of action or just warn
    # For now, we'll just warn and continue. The script doesn't verify vusted installation with a command.
fi

echo "Installing inspect..."
luarocks install --local inspect

echo "Development environment setup complete!"
