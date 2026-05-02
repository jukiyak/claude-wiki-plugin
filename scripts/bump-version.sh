#!/usr/bin/env bash
# bump-version.sh
#
# Atomically bumps the plugin version across .claude-plugin/plugin.json and
# .claude-plugin/marketplace.json. Prevents the drift that happens when one
# manifest is updated by hand and the other is forgotten.
#
# Usage: ./scripts/bump-version.sh <new-version>
# Example: ./scripts/bump-version.sh 0.1.0-dev.19
#
# Uses a sed pattern (not jq) on purpose: jq pretty-printer expands inline
# arrays like `keywords` to multi-line, which would churn the diff every
# bump. Each manifest has exactly one `"version": "..."` line, so a single
# substitution is safe.
#
# Does NOT commit or tag — prints the next steps so you can review the diff
# before persisting.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-version>" >&2
  echo "Example: $0 0.1.0-dev.19" >&2
  exit 2
fi

new_version="$1"

# Resolve repo root from this script's location so the command works from
# any cwd.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
plugin_json="$repo_root/.claude-plugin/plugin.json"
marketplace_json="$repo_root/.claude-plugin/marketplace.json"

for f in "$plugin_json" "$marketplace_json"; do
  [[ -f "$f" ]] || { echo "Error: missing $f" >&2; exit 1; }
done

# Each manifest must have exactly one `"version":` line, otherwise the sed
# substitution would silently rewrite the wrong field.
for f in "$plugin_json" "$marketplace_json"; do
  count=$(grep -cE '^[[:space:]]*"version":' "$f" || true)
  if [[ "$count" -ne 1 ]]; then
    echo "Error: $f has $count \"version\" lines (expected 1) — refuse to bump" >&2
    exit 1
  fi
done

old_plugin_version=$(sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' "$plugin_json")
old_marketplace_version=$(sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' "$marketplace_json")

echo "Bumping version: ${old_plugin_version} → ${new_version}"
[[ "$old_plugin_version" != "$old_marketplace_version" ]] && \
  echo "  (marketplace.json was at ${old_marketplace_version} — drift fixed)"

# macOS BSD sed needs `-i ''`; GNU sed accepts `-i` alone. Detect.
if sed --version >/dev/null 2>&1; then
  sed_inplace=(-i)
else
  sed_inplace=(-i '')
fi

sed "${sed_inplace[@]}" -E "s/(\"version\":[[:space:]]*\")[^\"]+\"/\1${new_version}\"/" "$plugin_json"
sed "${sed_inplace[@]}" -E "s/(\"version\":[[:space:]]*\")[^\"]+\"/\1${new_version}\"/" "$marketplace_json"

echo
echo "Updated:"
echo "  $plugin_json"
echo "  $marketplace_json"
echo
echo "Next steps:"
echo "  1. Review:  git diff .claude-plugin/"
echo "  2. Commit:  git commit -am \"v${new_version}: <message>\""
echo "  3. Tag:     git tag v${new_version}  (only for releases)"
