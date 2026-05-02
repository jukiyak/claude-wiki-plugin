#!/usr/bin/env bash
# vault-first-reminder.sh
#
# SessionStart hook that injects the claude-wiki Vault-First Consultation rule
# into Claude's context at session start. This ensures Claude consults the user's
# curated vault content first when answering substantive questions, before
# reaching for general knowledge or web retrieval.
#
# Output format: stdout JSON with hookSpecificOutput.additionalContext
# Event: SessionStart
# Bypass: set CLAUDE_WIKI_VAULT_FIRST_DISABLE=1 in the shell environment
#
# Part of claude-wiki plugin: https://github.com/jukiyak/claude-wiki-plugin
# Full rule: ${CLAUDE_PLUGIN_ROOT}/CANONICAL.md → Vault-First Consultation section

set -euo pipefail

# --- Env var bypass ---
if [[ "${CLAUDE_WIKI_VAULT_FIRST_DISABLE:-0}" == "1" ]]; then
  exit 0
fi

# --- Defensive: require jq ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not installed; claude-wiki vault-first-reminder hook is disabled (install jq to re-enable)" >&2
  exit 0
fi

# --- Discard stdin (SessionStart input not needed for this hook) ---
cat >/dev/null

# --- Build context message (concise summary of the canonical rule) ---
# Use unquoted heredoc so ${CLAUDE_PLUGIN_ROOT} expands to the real path at hook
# execution time. Otherwise Claude sees the literal string `${CLAUDE_PLUGIN_ROOT}`
# in additionalContext and cannot resolve it.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-<plugin-root-not-set; check Cowork plugin install path>}"
read -r -d '' VAULT_FIRST_REMINDER <<EOF || true
[claude-wiki Vault-First Consultation rule]

When the user asks a question that could plausibly be informed by their curated content, consult the vault FIRST before reaching for general knowledge or web retrieval — even when the user does not explicitly invoke /query-wiki.

Priority order: VAULT (curated, personal) → general knowledge (training) → web (real-time or outside-vault topics).

When the rule applies:
- Substantive questions about topics, concepts, or decisions the user might have curated
- Questions about people, projects, or organizations the user works with
- Questions framed as "what should I do about X" or "what do I know about X" — personal context implied

When the rule does NOT apply (web-first is fine):
- Real-time facts: weather, today's news, breaking events, current prices
- Procedural questions about Claude or its tooling (Cowork, plugins, command syntax, MCP servers)
- Explicit web-only requests
- One-off lookups with no expected personal context (unit conversion, generic definitions)

How to apply:
1. Read the vault README and relevant root-indexes / wiki-indexes for the question's topic
2. If relevant vault content is found, ground the answer in the vault, cite as [[Page]] inline; supplement with general knowledge or web only where the vault is silent on a needed point
3. If the vault is silent on a substantive topic, answer from general knowledge and optionally suggest /add-page to ingest the topic
4. Web retrieval: only when real-time or outside-vault content is required; prefer ingesting found content via /add-page (URL → defuddle → wiki page) rather than ephemeral retrieval

This is Claude-side default behavior, not a /query-wiki skill invocation. The /query-wiki skill is for structured queries with mandatory inline citations and auto-offer graduation; this rule is the informal default mode.

Full rule and rationale: ${PLUGIN_ROOT}/CANONICAL.md → "Vault-First Consultation" section.

To bypass for this shell session: export CLAUDE_WIKI_VAULT_FIRST_DISABLE=1
EOF

# --- Emit context injection JSON ---
jq -n --arg ctx "$VAULT_FIRST_REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'

exit 0
