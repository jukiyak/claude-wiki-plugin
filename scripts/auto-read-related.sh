#!/usr/bin/env bash
# auto-read-related.sh
#
# PostToolUse hook (matcher: Read) that auto-loads a wiki-page's parent index
# (categories[0]) and contexts[] entries into Claude's next turn via
# additionalContext. Implements CANONICAL.md "Auto-Read Convention" so the
# wiki neighborhood is always available without Claude having to remember to
# do it manually.
#
# Behavior:
# - Only fires for files inside an Obsidian vault (`.obsidian/` ancestor)
#   with frontmatter `type: wiki-page` / `タイプ: wikiページ`.
# - Reads parent index (categories[0]/カテゴリ[0]) + contexts[]/関連[].
# - Budget: max 7 files (per CANONICAL.md: 1 self + 1 parent + parent's
#   contexts ~3 + own contexts ~3). Skips status: archived files.
# - Emits each file as frontmatter + first 500 chars of body, total cap
#   ~3000 chars; truncates with `...(truncated)` marker.
# - Override: CLAUDE_WIKI_AUTO_READ_DISABLE=1 disables entirely.
#
# Part of claude-wiki plugin: https://github.com/jukiyak/claude-wiki-plugin

set -euo pipefail

# --- Env var bypass ---
if [[ "${CLAUDE_WIKI_AUTO_READ_DISABLE:-0}" == "1" ]]; then
  exit 0
fi

# --- Defensive: require jq ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not installed; claude-wiki auto-read-related hook is disabled (install jq to re-enable)" >&2
  exit 0
fi

# --- Read & parse hook input (1 MB cap) ---
input=$(head -c 1048576)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
[[ "$tool_name" == "Read" ]] || exit 0

raw_path=$(echo "$input" | jq -r '.tool_input.file_path // empty | strings' 2>/dev/null || echo "")
[[ -z "$raw_path" ]] && exit 0

file_path=$(realpath "$raw_path" 2>/dev/null || echo "")
[[ -z "$file_path" ]] && exit 0
[[ "$file_path" == *.md ]] || exit 0
[[ -f "$file_path" ]] || exit 0

# --- Vault detection ---
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

# --- Helper: extract frontmatter (between first --- and second ---) ---
extract_frontmatter() {
  awk '/^---$/ { c++; if (c == 1) { in_fm = 1; next } else if (c == 2) { exit } } in_fm { print }' "$1"
}

# --- Helper: is this file a wiki-page? ---
is_wiki_page() {
  local fm
  fm=$(extract_frontmatter "$1")
  echo "$fm" | grep -qE '^[[:space:]]*"?(type|タイプ)"?:[[:space:]]*("?wiki-page"?|"?wikiページ"?)[[:space:]]*$'
}

# --- Helper: is this file archived? ---
is_archived() {
  local fm
  fm=$(extract_frontmatter "$1")
  echo "$fm" | grep -qE '^[[:space:]]*"?(status|ステータス)"?:[[:space:]]*("?archived"?|"?アーカイブ済み"?)[[:space:]]*$'
}

# --- Helper: extract bare wikilinks from a YAML array value ---
# Input: a frontmatter line like  関連: ["[[A]]", "[[B]]"]
# Output: one wikilink target per line (e.g., A\nB), with annotations stripped.
extract_wikilinks() {
  local line="$1"
  echo "$line" | grep -oE '\[\[[^]]+\]\]' | sed -E 's/^\[\[([^]|#]+)([|#][^]]*)?\]\].*/\1/' | sed -E 's/[[:space:]]+$//'
}

# --- Helper: resolve a wikilink target name to a file path in the vault ---
resolve_wikilink() {
  local name="$1"
  find "$vault_root" -type f -name "${name}.md" 2>/dev/null | head -1
}

# --- Helper: extract a frontmatter array field's full value (may span lines) ---
# We support inline arrays (`field: ["[[A]]", "[[B]]"]`) — the canonical form
# emitted by claude-wiki skills. Multi-line YAML lists are out of scope.
get_fm_array_field() {
  local fm="$1"
  local key="$2"  # e.g., categories or カテゴリ
  echo "$fm" | grep -E "^[[:space:]]*\"?${key}\"?:[[:space:]]*\[" | head -1 | sed -E "s/^[[:space:]]*\"?${key}\"?:[[:space:]]*//"
}

# --- Filter: only act on wiki-pages, not on archived ones ---
is_wiki_page "$file_path" || exit 0
is_archived "$file_path" && exit 0

