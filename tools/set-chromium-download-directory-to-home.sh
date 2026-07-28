#!/bin/bash

# Script to set Chromium download directory to user's home directory

# Determine the correct Chromium config path
# Chromium uses one of these depending on distro/install method
POSSIBLE_PATHS=(
    "$HOME/.config/chromium"
    "$HOME/snap/chromium/common/chromium"
    "$HOME/.var/app/org.chromium.Chromium/config/chromium"
)

CONFIG_DIR=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        CONFIG_DIR="$path"
        break
    fi
done

# Fall back to the standard path if none exist yet
if [ -z "$CONFIG_DIR" ]; then
    CONFIG_DIR="$HOME/.config/chromium"
fi

PREFS_FILE="$CONFIG_DIR/Default/Preferences"
DOWNLOAD_DIR="$HOME"

# Make sure Chromium is not running (it overwrites Preferences on exit)
if pgrep -x "chromium" > /dev/null; then
    echo "Error: Chromium is running. Please close it before running this script."
    exit 1
fi

# Ensure the Default profile directory exists
mkdir -p "$CONFIG_DIR/Default"

# Create Preferences file if it doesn't exist
if [ ! -f "$PREFS_FILE" ]; then
    echo "{}" > "$PREFS_FILE"
fi

# Use jq if available for safe JSON editing; otherwise use python
if command -v jq > /dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg dir "$DOWNLOAD_DIR" \
        '.download.default_directory = $dir
         | .download.prompt_for_download = false
         | .savefile.default_directory = $dir' \
        "$PREFS_FILE" > "$tmp" && mv "$tmp" "$PREFS_FILE"
    echo "Updated download directory to: $DOWNLOAD_DIR (using jq)"
elif command -v python3 > /dev/null 2>&1; then
    python3 - "$PREFS_FILE" "$DOWNLOAD_DIR" <<'EOF'
import json, sys

prefs_file, download_dir = sys.argv[1], sys.argv[2]

try:
    with open(prefs_file) as f:
        prefs = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    prefs = {}

prefs.setdefault("download", {})
prefs["download"]["default_directory"] = download_dir
prefs["download"]["prompt_for_download"] = False
prefs.setdefault("savefile", {})
prefs["savefile"]["default_directory"] = download_dir

with open(prefs_file, "w") as f:
    json.dump(prefs, f)

print(f"Updated download directory to: {download_dir} (using python3)")
EOF
else
    echo "Error: Neither jq nor python3 found. Please install one of them."
    exit 1
fi

echo "Done. Restart Chromium for changes to take effect."