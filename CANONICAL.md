# Claude Wiki Rules

This is the canonical schema for vaults managed by the `claude-wiki` Cowork plugin. All four skills (`setup-claude-wiki`, `add-page`, `lint-vault`, `query-wiki`) and the `.obsidian/` write-guard hook reference this document. Skills locate it via `${CLAUDE_PLUGIN_ROOT}/CANONICAL.md` so the path is portable across plugin install locations.

## Contents

- [Vault-First Consultation](#vault-first-consultation) — Claude-side default behavior: consult vault before general knowledge or web
- [Wiki Structure](#wiki-structure) — folder layout per domain, naming conventions
- [Hierarchy Roles](#hierarchy-roles) — `type` enum: root-index / wiki-index / wiki-page / wiki-log
- [Auto-Read Convention](#auto-read-convention) — parent + contexts auto-load on file read; budget 4-7 files
- [Lifecycle](#lifecycle) — start → research → compile → iterate → reorganize
- [Wiki Page Frontmatter](#wiki-page-frontmatter) — required/conditional/optional fields, date quoting, **locale mapping (JP↔EN)**, locale auto-detect procedure, `updated` semantics, verification
- [Sub-Wiki Criteria](#sub-wiki-criteria) — initial scaffolding, 7+ wiki-page reorganization trigger, three reorganization paths
- [Directory Depth Rule](#directory-depth-rule) — sub-domain test, recursive splits valid, no hard depth cap
- [Wiki-Link Convention](#wiki-link-convention) — link contextually, not mechanically
- [Post-Rename Frontmatter Link Repair](#post-rename-frontmatter-link-repair) — fix YAML wikilinks after file rename
- [Attachment & Asset Convention](#attachment--asset-convention) — `Attachments/` vs `raw/` vs external
- [Archive Convention](#archive-convention) — `status: archived` + `archived_date`, physical move at 5+
- [Block ID Convention](#block-id-convention) — `^block-id` on-demand only
- [Ingest Workflow](#ingest-workflow) — Capture / Compile / Deep tiers; Compile-tier batch approval
- [Query Output Graduation](#query-output-graduation) — `query→wiki` log prefix, when to suggest promotion

## Vault-First Consultation

When the user asks a question or makes a request that could plausibly be informed by their curated content, Claude consults the **vault first** — even when the user does not explicitly invoke `/query-wiki`.

### Priority

**Vault** (curated, personal) → **general knowledge** (training) → **web** (real-time or outside-vault topics).

### Why

The vault reflects the user's understanding, decisions, and personal observations — knowledge that often exists nowhere else. Karpathy LLM Wiki principle: queries leverage past ingests' compounding value; consulting the vault is how the wiki pays off. Web content may contradict or muddy the vault's verified state; the vault wins on provenance for the user's own domain.

### When the rule applies

- Substantive questions about topics, concepts, or decisions the user might have curated
- Questions about people, projects, organizations the user works with
- Questions framed as "what should I do about X" or "what do I know about X" — personal context implied

### When the rule does not apply (web-first is fine)

- Real-time facts: weather, today's news, breaking events, current prices
- Procedural questions about Claude or its tooling (Cowork, plugins, command syntax, MCP servers)
- Explicit web-only requests ("what does the internet say about X", "find the latest on X")
- One-off lookups with no expected personal context (unit conversion, generic definitions)

### How to apply

1. **Quick vault scan**: read vault README and the relevant root-indexes / wiki-indexes for the question's topic
2. **If relevant vault content found**: ground the answer in the vault, cite as `[[Page]]` inline; supplement with general knowledge or web only where the vault is silent on a needed point
3. **If vault is silent on the topic**: answer from general knowledge; optionally suggest `/add-page` to ingest the topic if the user would want to track it
4. **Web retrieval**: only when real-time or outside-vault content is required; prefer ingesting found content via `/add-page` (URL → defuddle → wiki page) for future reuse rather than ephemeral retrieval

### Relationship to `/query-wiki`

This is a **Claude-side default behavior**, not a `/query-wiki` skill invocation. Vault consultation happens whether or not the user explicitly calls `/query-wiki`. The `/query-wiki` skill is for **structured queries** with mandatory inline citations and auto-offer graduation; the vault-first rule here is the **informal default mode**, applied to every substantive question.

A SessionStart hook (plugin-bundled, see `hooks/hooks.json`) injects this rule as `additionalContext` at session start so it remains active across all Claude sessions where the plugin is installed. A v0.1.1+ enhancement may add `UserPromptSubmit` proactive vault scanning once Claude Code [Issue #10225](https://github.com/anthropics/claude-code/issues/10225) (plugin-bundled UserPromptSubmit hooks not executing) is resolved.

---

## Wiki Structure

Each wiki lives inside a domain folder (system, work, self, etc.) with a consistent layout:

```
{folder}/
├── {name}.md          ← Index/MOC (summaries + ![[{name}.base]])
├── {name}.base        ← Obsidian Bases dynamic view
├── {name}-log.md      ← Chronological log (ingest/query/lint records)
├── raw/               ← Immutable primary sources
└── Page-Name.md       ← Wiki pages (directly in folder; `wiki/` subfolder is an opt-in orphan bucket — see Sub-Wiki Criteria)
```

**Naming:** `{name}` matches the folder name in lowercase-kebab-case (e.g., `health`, `obsidian`, `coral-id`).

**Folder/Wiki Naming (new wikis):**
- Use the broadest accurate single-word name when possible (`claude` not `claude-code-tools`)
- Match existing vault vocabulary — check sibling folders for style before choosing
- Prefer concrete nouns over abstract categories (`supplements` not `nutrition-resources`)
- Sub-wiki folders should be self-descriptive even outside parent context (`claude-code` not `code`)
- When scope is ambiguous, propose 2-3 candidates and let user choose before creating

## Hierarchy Roles

Role is carried by `type` alone. (`cssclasses` was retired — it was dead metadata; the only snippet targeting wiki classes is disabled.)

| Role | Example | `type` (EN) | `タイプ` (JP) | Claude behavior |
|:-----|:--------|:------------|:--------------|:----------------|
| **Root Index** | `self.md`, `work.md`, `system.md` | `root-index` | `ルート索引` | Dashboard for Obsidian. Never auto-loaded. Stops parent chain. |
| **Wiki index** | `health.md`, `obsidian.md` | `wiki-index` | `索引` | Top of chain. Auto-loaded as parent. |
| **Sub-wiki index** | `supplements.md` | `wiki-index` | `索引` | Has parent (wiki index above). |
| **Wiki page** | `Glycine.md`, `Concerta.md` | `wiki-page` | `wikiページ` | Has parent (nearest index above). |
| **Wiki log** | `health-log.md` | `wiki-log` | `ログ` | Append-only chronological record. |

> **Note:** Plugin v0.1.0-dev.6 onwards uses `wiki-page` (EN) / `wikiページ` (JP) for the wiki page type, diverging from the bare `wiki` value used in some pre-plugin canonical drafts. Other 3 type values (`root-index`, `wiki-index`, `wiki-log`) are unchanged.

## Auto-Read Convention

When Claude reads any wiki file (via `obsidian read`), auto-read related context. Subagents doing bulk operations (lint, migration) may skip auto-read for performance.

1. **Parent index**: from `categories` (preferred) or walk-up (fallback). Read it.
2. **Parent's `contexts`**: read the parent's `contexts` entries too (one level, no further recursion).
3. **Own `contexts`**: read own `contexts` entries.
4. **Max reads**: 1 (self) + 1 (parent) + parent's contexts (~1-3) + own contexts (~1-3) = **~4-7 files**
5. **Skip** files with `status: archived`.

### Parent Detection (two-tier)

**Tier 1 — `categories` property (preferred).** Wiki pages have `categories: ["[[health]]"]`. Use the first `categories` entry as the parent index. Explicit, no algorithm needed.

**Tier 2 — Walk-up fallback.** For files without `categories`: walk up from the file's directory. At each directory, check if `{dirname}.md` exists **in that directory**. If yes, that's the parent. If no, continue up. Stop at domain root boundaries.

When a page lives at `<domain>/wiki/<page>.md` (the `wiki/` orphan bucket — see Sub-Wiki Criteria), the walk-up still resolves correctly: skip `wiki/` (it has no `wiki.md` index), continue up to `<domain>/<domain>.md`.

**Domain root boundaries (hard-coded):** `inbox`, `system`, `work`, `self`, `_pending`. No regex — explicit list.

### Root Index Files

Domain top-level dashboards. Claude never auto-loads these.

| Folder | Root index |
|:-------|:-----------|
| `inbox/` | `inbox.md` |
| `system/` | `system.md` |
| `work/` | `work.md` |
| `self/` | `self.md` |
| `_pending/` | (no root index — triage zone) |

## Lifecycle

1. **Start:** Create `{name}.md` + `{name}-log.md` (2 files only)
2. **Research:** Create `raw/` when sources start accumulating
3. **Compile:** Create wiki pages directly in the folder + `{name}.base`
4. **Iterate:** Repeat steps 2-3. New sources → process → update wiki → log
5. **Reorganize (optional, when threshold met):** Sub-domain split or `wiki/` orphan bucket — see Sub-Wiki Criteria

## Wiki Page Frontmatter

```yaml
---
type: wiki-page                  # EN; JP equivalent: タイプ: wikiページ
tags: []
categories: ["[[parent-wiki-index]]"]
status: draft                    # draft | review | verified
updated: '2026-04-10'            # always quote date-only strings
summary: "One-line summary"
sources: ["[[raw/source-name]]"]
contexts: ["[[Related-Page]]"]   # Claude auto-reads these
aliases: []
---
```

**Required properties:** type, tags, categories, status, updated, summary, sources

**Conditional property:** `verified_date: 'YYYY-MM-DD'` — added only when `status: verified`, omitted otherwise. Keeps the Properties panel lean on mobile/iPad.

**Date format:** Always quote date-only strings (`'2026-04-15'`) to prevent YAML 1.1 coercion to ISO 8601 timestamps. Affects `updated`, `date`, `archived_date`, `verified_date`.

### Locale Mapping (JP ↔ EN)

Each vault locks one locale at setup time (`setup-claude-wiki` Step 3). Every key and every type/status value has a paired translation. This table is the **single source of truth**: skills (`setup-claude-wiki`, `add-page`, `lint-vault`, `query-wiki`) reference it instead of duplicating mappings.

| Concept | LOCALE = ja key | LOCALE = en key |
|:--|:--|:--|
| Role discriminator | `タイプ` | `type` |
| Free-form labels | `タグ` | `tags` |
| Parent wiki-link | `カテゴリ` | `categories` |
| Status | `ステータス` | `status` |
| Last content edit date | `更新日` | `updated` |
| One-line summary | `まとめ` | `summary` |
| Provenance wiki-links | `出典` | `sources` |
| Alternate names | `エイリアス` | `aliases` |
| Auto-read related pages | `関連` | `contexts` |
| Verification date | `確認日` | `verified_date` |
| Archive date | `アーカイブ日` | `archived_date` |

| Concept | LOCALE = ja value | LOCALE = en value |
|:--|:--|:--|
| Type: root index | `ルート索引` | `root-index` |
| Type: wiki index | `索引` | `wiki-index` |
| Type: wiki log | `ログ` | `wiki-log` |
| Type: wiki page | `wikiページ` | `wiki-page` |
| Status: draft | `下書き` | `draft` |
| Status: in review | `レビュー中` | `review` |
| Status: verified | `確認済み` | `verified` |
| Status: archived | `アーカイブ済み` | `archived` |

**Quoting rule:** JP keys must be quoted in YAML (`"タイプ": wikiページ`) for parser compatibility. EN keys are unquoted (`type: wiki-page`).

**Type-value note:** This canonical declares `wiki-page` / `wikiページ` as the wiki-page type discriminator. Pre-plugin canonical drafts used a bare `wiki` value — `wiki-page` is the more semantically explicit form going forward. `lint-vault` rule A2 reports both old `wiki` and any unknown type values as drift.

#### Locale auto-detect (vault-wide majority vote)

This is the canonical procedure every skill uses to determine an existing vault's locale. `setup-claude-wiki` does **not** use it (the user's Step-3 prompt locks the locale for a fresh vault); `add-page`, `query-wiki`, and `lint-vault` re-use this procedure during Step 2 vault survey.

```bash
obsidian properties counts format=tsv
```

Tally JP frontmatter keys (`タイプ`, `タグ`, `カテゴリ`, `ステータス`, `更新日`, `まとめ`, `出典`, `エイリアス`, `関連`, `確認日`, `アーカイブ日`) vs EN keys (`type`, `tags`, `categories`, `status`, `updated`, `summary`, `sources`, `aliases`, `contexts`, `verified_date`, `archived_date`). The locale with more occurrences wins. Tally is more robust than reading a single README — it reflects the vault's actual content, not a metadata file that may have drifted.

Fallback for tied or empty counts (a brand-new vault where setup just ran): read vault root `README.md` and inspect its frontmatter keys. The README is written in the locked locale by `setup-claude-wiki` Step 7 / Template 7.A.

The detected `LOCALE ∈ { ja, en }` is then used by the calling skill for: which key/value side of the [Locale Mapping table](#locale-mapping-jp--en) to write, which body-section heading to look for (`## 関連` vs `## Related`), and which template variant to render (Batch Approval Plan, lint report, query response).

### `updated` Semantics

`updated` tracks **content** changes, not schema/frontmatter fixes. Staleness lint (`if updated > verified_date → flag`) assumes this — schema-only bumps would falsely invalidate verification.

**Bump `updated`** when:
- Body prose changes (new sections, rewrites, new information)
- Summary or aliases change meaningfully
- Sources are added/removed or replaced

**Do NOT bump `updated`** for:
- Adding a missing required frontmatter field (`categories`, `sources: []`)
- Renaming a field value (`type: reference` → `type: wiki-page`)
- Quoting a previously-unquoted date (`2026-04-10` → `'2026-04-10'`) — the date is the same
- File rename or folder move
- Typo or formatting fixes that don't change meaning

Borderline cases — err on the side of not bumping unless it's a real revision. The goal is that `updated` reflects authorship drift, not bookkeeping churn.

### Key Properties

| Property | Format | Auto-read? | Notes |
|:---------|:-------|:-----------|:------|
| `categories` | `["[[wiki-index]]"]` | Yes (parent) | Tier 1 parent detection. Multi-wiki: `["[[system]]", "[[obsidian]]"]` |
| `contexts` | `["[[Related-Page]]"]` | Yes | Claude auto-reads these as background |
| `sources` | `["[[raw/source]]"]` | No | Provenance — every wiki page must cite its raw sources |
| `verified_date` | `'2026-04-16'` (quoted) | No | Added only when `status: verified`, omitted otherwise. Staleness lint: if `updated > verified_date` → flag. Sources cross-checked and caveats live in the log, not here. |

### Verification

`status: verified` means the page has been quality-checked and is currently trusted. It does NOT freeze the page — the wiki layer stays mutable. A verified page can still be revised when new sources arrive or an error surfaces.

**Storage split (minimal):**
- Frontmatter carries only `verified_date` (date). Omit entirely when not verified — keeps the Properties panel lean on mobile/iPad.
- The wiki log carries the **full record** — sources cross-checked and any caveats. Natural-language, appendable, greppable. "Who verified" is user + Claude by default; log notes exceptions.

**Lifecycle:**
- `draft` — Claude wrote it; user hasn't reviewed (default for new pages)
- `review` — user is actively reviewing; open questions remain (optional intermediate state)
- `verified` — user + Claude confirmed; `verified_date` set
- `archived` — superseded or no longer relevant; skipped by auto-read (tracked separately via `status` + `archived_date`)

**Promotion rules:**
- Claude never self-promotes `draft` → `verified`. Requires explicit user confirmation in the chat.
- On non-trivial edits to a verified page, Claude resets `status: verified` → `draft` and removes `verified_date`. Typo-level edits may keep the verified state — flag the edit in the log and let the user decide.
- `updated` is independent of `verified_date`: `updated` bumps on any edit; `verified_date` only moves on explicit (re-)verification.

**Log format for verification events:**
```
## [YYYY-MM-DD] verify | Page-Name
- Sources cross-checked: [[raw/source-1]], [[raw/source-2]]
- Notes: (caveats, scope limits, re-verify cadence hints, or who verified if not the usual user + claude)
```

Use `verify` (not `ingest`) as the log prefix so it's grep-distinguishable from ingest / query / lint entries.

**Staleness check (lint pass):**
1. For any page with `status: verified`, if `updated > verified_date` → flag as stale, suggest re-verification or demotion.
2. For fast-moving topics (medical dosing, pricing, API specs, product availability), `verified_date` older than 6 months → flag even without content edits. Slow-moving topics (principles, historical facts, design patterns) don't need cadenced re-verification.

### Frontmatter Opt-Out

`_lint_skip: true` — file is excluded from `vault-lint --fix`. Use for template files, intentionally non-canonical pages, or files mid-edit. The flag is surgical (per-file) and explicit — preferred over the mtime-based heuristic.

## Sub-Wiki Criteria

### Initial scaffolding (small domains, fewer than 7 wiki pages)

For new or small domains: write `{dirname}.md` (wiki-index format) + `{dirname}-log.md`. Wiki pages and `raw/` are added as content arrives. The index file MUST use wiki-index format (`type: wiki-index`, proper frontmatter) and include inline sections that map to future scaffolding:

- `## Pages` → expands to wiki pages in the folder
- `## Sources` → expands to `raw/` folder
- `## Log` → links to `{dirname}-log.md`

Every index is born wiki-ready, even when only 2 files exist.

### Reorganization consideration (when domains grow)

When a domain folder accumulates **7 or more wiki pages** (counting only `type: wiki-page` files; excluding `{dirname}.md` index and `{dirname}-log.md` log; excluding `raw/` subfolder content), Claude proactively raises the question of reorganization. **This is a heuristic alert, not an exact rule** — clusters emerging at 6 pages, or staying tight at 8 pages, are normal cases for judgment. The actual decision rests on whether the pages cluster into **natural sub-categories that aren't too fine-grained**.

When the alert fires, Claude proposes **three reorganization paths** so the user can choose:

#### Option 1 — Sub-domain split (default when natural clusters exist)

Identify natural sub-clusters among the pages and split them into sub-domains. Each sub-domain gets its own `<sub>/<sub>.md` index + `<sub>/<sub>-log.md`. Pages move into the sub-folder; their `categories:` updates from `[[<domain>]]` to `[[<sub-domain>]]`.

A named sub-domain folder serves the same containment role that a generic `wiki/` subfolder would — but the name carries semantic information. `science/biology/` says "these pages are biology"; `science/wiki/` says nothing. Always prefer naming over anonymizing.

**Containment + scope + granularity check** (all three required for split):

- **Containment**: each candidate sub-domain is a **semantic subset of the parent's scope** — the parent naturally includes this sub-domain (`science ⊇ biology`, `philosophy ⊇ ethics`). If the parent doesn't naturally contain the sub-domain (e.g. `science → marketing`), the hierarchy is wrong and you should re-think the parent.
- **Distinct scope**: each candidate sub-domain has its own coherent vocabulary, **meaningfully more refined than the parent** (`biology` introduces "cell / DNA / evolution" beyond `science` general level; `ethics` introduces "ought / virtue / consequence" beyond `philosophy`). Sibling sub-domains have non-overlapping vocabularies.
- **Granularity**: each candidate sub-domain holds at least 2 pages (preferably 3+) — single-page sub-domains are over-fragmentation.

All three must hold. If only 2 of 3 are met, prefer Option 2 (status-quo flat) and revisit later.

Examples of healthy splits:

- **philosophy** → ethics / epistemology / metaphysics (subject-based split; ethics can later sub-split into normative-ethics / applied-ethics / metaethics etc.)
- **science** → biology / physics / chemistry (disciplinary split; biology can itself later sub-split into marine-biology / botany / cell-biology when it crosses the threshold)
- **business** → executive / hr / marketing / finance (functional split; each holds long-lived content with its own vocabulary and stakeholders)

**Recursive splits are valid**: a sub-domain that itself crosses the 7+ threshold may be split again into sub-sub-domains. Each level must pass the sub-domain test (own wiki-index, vocabulary, log) per the Directory Depth Rule — there is no hard depth cap.

#### Option 2 — `wiki/` subfolder (orphan bucket for pages that don't cluster)

When some pages **don't pass the sub-domain test** (no natural clusters, or clusters too thin to satisfy the granularity check), move them into `<domain>/wiki/`. This keeps the domain root clean — only structural items (`<domain>.md` index, `<domain>-log.md` log, `raw/` sources, named sub-domains) sit at root; orphan / general pages live in `wiki/`.

`wiki/` is the natural counterpart to `raw/`. Both are organizational containers under the domain root, distinguished by content type and ownership:

| Container | Content | Lifecycle | Owner |
|:--|:--|:--|:--|
| `raw/` | Immutable primary sources (PDFs, articles, transcripts) | Append, never modify | User |
| `wiki/` | LLM-maintained wiki pages without their own sub-cluster | Edit as vault grows | Claude |

Pages moved into `wiki/` keep their `categories: ["[[<domain>]]"]` — `wiki/` does **not** rename the parent. The `wiki/` folder is **NOT** a sub-domain: it has no own index, no own log, no own distinct vocabulary. It is a leaves bucket — the parent's general-purpose pages live there.

The "Always prefer naming over anonymizing" rule from Option 1 applies to **clustered content**: when pages share their own vocabulary, give that cluster a name. For genuinely uncategorized pages, anonymous bucketing under `wiki/` is correct — there is no name to give.

#### Resulting layouts

**Orphan bucket only** (no clustering possible at all):

```
<domain>/
├── <domain>.md       (wiki-index)
├── <domain>-log.md   (wiki-log)
├── raw/              (immutable sources, optional)
└── wiki/             (all wiki pages, no sub-domains)
    ├── <Page-1>.md
    ├── <Page-2>.md
    └── ...
```

**Hybrid: named sub-domains + `wiki/` for orphans** (typical mature domain):

```
<domain>/
├── <domain>.md
├── <domain>-log.md
├── raw/
├── <sub-domain>/     (named cluster, has own index/log)
│   ├── <sub-domain>.md
│   ├── <sub-domain>-log.md
│   └── <Clustered-Page-A>.md, <Clustered-Page-B>.md
└── wiki/             (pages that don't fit any named sub-domain)
    └── <Orphan-Page>.md
```

#### Adoption

`wiki/` adoption is **optional and user-driven** — the default for new and small domains is flat (any pages live at domain root, no `wiki/` subfolder).

**Heuristic threshold**: a domain becomes a `wiki/` adoption candidate when **4 or more orphan pages** sit at the domain root (counting `type: wiki-page` files at root that don't belong to any named sub-domain). **This is a heuristic alert, not an exact rule** — orphan count of 3 with confusing root layout is also a valid trigger; orphan count of 5 with no named sub-domains can stay flat if the user prefers.

When the orphan threshold or qualitative signal is met, the user may adopt `wiki/`. Common reasons:

- Named sub-domains already exist at root, and orphan pages mixed alongside them make root structure hard to scan
- The user prefers structural separation as a personal organization style (root = scaffolding only)
- `lint-vault` flags the orphan accumulation as a candidate (≥ 4 orphan pages)

**Don't force `wiki/`** on small domains. Below 4 orphan pages, root flatness is fine and adopting `wiki/` is over-engineering. Adoption is a domain-by-domain choice, not a vault-wide rule.

#### Option 3 — Status-quo flat

Keep the current layout: pages live at domain root, no sub-domains, no `wiki/` bucket. Valid when:

- **Density signal**: cross-page wikilink density is high — pages reference each other heavily, and breaking them apart (Option 1) or bucketing them (Option 2) would visually separate things that conceptually belong together. Splitting would weaken the cluster.
- **Naming uncertainty**: sub-domain naming or grouping isn't yet clear. Holding flat for another iteration of growth often clarifies which sub-domains genuinely emerge.
- **Plateau signal**: page count is plateauing (no recent additions, no expected near-term growth). Reorganizing for an unchanging domain is busywork.
- **Personal preference**: the user's mental model favors flat namespaces. This is a legitimate organizational style — wikis served well in flat form for years before sub-domain conventions evolved.

Status-quo is a **deliberate choice, not absence of a choice**. When the user picks it, the wiki-log records the reason so future `lint-vault` passes don't re-propose the same reorganization without context.

### Reorganization is user-driven

Claude **proposes** the three options with concrete suggestions tailored to the **actual domain content** — naming the candidate sub-domains, listing which pages go where, identifying orphan pages for `wiki/`, or justifying why status-quo is healthier. Examples:

- For a `science/` domain holding pages on cells, atoms, and molecules → propose `biology / physics / chemistry` split with page assignments
- For a `business/` domain with mixed pages → propose `executive / hr / marketing / finance` split, or hybrid (named subs + `wiki/` for orphans), depending on cluster shape
- For a domain with high cross-page wikilink density → recommend status-quo flat with reasoning

The user **chooses**. The skill responsibilities are split:

- `lint-vault` raises the trigger as a finding (rule C1), reports candidate suggestions, applies the user's chosen option on approval
- `add-page` raises the trigger as a post-write nudge after each new page, presents suggestions inline
- `setup-claude-wiki` does **not** raise the trigger (setup writes minimum scaffold only — reorganization is a later concern, not setup-time)

## Directory Depth Rule

**Folders are for sub-domain boundaries, not classification hierarchies.** There is no hard depth cap — depth is bounded by the **sub-domain test** below, not by a number.

### Sub-domain test (every level must pass)

For each folder level, ask: **does this level have its own wiki-index (`{name}.md`) with its own vocabulary, scope, and `{name}-log.md`?**

- **Yes** → it's a real sub-domain. Depth is justified. Adding deeper sub-domains is fine when they pass the same test.
- **No** → you're using the folder as a taxonomy node. Push that hierarchy into frontmatter properties (queried via Obsidian Bases) instead.

### Other rules

- Wiki pages live in either the topic folder root OR a `wiki/` subfolder (see Sub-Wiki Criteria Option 2). Identified by `type: wiki-page` / `wikiページ`.
- `raw/` is justified as a subfolder (holds immutable source files with different lifecycle).
- **Taxonomy ≠ sub-domain.** Coral biological classification (Kingdom→Phylum→Class→…→Species) is taxonomy — don't make a folder per rank. Use frontmatter properties (`family`, `genus`, `species`) and query via Bases. But `science/biology/marine-biology/coral-reef-ecosystems/` is a sub-domain chain — each level has its own coherent scope and content, and is fine.
- Most vaults stabilize at 3-5 levels deep. Specialized domains (research wikis, technical handbooks) may go deeper without violation, as long as each level passes the sub-domain test.

### Example layouts

**Common case (3-4 levels):**

```
self/health/                       ← Level 2 (wiki root)
├── health.md                      ← Index
├── health-log.md                  ← Log
├── raw/                           ← Sources (level 3)
├── concerta.md                    ← Wiki page (level 3)
├── supplements/                   ← Sub-wiki (level 3)
│   ├── supplements.md
│   ├── glycine.md                 ← Wiki page (level 4)
│   └── raw/                       ← Sources (level 4)
```

**Deeper specialized case (5+ levels, valid when each level is a real sub-domain):**

```
work/science/                                ← Level 2 (top sub-domain)
├── science.md
├── biology/                                 ← Level 3 (real sub-domain)
│   ├── biology.md
│   ├── marine-biology/                      ← Level 4 (real sub-domain)
│   │   ├── marine-biology.md
│   │   ├── coral-reef-ecosystems/           ← Level 5 (specialized sub-domain)
│   │   │   ├── coral-reef-ecosystems.md
│   │   │   ├── coral-identification.md      ← Wiki page (level 6)
│   │   │   └── coral-bleaching.md           ← Wiki page (level 6)
│   │   └── kelp-forest-ecosystems/          ← Level 5 sibling
│   └── botany/                              ← Level 4 sibling
```

Each level above has its own `{name}.md` index — the chain passes the sub-domain test all the way down. Compare with a taxonomy chain (Kingdom→Phylum→Class→…) where intermediate levels have no own content — that belongs in frontmatter, not folders.

## Wiki-Link Convention

Link contextually, not mechanically. Link a term when the reader needs context to understand the claim. Avoid overlinking — too many links make important connections invisible. As a guideline, link the first meaningful mention per section, not every occurrence.

**Priority when unsure:**
1. **Interactive sessions** — request confirmation from the user.
2. **Automated generation** (skills, bulk ingest) — skip per-link confirmation; link only wiki-index names and page titles that already exist in the vault.

## Post-Rename Frontmatter Link Repair

YAML frontmatter wiki-links (`categories`, `contexts`, `sources`) are NOT updated by Obsidian on file rename. After renaming any file that appears in frontmatter properties, search vault for the old name in YAML frontmatter and update all references:
`obsidian search query="old-name" | grep -E "categories|contexts|sources"`

## Attachment & Asset Convention

| File type | Location | Managed by |
|:----------|:---------|:-----------|
| Pasted/embedded images | `Attachments/` | Obsidian (auto) |
| Wiki raw sources (PDFs, articles) | `raw/` in wiki folder | Claude (ingest) |
| Business assets (logo, seal) | External (e.g. Google Drive) | Manual |

`raw/` is for wiki sources only — not general attachments.

## Archive Convention

- **Default**: Set `status: archived` + `archived_date: YYYY-MM-DD`. File stays in place.
- **Physical move**: When a folder has 5+ archived files, move them to a flat archive folder (e.g., `archive/` at vault root, created on demand) with `origin` property preserving the source path.
- **Claude**: Skip `status: archived` files during auto-read.

## Block ID Convention

- **On-demand only** — add `^block-id` only when another page needs to reference that block
- Do NOT proactively add IDs during page creation
- Naming patterns: `^finding-N`, `^mechanism`, `^dosage`, `^evidence`
- Never rename after creation (breaks references)

## Ingest Workflow

### Ingest Tiers: Capture / Compile / Deep

| Tier | Gate | Default domain | Time |
|:-----|:-----|:---------------|:-----|
| **Capture** | No approval. Auto-filed. `status: capture` | Clippings, meeting notes, bookmarks | 30 sec |
| **Compile** | Batch approval. Basic fact-check. | Articles, research papers, project docs | 5 min |
| **Deep** | Per-claim verification. Multi-session. | Medical, financial, legal | 30+ min |

Claude auto-classifies by domain (`self/health/` → deep, `_pending/clippings/` → capture, `work/` → compile). User overrides with one word: "just capture this" / "compile this" / "deep dive this."

> **Note for v0.1.0:** the `add-page` skill ships **Compile-tier only** — all new pages default to `status: draft` regardless of domain. Capture-tier (auto-file with `status: capture`) and Deep-tier (per-claim verification) are scoped for v0.1.1+.

### Compile-tier workflow (default)

1. Source placed in `raw/` (or identified in Inbox/Clippings)
2. Claude reads the source and researches/fact-checks the content
3. **Once research and validation are sufficient, Claude proactively suggests creating a wiki page** — do not wait for the user to ask. Sufficient = key claims verified, contradictions resolved, at least 2 sources for load-bearing facts.
4. **Batch approval** — Claude presents a structured ingest plan for the user to review and approve once:
   ```
   Ingest plan for [source title]:

   CREATE:
     - [[New-Page]] — what it covers (one line)

   UPDATE:
     - [[Existing-Page]] — what changes: adding section on X; modifying Y

   INDEX: update {name}.md (+N entries)
   LOG: append ingest entry
   ```
   New pages get a "what it covers" line; updated pages get a "what changes" line; index/log listed without detail (mechanical). User reviews the plan and approves the batch. Individual page quality review happens after writes, in Obsidian, at the user's pace. Pages start as `status: draft` for this reason.
5. **Fact-check gate** — only verified information enters the wiki; flag uncertainties inline
6. Claude creates/updates wiki pages with proper frontmatter
7. Claude updates `{name}.md` index (summary list)
8. Claude appends to `{name}-log.md`:
   ```
   ## [YYYY-MM-DD] ingest | Source Title
   - Created: [[New-Page]]
   - Updated: [[Existing-Page-1]], [[Existing-Page-2]]
   ```

## Query Output Graduation

When a query against the wiki produces a reusable artifact — a comparison, an analysis, or a surfaced connection — Claude proactively suggests filing it back as a wiki page. This is how explorations compound rather than leaking into chat history.

**When to suggest promotion** (any of):
- The output synthesizes 3+ existing pages or sources
- It introduces a framing, comparison, or distinction not present in any existing page
- The same or adjacent question is likely to come up again

**Workflow:** Same gate as ingest — user confirms before any write, Claude adds proper frontmatter, cross-references via `contexts`, and updates the wiki index. Log prefix is `query→wiki` (not `ingest`) so provenance is distinguishable:

```
## [YYYY-MM-DD] query→wiki | Artifact title
- Created: [[New-Page]]
- Based on: [[Source-Page-1]], [[Source-Page-2]]
- Triggered by: (one-line description of the originating query)
```

This is implemented by the `query-wiki` skill via auto-offer graduation (Step 4) and hand-off to `add-page` Batch Approval (Step 4.3). See Karpathy LLM Wiki Principle #6 ("Queries are sources too").
