#!/usr/bin/env bash
# =============================================================================
# set_vscode_directory.sh
# Sets the directory that Visual Studio Code will open on next launch.
# Creates a valid storage.json if one does not already exist.
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
# 2. LOCATE OR CREATE VS CODE storage.json
# -----------------------------------------------------------------------------
VSCODE_DIRS=(
    "$HOME/.config/Code"
    "$HOME/.config/Code - Insiders"
    "$HOME/.config/VSCodium"
)

STORAGE_FILE=""
VSCODE_CONFIG_DIR=""
STORAGE_CREATED=false

# ── First pass: check if any storage.json already exists ──────────────────
for dir in "${VSCODE_DIRS[@]}"; do
    candidate="$dir/User/globalStorage/storage.json"
    if [[ -f "$candidate" ]]; then
        STORAGE_FILE="$candidate"
        VSCODE_CONFIG_DIR="$dir"
        info "Found existing storage.json: ${BOLD}$STORAGE_FILE${NC}"
        break
    fi
done

# ── Second pass: if not found, detect installed VS Code variant and create ─
if [[ -z "$STORAGE_FILE" ]]; then
    warn "No existing storage.json found. Detecting installed VS Code variant..."

    # Map each config dir to the binary that would create it
    declare -A VARIANT_BINS=(
        ["$HOME/.config/Code"]="code"
        ["$HOME/.config/Code - Insiders"]="code-insiders"
        ["$HOME/.config/VSCodium"]="codium"
    )

    CHOSEN_DIR=""

    # Prefer whichever binary is actually installed
    for dir in "${VSCODE_DIRS[@]}"; do
        bin="${VARIANT_BINS[$dir]}"
        if command -v "$bin" &>/dev/null; then
            CHOSEN_DIR="$dir"
            info "Detected installed variant: ${BOLD}$bin${NC} → config dir: ${BOLD}$dir${NC}"
            break
        fi
    done

    # Fallback: default to standard Code location even if binary not found
    if [[ -z "$CHOSEN_DIR" ]]; then
        CHOSEN_DIR="${VSCODE_DIRS[0]}"
        warn "No VS Code binary detected. Defaulting to: ${BOLD}$CHOSEN_DIR${NC}"
    fi

    STORAGE_FILE="$CHOSEN_DIR/User/globalStorage/storage.json"
    VSCODE_CONFIG_DIR="$CHOSEN_DIR"

    # Create the full directory tree
    mkdir -p "$(dirname "$STORAGE_FILE")"
    info "Created directory tree: ${BOLD}$(dirname "$STORAGE_FILE")${NC}"

    # Write a minimal but valid storage.json skeleton
    cat > "$STORAGE_FILE" <<'SKELETON'
{
  "windowsState": {
    "lastActiveWindow": {},
    "openedWindows": []
  },
  "lastActiveWindow": {}
}
SKELETON

    STORAGE_CREATED=true
    success "Created new storage.json: ${BOLD}$STORAGE_FILE${NC}"
fi

# -----------------------------------------------------------------------------
# 3. BACKUP storage.json (always, whether pre-existing or freshly created)
# -----------------------------------------------------------------------------
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${STORAGE_FILE}.bak_${TIMESTAMP}"
cp "$STORAGE_FILE" "$BACKUP_FILE"
success "Backup created: ${BOLD}$BACKUP_FILE${NC}"

# -----------------------------------------------------------------------------
# 4. UPDATE storage.json (Python 3 handles the JSON safely)
# -----------------------------------------------------------------------------
info "Updating storage.json with target directory..."

python3 - "$STORAGE_FILE" "$TARGET_DIR" <<'PYEOF'
import sys
import json
import os
from datetime import datetime, timezone

storage_path = sys.argv[1]
target_dir   = sys.argv[2]

# VS Code uses a URI-style path for folder entries
folder_uri = "file://" + target_dir

