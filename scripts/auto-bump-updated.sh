#!/usr/bin/env bash
# auto-bump-updated.sh
#
# PostToolUse hook (matcher: Write|Edit|NotebookEdit) that auto-updates the
# `更新日:` (JP) / `updated:` (EN) frontmatter field on wiki-page files to
# today's quoted YYYY-MM-DD whenever Claude edits them. Removes the chronic
# "forgot to bump updated" footgun, keeps staleness lint trustworthy.
#
# Behavior:
# - Only fires for files inside an Obsidian vault (detected by walking up to
#   find a `.obsidian/` ancestor) with frontmatter `type: wiki-page` /
#   `タイプ: wikiページ`.
# - Skips wiki-index, wiki-log, root-index, and any file with `_lint_skip: true`.
# - Skips when the date is already today (no-op sentinel — also breaks any
#   theoretical recursive PostToolUse fire).
# - For Edit tool only: applies a heuristic to skip "schema-only" edits where
#   `new_string` looks like pure YAML key:value content (no markdown body
#   markers). Best-effort, documented as such; user can always disable.
# - Override: CLAUDE_WIKI_AUTO_BUMP_DISABLE=1 disables entirely.
#
# Part of claude-wiki plugin: https://github.com/jukiyak/claude-wiki-plugin

set -euo pipefail

# --- Env var bypasses ---
if [[ "${CLAUDE_WIKI_AUTO_BUMP_DISABLE:-0}" == "1" ]]; then
  exit 0
fi
if [[ "${CLAUDE_WIKI_HOOK_RECURSION_GUARD:-0}" == "1" ]]; then
  exit 0
fi
export CLAUDE_WIKI_HOOK_RECURSION_GUARD=1

# --- Defensive: require jq ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not installed; claude-wiki auto-bump-updated hook is disabled (install jq to re-enable)" >&2
  exit 0
fi

# --- Read & parse hook input (1 MB cap) ---
input=$(head -c 1048576)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
case "$tool_name" in
  Write|Edit|NotebookEdit) ;;
  *) exit 0 ;;
esac

raw_path=$(echo "$input" | jq -r '.tool_input.file_path // empty | strings' 2>/dev/null || echo "")
[[ -z "$raw_path" ]] && exit 0

# Canonicalize (resolve symlinks, normalize ../) — defends against path
# traversal and edge cases like iCloud-synced symlink vault roots.
file_path=$(realpath "$raw_path" 2>/dev/null || echo "")
[[ -z "$file_path" ]] && exit 0
[[ "$file_path" == *.md ]] || exit 0
[[ -f "$file_path" ]] || exit 0

# --- Vault detection: walk up to find .obsidian/ ---
vault_root=""
dir=$(dirname "$file_path")
while [[ "$dir" != "/" && "$dir" != "." ]]; do
  if [[ -d "$dir/.obsidian" ]]; then
    vault_root="$dir"
    break
  fi
  dir=$(dirname "$dir")
done
[[ -z "$vault_root" ]] && exit 0

# --- Frontmatter extraction (between first --- and second ---) ---
frontmatter=$(awk '
  /^---$/ { count++; if (count == 1) { in_fm = 1; next } else if (count == 2) { exit } }
  in_fm { print }
' "$file_path")
[[ -z "$frontmatter" ]] && exit 0

# --- Wiki-page filter: only bump wiki-page / wikiページ types ---
if echo "$frontmatter" | grep -qE '^[[:space:]]*"?(type|タイプ)"?:[[:space:]]*("?wiki-page"?|"?wikiページ"?)[[:space:]]*$'; then
  : # is wiki-page, continue
else
  exit 0
fi

# --- _lint_skip: true honor ---
if echo "$frontmatter" | grep -qE '^[[:space:]]*_lint_skip:[[:space:]]*true[[:space:]]*$'; then
  exit 0
fi

# --- Schema-only edit heuristic (Edit tool only) ---
# If the Edit's new_string contains only YAML-shape lines (key: value, array
# continuations, scalar continuations) and no markdown body markers, treat
# it as schema-only and skip the bump. Best-effort; documented limitation.
if [[ "$tool_name" == "Edit" ]]; then
  new_string=$(echo "$input" | jq -r '.tool_input.new_string // empty | strings' 2>/dev/null || echo "")
  if [[ -n "$new_string" ]]; then
    # Body markers: H1/H2 headings, blockquotes, list items, tables, fenced code,
    # horizontal rules other than the frontmatter delimiter, bare prose lines.
    # If the new_string contains NONE of these and only YAML-ish content, skip.
    has_body_marker=$(echo "$new_string" | grep -cE '^(#+ |> |[*+-] |\| |```|~~~)' || true)
    # Also detect prose: a non-empty line that doesn't look like YAML (key:value)
    # and doesn't start with array/scalar continuation whitespace.
    has_prose_line=$(echo "$new_string" | awk '
      /^[[:space:]]*$/ { next }
      /^---$/ { next }
      /^[[:space:]]*[a-zA-Z_"][^:]*:[[:space:]]*/ { next }
      /^[[:space:]]+- / { next }
      /^[[:space:]]+[a-zA-Z0-9"\[]/ { next }
      { count++ }
      END { print (count+0) }
    ')
    if [[ "$has_body_marker" -eq 0 ]] && [[ "$has_prose_line" -eq 0 ]]; then
      exit 0
    fi
  fi
fi

# --- Date sentinel + locale-aware bump ---
today=$(date '+%Y-%m-%d')

# Check if already today (using grep on the live file). Match both quoted
# (single or double) and bare forms, JP and EN keys.
if grep -qE "^[[:space:]]*\"?(更新日|updated)\"?:[[:space:]]*['\"]?${today}['\"]?[[:space:]]*$" "$file_path"; then
  exit 0
fi

# --- Detect sed inplace flavor (BSD vs GNU) ---
if sed --version >/dev/null 2>&1; then
  sed_inplace=(-i)
else
  sed_inplace=(-i '')
fi

# --- Atomic write via temp file + mv ---
tmp_file="${file_path}.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

# Two patterns: JP (`"更新日": ...`) and EN (`updated: ...`). Match the value
# portion (anything up to end of line) and rewrite to today's quoted date.
# Single-quote the date value (canonical form per CANONICAL.md).
sed -E \
  -e "s/^([[:space:]]*\"?更新日\"?:[[:space:]]*)['\"]?[^'\"[:space:]]*['\"]?[[:space:]]*$/\1'${today}'/" \
  -e "s/^([[:space:]]*updated:[[:space:]]*)['\"]?[^'\"[:space:]]*['\"]?[[:space:]]*$/\1'${today}'/" \
  "$file_path" > "$tmp_file"

# Only replace if the temp file actually changed (defensive: if neither key
# matched, both files are identical and we skip the move to avoid mtime churn).
if ! cmp -s "$file_path" "$tmp_file"; then
  mv "$tmp_file" "$file_path"
else
  rm -f "$tmp_file"
fi

trap - EXIT
exit 0