# --- Honor _lint_skip (user-managed opt-out) ---
fm_self=$(extract_frontmatter "$file_path")
if echo "$fm_self" | grep -qE '^[[:space:]]*_lint_skip:[[:space:]]*true[[:space:]]*$'; then
  exit 0
fi

# --- Build the related-files list (parent first, then contexts, capped 6) ---
# Self is excluded from injection (Claude already has it via the Read).
# bash 3.2 compat: no associative arrays — use a delimited string for dedup.
related_paths=()
seen_str="|"

add_related() {
  local p="$1"
  if [[ -z "$p" ]]; then return 0; fi
  if [[ "$p" == "$file_path" ]]; then return 0; fi
  # Dedup via substring search on a delimited string.
  case "$seen_str" in
    *"|${p}|"*) return 0 ;;
  esac
  # Skip archived (is_archived returns 0=archived, 1=not). Don't trip set -e.
  if is_archived "$p"; then return 0; fi
  related_paths+=("$p")
  seen_str="${seen_str}${p}|"
  return 0
}

# Parent (categories[0]/カテゴリ[0])
parent_field=$(get_fm_array_field "$fm_self" "categories")
[[ -z "$parent_field" ]] && parent_field=$(get_fm_array_field "$fm_self" "カテゴリ")
parent_name=$(extract_wikilinks "$parent_field" | head -1)
if [[ -n "$parent_name" ]]; then
  parent_path=$(resolve_wikilink "$parent_name")
  add_related "$parent_path"
fi

# Parent's contexts (max 3)
if [[ -n "${parent_path:-}" && -f "${parent_path:-}" ]]; then
  fm_parent=$(extract_frontmatter "$parent_path")
  parent_ctx_field=$(get_fm_array_field "$fm_parent" "contexts")
  [[ -z "$parent_ctx_field" ]] && parent_ctx_field=$(get_fm_array_field "$fm_parent" "関連")
  if [[ -n "$parent_ctx_field" ]]; then
    while IFS= read -r ctx_name; do
      [[ -z "$ctx_name" ]] && continue
      ctx_path=$(resolve_wikilink "$ctx_name")
      add_related "$ctx_path"
      if [[ ${#related_paths[@]} -ge 4 ]]; then break; fi  # parent + 3 parent ctx = 4
    done < <(extract_wikilinks "$parent_ctx_field")
  fi
fi

# Own contexts (fill remaining budget up to 6 total)
own_ctx_field=$(get_fm_array_field "$fm_self" "contexts")
[[ -z "$own_ctx_field" ]] && own_ctx_field=$(get_fm_array_field "$fm_self" "関連")
if [[ -n "$own_ctx_field" ]]; then
  while IFS= read -r ctx_name; do
    [[ -z "$ctx_name" ]] && continue
    ctx_path=$(resolve_wikilink "$ctx_name")
    add_related "$ctx_path"
    if [[ ${#related_paths[@]} -ge 6 ]]; then break; fi
  done < <(extract_wikilinks "$own_ctx_field")
fi

# Nothing to inject? Exit silently.
if [[ ${#related_paths[@]} -eq 0 ]]; then exit 0; fi

# --- Build the additionalContext payload ---
total_budget=3000
context=""
context+="## Auto-loaded related pages (per CANONICAL.md Auto-Read Convention)"$'\n\n'
context+="The following pages are linked from \`${file_path#$vault_root/}\` via \`categories\` (parent) and \`contexts\` (related). Frontmatter and a body excerpt are included so Claude can synthesize without re-reading."$'\n\n'

remaining=$total_budget
truncated_any=0
for p in "${related_paths[@]}"; do
  rel="${p#$vault_root/}"
  fm=$(extract_frontmatter "$p")
  body=$(awk '/^---$/ { c++; if (c == 2) { in_body = 1; next } } in_body { print }' "$p")
  body_excerpt=$(printf '%s' "$body" | head -c 500)
  [[ "$(printf '%s' "$body" | wc -c)" -gt 500 ]] && body_excerpt+=$'\n…(truncated)'

  block=$'### '"${rel}"$'\n```yaml\n'"${fm}"$'\n```\n\n'"${body_excerpt}"$'\n\n'
  block_size=$(printf '%s' "$block" | wc -c)

  if (( block_size > remaining )); then
    truncated_any=1
    break
  fi

  context+="$block"
  remaining=$((remaining - block_size))
done

[[ $truncated_any -eq 1 ]] && context+=$'_(remaining related pages omitted to stay within budget; use Read tool to load them on demand.)_'$'\n'

# --- Emit JSON ---
jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'

exit 0