# ── Load existing file (guaranteed to exist at this point) ────────────────
with open(storage_path, "r", encoding="utf-8") as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        print("[WARN] storage.json was not valid JSON — rebuilding from scratch.")
        data = {}

# ── Ensure top-level keys are present ────────────────────────────────────
if not isinstance(data.get("windowsState"), dict):
    data["windowsState"] = {}

if not isinstance(data["windowsState"].get("lastActiveWindow"), dict):
    data["windowsState"]["lastActiveWindow"] = {}

if not isinstance(data["windowsState"].get("openedWindows"), list):
    data["windowsState"]["openedWindows"] = []

if not isinstance(data.get("lastActiveWindow"), dict):
    data["lastActiveWindow"] = {}

# ── Build the folder entry ────────────────────────────────────────────────
folder_entry = {
    "folder":    folder_uri,
    "folderUri": {
        "scheme":    "file",
        "authority": "",
        "path":      target_dir,
        "query":     "",
        "fragment":  ""
    }
}

# ── windowsState.lastActiveWindow ─────────────────────────────────────────
law = data["windowsState"]["lastActiveWindow"]
law["folder"]    = folder_uri
law["folderUri"] = folder_entry["folderUri"]

# Optional metadata VS Code sometimes writes
law.setdefault("id",           str(int(datetime.now(timezone.utc).timestamp() * 1000)))
law.setdefault("mode",         "normal")
law.setdefault("isFullScreen", False)
law.setdefault("isMaximized",  False)

# ── windowsState.openedWindows — prepend, dedup ───────────────────────────
ow = data["windowsState"]["openedWindows"]
ow = [
    w for w in ow
    if w.get("folder") != folder_uri
    and w.get("folderUri", {}).get("path") != target_dir
]
ow.insert(0, folder_entry)
data["windowsState"]["openedWindows"] = ow

# ── lastActiveWindow (top-level, used by older VS Code versions) ──────────
data["lastActiveWindow"]["folder"]    = folder_uri
data["lastActiveWindow"]["folderUri"] = folder_entry["folderUri"]

# ── Write back ────────────────────────────────────────────────────────────
with open(storage_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")   # POSIX-friendly trailing newline

print("storage.json written successfully.")
PYEOF

success "storage.json updated successfully."

# -----------------------------------------------------------------------------
# 5. VALIDATE the resulting JSON is well-formed
# -----------------------------------------------------------------------------
info "Validating storage.json..."
python3 - "$STORAGE_FILE" <<'VALIDATE'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    required = [
        ("windowsState",),
        ("windowsState", "lastActiveWindow"),
        ("windowsState", "openedWindows"),
        ("lastActiveWindow",),
    ]
    for keys in required:
        obj = data
        for k in keys:
            assert k in obj, f"Missing key: {'.'.join(keys)}"
            obj = obj[k]
    assert len(data["windowsState"]["openedWindows"]) > 0, "openedWindows is empty"
    print("Validation passed — all required keys present and well-formed.")
except Exception as e:
    print(f"VALIDATION FAILED: {e}", file=sys.stderr)
    sys.exit(1)
VALIDATE

success "storage.json validation passed."

# -----------------------------------------------------------------------------
# 6. SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  VS Code Launch Directory Summary${NC}"
echo -e "${BOLD}========================================${NC}"
if [[ "$STORAGE_CREATED" == true ]]; then
echo -e "  storage.json  : ${YELLOW}CREATED (new)${NC} ${BOLD}${STORAGE_FILE}${NC}"
else
echo -e "  storage.json  : ${GREEN}UPDATED (existing)${NC} ${BOLD}${STORAGE_FILE}${NC}"
fi
echo -e "  Directory set : ${GREEN}${TARGET_DIR}${NC}"
echo -e "  Backup        : ${GREEN}${BACKUP_FILE}${NC}"
echo ""
echo -e "${BOLD}========================================${NC}"
echo ""