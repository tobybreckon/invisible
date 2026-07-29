#!/usr/bin/env bash

###############################################################################

# First set chromium as the default external browser in MATE

xdg-settings set default-web-browser chromium.desktop

echo "MATE: default-web-browser: chromium.desktop"
echo

###############################################################################

# Second, set chromium as the default external browser in VS Code
# by updating "workbench.externalBrowser" in settings.json.

set -euo pipefail

# --- 1. Locate the Chromium binary -----------------------------------------
BROWSER="${1:-}" # can specify path on command line

if [[ -z "$BROWSER" ]]; then
    for candidate in chromium chromium-browser; do
        if command -v "$candidate" >/dev/null 2>&1; then
            BROWSER="$(command -v "$candidate")"
            break
        fi
    done
fi

if [[ -z "$BROWSER" ]]; then
    echo "Error: Chromium not found in PATH." >&2
    echo "Install it or pass the path explicitly: $0 /path/to/chromium" >&2
    exit 1
fi

echo "Using browser: $BROWSER"

# --- 2. Locate the VS Code settings.json -----------------------------------
# Covers VS Code, VS Code OSS, VSCodium on Linux
CONFIG_CANDIDATES=(
    "$HOME/.config/Code/User/settings.json"
    "$HOME/.config/Code - OSS/User/settings.json"
    "$HOME/.config/VSCodium/User/settings.json"
)

SETTINGS=""
for f in "${CONFIG_CANDIDATES[@]}"; do
    if [[ -f "$f" ]]; then
        SETTINGS="$f"
        break
    fi
done

# If none exists, create the standard one
if [[ -z "$SETTINGS" ]]; then
    SETTINGS="$HOME/.config/Code/User/settings.json"
    mkdir -p "$(dirname "$SETTINGS")"
    echo '{}' > "$SETTINGS"
    echo "Created new settings file: $SETTINGS"
else
    echo "Found settings file: $SETTINGS"
fi

# --- 3. Update the setting ---------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required. Install it with your package manager (e.g. sudo apt install jq)." >&2
    exit 1
fi

# Backup first
cp "$SETTINGS" "${SETTINGS}.bak"
echo "Backup saved to: ${SETTINGS}.bak"

# Strip // line comments (JSONC -> JSON) so jq can parse, then set the key.
# Note: this removes comments from the file; the .bak preserves the original.
TMP="$(mktemp)"
sed 's|^\s*//.*$||' "$SETTINGS" | jq --arg browser "$BROWSER" \
    '. + {"workbench.externalBrowser": $browser}' > "$TMP"

mv "$TMP" "$SETTINGS"

echo "Done. 'workbench.externalBrowser' set to: $BROWSER"
echo "Restart VS Code (or reload the window) for the change to take effect."
echo

###############################################################################