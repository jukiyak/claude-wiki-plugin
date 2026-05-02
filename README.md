# claude-wiki

A Claude Cowork plugin that implements [Andrej Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) on top of Obsidian. Build a personal knowledge base where the LLM does all the bookkeeping — summaries, cross-references, contradictions, and consistency — while you stay in charge of sourcing and direction.

## Status: v0.1.0 — first feature release

v0.1.0 ships the basic-profile MVP — 4 skills + 2 hooks + a bundled canonical schema. See the [v0.1.0 release notes](https://github.com/jukiyak/claude-wiki-plugin/releases/tag/v0.1.0) for the full announcement.

Skills:

1. `setup-claude-wiki` — interview-driven vault scaffold (asks language + domains, writes minimum 4-section structure)
2. `add-page` — ingest interview + Batch Approval Plan (touches page + index + log per Karpathy Principle #5)
3. `lint-vault` — schema / hygiene / structural lint with tier-based Batch Approval (17 rules, file-level + rule-level modes)
4. `query-wiki` — hybrid index-first reading + grep fallback, markdown / table / Mermaid synthesis with `[[Page]]` citations, auto-offer graduation back to wiki

Hooks (auto-registered on plugin install):

- `obsidian-write-guard` — **PreToolUse** guard that blocks Write/Edit/NotebookEdit and destructive Bash operations targeting the vault's `.obsidian/` directory (workspace.json, plugins/, themes/, etc.). Override via `CLAUDE_WIKI_GUARD_DISABLE=1` for rare manual edits.
- `vault-first-reminder` — **SessionStart** hook that injects the Vault-First Consultation rule into Claude's context at session start. Ensures Claude consults the vault first before reaching for general knowledge or web on substantive questions. Override via `CLAUDE_WIKI_VAULT_FIRST_DISABLE=1`.

Bundled schema:

- `CANONICAL.md` at the plugin root — single source of truth referenced by every skill via `${CLAUDE_PLUGIN_ROOT}/CANONICAL.md`. Distributed with the plugin so every user has the same schema, no separate setup required.

`daily-log` (optional journaling skill) and the v0.2.0+ pro profile (Capture/Compile/Deep ingest tiers, verified-page auto-flow, automatic sub-wiki scaffolding, JP↔EN migration) follow in subsequent releases — see the Roadmap below.

## Requirements

- **Claude Desktop** ([download](https://claude.com/download)) on macOS or Windows
- **Cowork mode** — available on Pro / Max / Team / Enterprise plans
- **[kepano/obsidian-skills](https://github.com/kepano/obsidian-skills)** — **hard dependency** for `/add-page` and other v0.1.0 ingest skills. Install via Cowork → Customize → `+` → Claude marketplace url → `https://github.com/kepano/obsidian-skills`. The plugin uses `obsidian-cli` (vault read/write), `obsidian-markdown` (OFM correctness), and `defuddle` (URL ingest).
- **Obsidian app must be running** when invoking `/add-page` so `obsidian-cli` can resolve the active vault. The setup skill (`/setup-claude-wiki`) does not require Obsidian to be running.

## Installation

### Recommended — GitHub marketplace (auto-updates)

1. Open Claude Desktop and switch to the **Cowork** tab
2. Click **Customize** in the left sidebar, then the **`+`** button
3. Choose **Claude marketplace url**
4. Paste:
   ```
   https://github.com/jukiyak/claude-wiki-plugin
   ```
5. Find `claude-wiki` in the listing and press **Install**

Future versions will auto-update once you have the marketplace registered.

### Alternative — `.plugin` upload

> Currently broken in some Cowork builds (see [issue #42651](https://github.com/anthropics/claude-code/issues/42651)). Use the marketplace flow above.

## Quick start

After install:

1. Pick or create an empty folder in Cowork's folder picker — for example `~/Documents/my-vault/`
2. In chat, send any of these triggers:
   - `set up claude-wiki`
   - `セットアップ`
   - `/setup-claude-wiki`

The setup skill conducts an interview — asks your language (日本語 / English), what domains you want to track (e.g. 仕事, 個人, 健康), helps you name top-level folders in your own vocabulary, then writes only the minimum scaffold: one root index per top folder + one wiki-index and wiki-log per domain. No bundled templates, no domain presets — your structure, your vocabulary.

After setup, ingest pages with `/add-page`, ask the vault questions with `/query-wiki`, and run `/lint-vault` periodically for schema/hygiene/structural checks.

## Roadmap

| Version | Status | Scope |
|:---|:---|:---|
| **v0.1.0** | **current release** | Basic profile MVP — interview-driven `setup-claude-wiki`, `add-page`, `lint-vault`, `query-wiki` + 2 hooks (`obsidian-write-guard`, `vault-first-reminder`) + bundled `CANONICAL.md`. Compile-tier ingest only. |
| v0.1.1+ | optional add-ons | `daily-log` skill + Stop reminder hook for users who want a daily-journal workflow. Made optional because journaling is opinionated; not all PKM users do it. `UserPromptSubmit` proactive vault context injection (waiting on upstream Claude Code [Issue #10225](https://github.com/anthropics/claude-code/issues/10225)). |
| v0.2.0 | planned | Pro profile — Capture / Compile / Deep ingest tiers with domain auto-classification, verified-page auto-reset on edits, automatic sub-wiki scaffolding, `update-claude-wiki` schema migration, JP↔EN frontmatter migration |
| v1.0.0 | stability target | Candidate for the Anthropic official marketplace |

The **basic** profile aims at general PKM users (journals, reading notes, study). The **pro** profile adds the discipline needed for medical, legal, or research domains where citation provenance matters.

## Profiles

- **basic** (v0.1.0) — interview-driven setup + Compile-tier ingest. The plugin asks which domains you want to track, helps you name top-level folders in your own vocabulary (e.g. `パーソナル / 仕事 / システム` or `personal / work / system`), and writes only the minimum scaffold. `add-page` adds wiki pages via Batch Approval Plan (CREATE / UPDATE / INDEX / LOG presented once, user approves the batch). All ingests start as `draft`. Templates emerge through first-use interviews. `daily-log` is available as an optional add-on starting v0.1.1+.
- **pro** (v0.2.0+) — adds Capture/Compile/Deep ingest tier semantics with domain auto-classification, `verified`-status auto-reset on edits, automatic sub-wiki scaffolding (v0.1.0 only nudges), and a JP↔EN migration skill.

## Localization

Plugin metadata, skill instructions, and documentation are written in English so the plugin is discoverable globally.

**Vault output is fully localized.** At first run, the setup skill asks you to pick `日本語` or `English`. The choice applies to **everything written into your vault**: filenames, frontmatter keys, frontmatter values, and body text. Pick `日本語` and you get `健康/健康.md` with `タイプ: 索引`, `ステータス: 下書き`, etc.; pick `English` and you get `health/health.md` with `type: wiki-index`, `status: draft`. The downstream skills (`lint-vault`, `query-wiki`) accept both key sets.

A single vault should not mix JP and EN keys. The setup choice is the vault's "language lock"; a migration skill is planned for v0.2.0+.

## Architecture

The plugin sits between three layers, following Karpathy's LLM Wiki pattern:

| Layer | Owner | What lives here |
|:---|:---|:---|
| **Raw sources** | You | Articles, PDFs, transcripts in `raw/` folders. Immutable. |
| **Wiki** | Claude | Summaries, entity pages, cross-references — generated and maintained by skills. |
| **Schema** | Both | Canonical schema bundled with the plugin (`CANONICAL.md`) and referenced by every skill. |

See [Karpathy's gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) for the conceptual foundation.

## Development

Source layout:

```
claude-wiki/
├── .claude-plugin/
│   ├── marketplace.json    # Marketplace catalog (used by GitHub install)
│   └── plugin.json          # Plugin manifest
├── CANONICAL.md             # Canonical schema (single source of truth, referenced by all skills)
├── hooks/
│   └── hooks.json           # PreToolUse + SessionStart hook declarations (auto-registered)
├── scripts/
│   ├── obsidian-write-guard.sh    # PreToolUse hook (block writes to .obsidian/)
│   └── vault-first-reminder.sh    # SessionStart hook (inject vault-first behavior rule)
├── skills/
│   ├── setup-claude-wiki/
│   │   └── SKILL.md         # Interview-driven vault scaffold (shipped)
│   ├── add-page/
│   │   └── SKILL.md         # Ingest interview + Batch Approval Plan (shipped)
│   ├── lint-vault/
│   │   └── SKILL.md         # Schema/hygiene/structural lint (shipped)
│   └── query-wiki/
│       └── SKILL.md         # Hybrid query + citations + graduation (shipped)
└── README.md
```

To build a `.plugin` archive locally:

```bash
cd path/to/claude-wiki
zip -r /tmp/claude-wiki.plugin . -x "*.DS_Store" "*.git*"
```

## Author

[Jukiya Kinjo](https://jukiyakinjo.com)

## License

MIT
