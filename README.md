# claude-wiki

A Claude Cowork plugin that implements [Andrej Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) on top of Obsidian. Build a personal knowledge base where the LLM does all the bookkeeping — summaries, cross-references, contradictions, and consistency — while you stay in charge of sourcing and direction.

## Status: v0.0.1 (pipeline validation stub) — v0.1.0 in development

The current released version is **v0.0.1**, a **distribution-pipeline validation stub** that verifies:

- The `.plugin` build → `.claude-plugin/marketplace.json` → GitHub marketplace install flow works end-to-end
- Cowork on macOS (and later Windows) accepts the plugin
- Auto-update via the GitHub marketplace is reliable

**v0.1.0 is in development** on `main` (no separate dev branch). All four v0.1.0 skills have shipped (currently `0.1.0-dev.N` pre-release tags):

1. `setup-claude-wiki` — interview-driven vault scaffold (asks language + domains, writes minimum 4-section structure)
2. `add-page` — ingest interview + Batch Approval Plan (touches page + index + log per Karpathy Principle #5)
3. `lint-vault` — schema / hygiene / structural lint with tier-based Batch Approval (17 rules, file-level + rule-level modes)
4. `query-wiki` — hybrid index-first reading + grep fallback, markdown / table / Mermaid synthesis with `[[Page]]` citations, auto-offer graduation back to wiki

The `.obsidian/` write-guard hook + 統合 dogfood follow before v0.1.0 stable release. `daily-log` and its Stop reminder hook were originally scoped for v0.1.0 but moved to v0.1.1+ as an optional add-on (journaling is opinionated; many users don't want it imposed).

Real features (wiki page management, query-with-citations, automated lint, Capture/Compile/Deep ingest tiers, verified-page gates) ship at **v0.1.0** and beyond.

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

**On v0.0.1 (the current release):** the skill writes a single `Hello-claude-wiki.md` file confirming the pipeline works.

**On v0.1.0-dev (in development):** the skill conducts an interview — asks your language (日本語 / English), what domains you want to track (e.g. 仕事, 個人, 健康), helps you name top-level folders in your own vocabulary, then writes only the minimum scaffold: one root index per top folder + one wiki-index and wiki-log per domain. No bundled templates, no domain presets — your structure, your vocabulary.

## What v0.0.1 verifies

- [x] Plugin is recognized by Cowork
- [x] Skill triggers fire on natural-language phrases (English and Japanese)
- [x] The skill can write to the user-selected folder
- [x] Markdown frontmatter renders cleanly

## Roadmap

| Version | Scope |
|:---|:---|
| **v0.0.1** (current release) | Distribution-pipeline stub |
| v0.1.0 (in development on `main`) | Basic profile MVP — interview-driven `setup-claude-wiki` (no bundled templates or domain presets — the user's domains and vocabulary drive the scaffold), `add-page`, `query-wiki`, `lint-vault`, plus the `.obsidian/` write-guard hook. Per-skill templates emerge through first-use interviews. |
| v0.1.1+ (optional add-ons) | `daily-log` skill + Stop reminder hook for users who want a daily-journal workflow. Made optional because journaling is opinionated; not all PKM users do it. |
| v0.2.0 | Pro profile — Capture / Compile / Deep ingest tiers, verified-page gate, sub-wiki scaffolding, `update-claude-wiki` schema migration, JP↔EN frontmatter migration |
| v1.0.0 | Stability target — candidate for the Anthropic official marketplace |

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
| **Schema** | Both | Conventions defined in `~/.claude/rules/claude-wiki.md` (canonical) and the plugin's skill definitions. |

See [Karpathy's gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) for the conceptual foundation.

## Development

Source layout:

```
claude-wiki/
├── .claude-plugin/
│   ├── marketplace.json    # Marketplace catalog (used by GitHub install)
│   └── plugin.json          # Plugin manifest
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
