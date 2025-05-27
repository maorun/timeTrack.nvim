#!/bin/bash

echo "Starting development environment setup..."

# Check for Cargo
if ! command -v cargo &> /dev/null
then
    echo "Cargo not found. Please install Rust and Cargo from https://rustup.rs/"
    exit 1
fi

echo "Installing stylua..."
cargo install stylua

# Check for Luarocks
if ! command -v luarocks &> /dev/null
then
    echo "Luarocks not found. Please install Luarocks from https://luarocks.org/wiki/rock/Installation"
    exit 1
fi

echo "Installing vusted..."
luarocks install vusted

echo "Development environment setup complete!"
