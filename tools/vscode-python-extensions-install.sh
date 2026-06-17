#!/usr/bin/env bash

set -e

# Detect VS Code command
if command -v code >/dev/null 2>&1; then
    VSCODE_CMD="code"
elif command -v code-insiders >/dev/null 2>&1; then
    VSCODE_CMD="code-insiders"
else
    echo "Error: VS Code command-line tool 'code' was not found."
    echo "Open VS Code, then enable it from:"
    echo "Command Palette → Shell Command: Install 'code' command in PATH"
    exit 1
fi

echo "Using VS Code command: $VSCODE_CMD"

# Python-related extensions
EXTENSIONS=(
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.debugpy"
)

echo "Installing Python extensions for VS Code..."

for extension in "${EXTENSIONS[@]}"; do
    echo "Installing: $extension"
    "$VSCODE_CMD" --install-extension "$extension" --force
done

echo "Done. Python extensions installed successfully."