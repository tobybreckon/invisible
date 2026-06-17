#!/usr/bin/env bash
# =============================================================================
# set_vscode_directory.sh
# Sets the directory that Visual Studio Code will open on next launch.
# Usage: ./set_vscode_directory.sh /path/to/your/directory
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# ANSI colour helpers
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -----------------------------------------------------------------------------
# 1. INPUT VALIDATION
# -----------------------------------------------------------------------------
if [[ $# -ne 1 ]]; then
    error "Exactly one argument required."
    echo -e "Usage: ${BOLD}$0 /path/to/directory${NC}"
    exit 1
fi

TARGET_DIR="$(realpath "$1" 2>/dev/null || true)"

if [[ -z "$TARGET_DIR" ]]; then
    error "Could not resolve path: '$1'"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    error "Directory does not exist: '$TARGET_DIR'"
    exit 1
fi

info "Target directory validated: ${BOLD}$TARGET_DIR${NC}"

# -----------------------------------------------------------------------------
# 2. LOCATE VS CODE storage.json
# -----------------------------------------------------------------------------
VSCODE_DIRS=(
    "$HOME/.config/Code"
    "$HOME/.config/Code - Insiders"
    "$HOME/.config/VSCodium"
)

STORAGE_FILE=""
VSCODE_CONFIG_DIR=""

for dir in "${VSCODE_DIRS[@]}"; do
    candidate="$dir/User/globalStorage/storage.json"
    if [[ -f "$candidate" ]]; then
        STORAGE_FILE="$candidate"
        VSCODE_CONFIG_DIR="$dir"
        info "Found storage.json: ${BOLD}$STORAGE_FILE${NC}"
        break
    fi
done

if [[ -z "$STORAGE_FILE" ]]; then
    warn "storage.json not found in any known VS Code config location."
    warn "Checked:"
    for dir in "${VSCODE_DIRS[@]}"; do
        warn "  $dir/User/globalStorage/storage.json"
    done
    warn "VS Code may not have been launched yet, or uses a custom path."
    warn "Skipping storage.json update — only the launcher and saved-path file will be written."
fi

# -----------------------------------------------------------------------------
# 3. BACKUP storage.json
# -----------------------------------------------------------------------------
if [[ -n "$STORAGE_FILE" ]]; then
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    BACKUP_FILE="${STORAGE_FILE}.bak_${TIMESTAMP}"
    cp "$STORAGE_FILE" "$BACKUP_FILE"
    success "Backup created: ${BOLD}$BACKUP_FILE${NC}"
fi

# -----------------------------------------------------------------------------
# 4. UPDATE storage.json (Python 3 handles the JSON safely)
# -----------------------------------------------------------------------------
if [[ -n "$STORAGE_FILE" ]]; then
    info "Updating storage.json with target directory..."

    python3 - "$STORAGE_FILE" "$TARGET_DIR" <<'PYEOF'
import sys
import json
import os

storage_path = sys.argv[1]
target_dir   = sys.argv[2]

# VS Code uses a URI-style path for folder entries
folder_uri = "file://" + target_dir

with open(storage_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# ── windowsState ──────────────────────────────────────────────────────────
if "windowsState" not in data or not isinstance(data["windowsState"], dict):
    data["windowsState"] = {}

ws = data["windowsState"]

# lastActiveWindow
if "lastActiveWindow" not in ws or not isinstance(ws["lastActiveWindow"], dict):
    ws["lastActiveWindow"] = {}

ws["lastActiveWindow"]["folder"]          = folder_uri
ws["lastActiveWindow"]["folderUri"]       = {"scheme": "file", "path": target_dir}

# openedWindows — prepend so VS Code picks it up first
entry = {
    "folder":    folder_uri,
    "folderUri": {"scheme": "file", "path": target_dir}
}

if "openedWindows" not in ws or not isinstance(ws["openedWindows"], list):
    ws["openedWindows"] = []

# Remove any existing entry for the same folder to avoid duplicates
ws["openedWindows"] = [
    w for w in ws["openedWindows"]
    if w.get("folder") != folder_uri and w.get("folderUri", {}).get("path") != target_dir
]
ws["openedWindows"].insert(0, entry)

# ── lastActiveWindow (top-level, older VS Code versions) ──────────────────
if "lastActiveWindow" not in data or not isinstance(data["lastActiveWindow"], dict):
    data["lastActiveWindow"] = {}

data["lastActiveWindow"]["folder"] = folder_uri

# ── Write back ────────────────────────────────────────────────────────────
with open(storage_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")   # POSIX-friendly trailing newline

print(f"storage.json updated successfully.")
PYEOF

    success "storage.json updated successfully."
fi

# -----------------------------------------------------------------------------
# 6. SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  VS Code Launch Directory Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo -e "  Directory set : ${GREEN}${TARGET_DIR}${NC}"
if [[ -n "$STORAGE_FILE" ]]; then
echo -e "  storage.json  : ${GREEN}${STORAGE_FILE}${NC}"
echo -e "  Backup        : ${GREEN}${BACKUP_FILE}${NC}"
fi