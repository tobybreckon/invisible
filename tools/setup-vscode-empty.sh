#!/usr/bin/env bash
set -euo pipefail

# setup-vscode-quiet.sh
#
# Configure VS Code / VSCodium-like installs on Linux to:
# - Start with an empty window
# - Avoid Welcome / walkthrough / release note screens
# - Disable built-in AI, Copilot, chat, agents, MCP, AI search
# - Disable GitHub auth prompts where configurable
# - Create a launcher that starts VS Code with AI/GitHub extensions disabled
#
# Recommended: close VS Code before running.

CONFIG_DIRS=(
  "$HOME/.config/Code/User"
  "$HOME/.config/Code - Insiders/User"
  "$HOME/.config/VSCodium/User"
  "$HOME/.config/Code - OSS/User"
)

SETTINGS_JSON='{
  "workbench.startupEditor": "none",
  "window.restoreWindows": "none",
  "window.restoreFullscreen": false,

  "workbench.welcomePage.walkthroughs.openOnInstall": false,
  "workbench.tips.enabled": false,
  "update.showReleaseNotes": false,
  "extensions.ignoreRecommendations": true,
  "extensions.showRecommendationsOnlyOnDemand": true,

  "workbench.enableExperiments": false,
  "telemetry.telemetryLevel": "off",

  "security.workspace.trust.enabled": false,
  "security.workspace.trust.startupPrompt": "never",
  "security.workspace.trust.banner": "never",

  "github.gitAuthentication": false,
  "git.terminalAuthentication": false,
  "git.autofetch": false,
  "git.confirmSync": false,
  "git.openRepositoryInParentFolders": "never",

  "chat.disableAIFeatures": true,
  "chat.commandCenter.enabled": false,
  "chat.agent.enabled": false,
  "chat.mcp.discovery.enabled": false,
  "chat.mcp.autoStart": "never",
  "chat.mcp.access": false,
  "chat.extensionTools.enabled": false,
  "chat.plugins.enabled": false,
  "chat.viewSessions.enabled": false,
  "chat.agentsControl.enabled": false,
  "chat.unifiedAgentsBar.enabled": false,
  "chat.useAgentsMdFile": false,
  "chat.useAgentSkills": false,
  "chat.includeApplyingInstructions": false,
  "chat.includeReferencedInstructions": false,
  "chat.promptFilesRecommendations": [],
  "chat.promptFilesLocations": {},
  "chat.agentFilesLocations": {},
  "chat.agentSkillsLocations": {},
  "chat.instructionsFilesLocations": {},

  "workbench.settings.showAISearchToggle": false,
  "workbench.commandPalette.experimental.askChatLocation": "disabled",
  "search.searchView.semanticSearchBehavior": "manual",

  "github.copilot.enable": {
    "*": false
  },
  "github.copilot.chat.agent.autoFix": false,
  "github.copilot.chat.cli.remote.enabled": false,
  "github.copilot.chat.cli.customAgents.enabled": false,
  "github.copilot.chat.organizationCustomAgents.enabled": false,
  "github.copilot.chat.organizationInstructions.enabled": false,
  "github.copilot.chat.tools.memory.enabled": false,
  "github.copilot.chat.copilotMemory.enabled": false,
  "github.copilot.chat.codeGeneration.useInstructionFiles": false,
  "github.copilot.chat.setupTests.enabled": false,
  "github.copilot.chat.startDebugging.enabled": false,
  "github.copilot.chat.copilotDebugCommand.enabled": false,
  "github.copilot.chat.otel.enabled": false,
  "github.copilot.editor.enableCodeActions": false,
  "github.copilot.renameSuggestions.triggerAutomatically": false,
  "github.copilot.nextEditSuggestions.enabled": false,

  "notebook.experimental.generate": false,
  "git.addAICoAuthor": "off",
  "inlineChat.askInChat": false,
  "editor.inlineSuggest.enabled": false,
  "editor.inlineSuggest.showToolbar": "never"
}'

merge_settings() {
  local dir="$1"
  local file="$dir/settings.json"

  mkdir -p "$dir"

  if [[ ! -f "$file" ]]; then
    printf '{}\n' > "$file"
  fi

  python3 - "$file" "$SETTINGS_JSON" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
new_settings = json.loads(sys.argv[2])

raw = path.read_text() if path.exists() else "{}"

try:
    existing = json.loads(raw or "{}")
except json.JSONDecodeError:
    backup = path.with_suffix(".json.bak")
    backup.write_text(raw)
    print(f"Invalid JSON in {path}; backed up to {backup}")
    existing = {}

existing.update(new_settings)

path.write_text(json.dumps(existing, indent=2, sort_keys=True) + "\n")
print(f"Updated {path}")
PY
}

for dir in "${CONFIG_DIRS[@]}"; do
  merge_settings "$dir"
done

# Create a launcher that also disables common GitHub/Copilot extensions at runtime.
# This helps even if the extensions are installed globally or bundled.
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/code-empty-quiet" <<'EOF'
#!/usr/bin/env bash

# Pick the first VS Code-like command available.
if command -v code >/dev/null 2>&1; then
  CODE_BIN="code"
elif command -v codium >/dev/null 2>&1; then
  CODE_BIN="codium"
elif command -v code-insiders >/dev/null 2>&1; then
  CODE_BIN="code-insiders"
else
  echo "Could not find code, codium, or code-insiders in PATH." >&2
  exit 1
fi

exec "$CODE_BIN" \
  --new-window \
  --disable-extension GitHub.copilot \
  --disable-extension GitHub.copilot-chat \
  --disable-extension GitHub.vscode-pull-request-github \
  --disable-extension GitHub.remotehub \
  --disable-extension GitHub.remotehub-insiders \
  "$@"
EOF

chmod +x "$HOME/.local/bin/code-empty-quiet"

# GUI desktop launcher.
mkdir -p "$HOME/.local/share/applications"

cat > "$HOME/.local/share/applications/code-empty-quiet.desktop" <<EOF
[Desktop Entry]
Name=Visual Studio Code - Empty Quiet
Comment=Open VS Code with empty window, no AI/GitHub startup surfaces
Exec=$HOME/.local/bin/code-empty-quiet
Icon=visual-studio-code
Type=Application
Categories=Development;IDE;
StartupNotify=true
EOF

chmod +x "$HOME/.local/share/applications/code-empty-quiet.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

# Optional: uninstall user-installed Copilot/GitHub PR extensions if present.
# This only affects extensions installed in the user's extension directory.
for bin in code codium code-insiders; do
  if command -v "$bin" >/dev/null 2>&1; then
    "$bin" --uninstall-extension GitHub.copilot >/dev/null 2>&1 || true
    "$bin" --uninstall-extension GitHub.copilot-chat >/dev/null 2>&1 || true
    "$bin" --uninstall-extension GitHub.vscode-pull-request-github >/dev/null 2>&1 || true
    "$bin" --uninstall-extension GitHub.remotehub >/dev/null 2>&1 || true
  fi
done

echo
echo "Done."
echo
echo "Start VS Code with:"
echo "  code-empty-quiet"
echo
echo "Or use the desktop launcher:"
echo "  Visual Studio Code - Empty Quiet"
echo
echo "Note: if ~/.local/bin is not in PATH, add this to your shell profile:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""