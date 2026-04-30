#!/usr/bin/env bash
# obsidian-write-guard.sh
#
# Pre-tool-use guard that blocks Write/Edit/NotebookEdit and destructive Bash
# operations targeting the Obsidian vault's .obsidian/ directory. The directory
# contains user-managed app settings (workspace.json, plugins/, themes/, etc.)
# that must not be modified by claude-wiki skills.
#
# Override: set CLAUDE_WIKI_GUARD_DISABLE=1 in the shell environment to bypass
# (rare; intended for manual theme migration or batch settings edits).
#
# Part of claude-wiki plugin: https://github.com/jukiyak/claude-wiki-plugin

set -euo pipefail

# --- Env var bypass ---
if [[ "${CLAUDE_WIKI_GUARD_DISABLE:-0}" == "1" ]]; then
  exit 0
fi

# --- Defensive: require jq ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not installed; claude-wiki obsidian-write-guard hook is disabled (install jq to re-enable)" >&2
  exit 0
fi

# --- Read hook input from stdin ---
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# --- Detect blocked operations ---
block_reason=""

# Helper: is a path inside .obsidian/ ?
path_in_obsidian() {
  local p="$1"
  [[ "$p" == *"/.obsidian/"* ]] || \
  [[ "$p" == *"/.obsidian" ]] || \
  [[ "$p" == ".obsidian/"* ]] || \
  [[ "$p" == ".obsidian" ]]
}

case "$tool_name" in
  Write|Edit)
    target=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    if [[ -n "$target" ]] && path_in_obsidian "$target"; then
      block_reason="Direct write/edit to .obsidian/ blocked. Path: ${target}"
    fi
    ;;
  NotebookEdit)
    target=$(echo "$input" | jq -r '.tool_input.notebook_path // empty')
    if [[ -n "$target" ]] && path_in_obsidian "$target"; then
      block_reason="NotebookEdit on .obsidian/ blocked. Path: ${target}"
    fi
    ;;
  Bash)
    cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
    # Block writes/destroys targeting .obsidian/.
    # Patterns: redirect (> path), tee path, rm path, mv path (as src or dst), cp -f path
    if [[ -n "$cmd" ]] && echo "$cmd" | grep -qE '(>[^|<>]*\.obsidian/|tee\s+[^|<>]*\.obsidian/|rm\s+(-[a-zA-Z]+\s+)*[^|<>]*\.obsidian/|mv\s+[^|<>]*\.obsidian/|cp\s+(-[a-zA-Z]+\s+)*[^|<>]*\.obsidian/)'; then
      # Truncate command in message to keep payload small
      truncated=$(printf '%s' "$cmd" | head -c 200)
      block_reason="Bash command writes/destroys .obsidian/. Command (first 200 chars): ${truncated}"
    fi
    ;;
esac

# --- Emit deny decision if matched ---
if [[ -n "$block_reason" ]]; then
  jq -n --arg reason "$block_reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: (
        $reason +
        "\n\nThe .obsidian/ directory contains user-managed Obsidian app settings " +
        "(workspace.json, plugins/, themes/, hotkeys.json, etc.) and is not part of " +
        "the claude-wiki schema. claude-wiki skills must not modify it.\n\n" +
        "If you need to override for a manual operation (rare), set " +
        "CLAUDE_WIKI_GUARD_DISABLE=1 in your shell environment, then re-run. " +
        "For permanent disable, uninstall the claude-wiki plugin."
      )
    }
  }'
fi

exit 0
