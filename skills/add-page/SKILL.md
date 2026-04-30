---
name: add-page
description: Use this skill when the user wants to add a new wiki page to a claude-wiki vault — either from scratch (topic-driven) or by ingesting a source (URL, PDF, pasted text). The skill conducts an interview, drafts the page, presents a structured Batch Approval Plan (CREATE / UPDATE / INDEX / LOG), then on user approval writes the page, updates the parent wiki-index, and prepends a log entry — all in one ingest pass per Karpathy's LLM Wiki principle that a single source touches many pages. English triggers include "add a page", "add page about X", "ingest this", "compile this source", "/add-page". Japanese triggers include "ページを追加", "ページ追加", "このソースを取り込んで", "この PDF を読んで wiki にして", "メモを起こして", "/ページ追加". Requires kepano/obsidian-skills (hard dependency) and a running Obsidian app.
---

# Add a wiki page (interview-driven, Batch Approval)

> Walks the user through an ingest interview, drafts a wiki page from scratch or from a source, presents a structured CREATE/UPDATE/INDEX/LOG plan, and on approval writes everything in one pass. Honors Karpathy's principle that **one source should touch many pages** — page + index + log are always updated together.

## Behavior summary

The skill walks through seven steps, in order:

0. **Dependency gate** — verify kepano/obsidian-skills is installed and Obsidian app is running
1. **Trigger parse** — decide whether the user is adding from-scratch (topic) or from-raw (source)
2. **Vault survey** — auto-detect locale, list wiki-indexes, identify candidate parent
3. **Content draft** — read source (if any), infer body style from existing pages, draft page
4. **Batch Approval Plan** — present CREATE/UPDATE/INDEX/LOG proposal in user's locale
5. **Write pass** — on approval, write all files in dependency order
6. **Post-write checks** — sub-wiki threshold nudge, confirmation tree, next-step hints

The skill writes nothing without the user's explicit approval at Step 4.

---

## Step 0 — Dependency gate

claude-wiki requires the [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) plugin and a running Obsidian app. **Verify both before proceeding.**

### 0.1 — kepano/obsidian-skills installed?

Run a lightweight `obsidian help` check (or `which obsidian`):

```bash
obsidian help 2>&1 | head -1
```

If the command is **not found** (kepano not installed), stop and instruct:

> **JP:** claude-wiki/add-page には [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) が必要です。Cowork → Customize → `+` → Claude marketplace url で `https://github.com/kepano/obsidian-skills` を追加し、`obsidian-skills` を install してから再度 `/add-page` を実行してください。
>
> **EN:** claude-wiki/add-page requires [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills). Install via Cowork → Customize → `+` → Claude marketplace url → `https://github.com/kepano/obsidian-skills` → install `obsidian-skills`, then re-run `/add-page`.

Stop. Do not proceed.

### 0.2 — Obsidian app running?

Run a lightweight read against the user's vault:

```bash
obsidian read path="README.md" 2>&1 | head -1
```

If the response is `Vault not found` (Obsidian app is not open), **prompt the user to launch Obsidian — do not silently fall back to Edit/Write**:

> **JP:** Obsidian が起動していないようです。`/add-page` は obsidian-cli で OFM (wikilinks、frontmatter、embeds) の整合性を保ちます。Obsidian を開いてから再度 `/add-page` を実行してください。
>
> **EN:** Obsidian doesn't appear to be running. `/add-page` relies on obsidian-cli for OFM correctness (wikilinks, frontmatter, embeds). Open Obsidian and re-run `/add-page`.

**Last-resort fallback:** Only if the user explicitly says "Obsidian は開けない、Edit で書いて" / "I can't open Obsidian, write directly with Edit", proceed in degraded mode using Read/Write/Edit tools. Warn that auto-link tracking, embed resolution, and Properties panel rendering may be incorrect.

---

## Step 1 — Trigger parse

Determine the ingest mode from the user's wording:

| Mode | Triggered when | Examples |
|:--|:--|:--|
| **from-raw** | The user references a source: a URL, a `raw/...` path, an existing PDF/MD file, pasted long text | "ingest this PDF", "https://example.com/article を取り込んで", "raw/sleep-paper.pdf を要約してページに" |
| **from-scratch** | No source mentioned; topic-driven page creation | "耳鳴りについてページを足して", "add a page about tinnitus", "Concerta の使い方をまとめて" |

If ambiguous, ask **once** via AskUserQuestion: "from-raw (取り込み) ですか、from-scratch (新規ページ作成) ですか？" with both options.

---

## Step 2 — Vault survey (kepano `obsidian-cli`)

Read-only exploration of the vault's current state.

### 2.1 — Locale auto-detect (vault-wide majority vote)

```bash
obsidian properties counts format=tsv
```

Tally JP frontmatter keys (`タイプ`, `タグ`, `カテゴリ`, `ステータス`, `更新日`, `まとめ`, `出典`, `エイリアス`, `関連`, `確認日`, `アーカイブ日`) vs EN keys (`type`, `tags`, `categories`, `status`, `updated`, `summary`, `sources`, `aliases`, `contexts`, `verified_date`, `archived_date`). The locale with more occurrences wins. This is more robust than reading a single README.

If the count is tied or empty (very small vault), fall back to reading vault root `README.md` and inspecting its frontmatter keys.

### 2.2 — Wiki-index inventory (3-pass strategy, avoid colon parse error)

`obsidian search query="type: wiki-index"` errors out (`Operator "type" not recognized`). Use 3 passes:

1. **Broad search:** `obsidian search query="wiki-index"` (no operator) — collects candidates from frontmatter and body alike.
2. **Glob fallback:** enumerate `<vault>/*/*.md` and `<vault>/*/*/*.md` where `basename(file) == basename(parent_dir) + ".md"` (the canonical wiki-index naming convention).
3. **Frontmatter verify:** for each candidate, `obsidian read path="..."` and YAML-parse the frontmatter. Keep only those with `type: wiki-index` (or `タイプ: 索引` for JP).

The deduped union is the authoritative wiki-index list.

### 2.3 — Domain root (root-index) inventory

Same 3-pass approach with the EN/JP value pair `root-index` / `ルート索引`. Folder names are vault-specific — do **not** rely on canonical's hard-coded `inbox/system/work/self/_pending` list. The plugin design intent is frontmatter-based detection (per setup-claude-wiki SKILL.md L296).

### 2.4 — Existing-page style inference (after target domain is fixed)

Once the target domain is decided (Step 3 or end of Step 1 if user named it), read the **2-3 most-recently-modified** wiki pages in that domain via `obsidian read`. Extract the section heading pattern (e.g. `## Summary / ## Sources / ## Notes`) and any consistent callout usage. Use this as the body skeleton for the new page.

If the domain has no existing wiki pages, use a sensible default: frontmatter + H1 + free body.

OFM details (wikilinks `[[]]`, embeds `![[]]`, callouts `> [!note]`, properties syntax) follow kepano `obsidian-markdown` conventions.

---

## Step 3 — Content draft

### 3.A — from-raw mode

#### 3.A.1 — Source intake

| Source type | Action |
|:--|:--|
| **URL** | `defuddle parse <url> --md -o raw/<slug>.md` — saves cleaned markdown to `raw/` by default. The wiki page's `sources` will reference this file. If the user explicitly says "raw に残さなくていい" / "don't save to raw", pass through `defuddle` without `-o` and keep markdown in buffer only (sources will be empty per relaxed policy). |
| **Existing file (PDF, .md)** | First check the path exists — if not, stop and ask the user: 「`raw/<source>` が見つかりません。先にファイルを置くか、別のソース指定をお願いできますか？」 If exists, read with `obsidian read path="raw/<source>"` (Obsidian renders PDFs natively). Read tool fallback only if obsidian read times out or returns empty. |
| **Pasted long text** | Use as-is from the conversation buffer. Ask if the user wants it saved to `raw/<slug>.md` for provenance — default no save unless they explicitly want it. |

**URL slug derivation (with example):**

Take the URL's final path segment, lowercase, convert spaces and underscores to hyphens, strip query strings and fragments. Then call `obsidian unique name="<slug>" path="raw"` — if collision exists, append `-<YYYYMMDD>` for today's date.

```
https://en.wikipedia.org/wiki/Tinnitus       → tinnitus
https://example.com/sleep_science/why-sleep  → why-sleep
https://example.com/article?ref=newsletter   → article
https://blog.foo.com/2026/04/headache-tips/  → headache-tips
```

**Error handling for `defuddle`:**

- 404 / network error / unreachable URL → stop and tell the user: 「URL `<url>` が defuddle で取得できませんでした (404 or network error)。URL を確認するか、本文をそのまま貼り付けてもらえれば pasted text モードで進めます。」
- defuddle returns empty markdown (JS-heavy site) → tell the user the page may be SPA-only and offer to fall back to manual paste
- Don't proceed silently with empty content

#### 3.A.2 — Extract & fact-check

Read the raw source. Extract key claims, identify any internal contradictions, and pull out 2-3 most load-bearing facts. (Compile-tier discipline per canonical L244: "only verified information enters the wiki; flag uncertainties inline".)

#### 3.A.3 — Page draft

Construct the page draft with the locale-appropriate frontmatter (Templates 4.A / 4.B below) and a body that mirrors the inferred style from Step 2.4.

### 3.B — from-scratch mode

1. Confirm the topic and the target domain via AskUserQuestion if not stated. Present 1-3 candidate domains from the vault survey (`type: wiki-index` matches), or "create a new domain" option.
2. Iterate with the user on the content (free-form Q&A) until enough material exists for a draft.
3. Construct the page draft with `sources: []` (empty — relaxed sources policy applies for from-scratch).

### 3.C — New-domain auto-create branch

If the target domain doesn't exist (e.g., user says "add a page about 耳鳴り" but no `耳鳴り/` folder exists):

1. Ask the user where the new domain should sit:
   > "新規ドメイン `耳鳴り/` を作成して、そこにページを追加してよいですか？親フォルダの候補: [[<top-folder-1>]] / [[<top-folder-2>]] / 新しい top folder"
2. On approval, the Step 4 Batch Approval Plan will include 3 CREATE entries:
   - `<top-folder>/<new-domain>/<new-domain>.md` (`type: wiki-index` / `タイプ: 索引`, `categories: ["[[<top-folder>]]"]`)
   - `<top-folder>/<new-domain>/<new-domain>-log.md` (`type: wiki-log` / `タイプ: ログ`, `categories: ["[[<new-domain>]]"]`)
   - `<top-folder>/<new-domain>/<page-title>.md` (`type: wiki-page` / `タイプ: wikiページ`, `categories: ["[[<new-domain>]]"]`)
3. The new domain's log gets two entries: an `init` entry (domain creation) and an `ingest` entry (the new page).
4. The top-folder root-index gets one UPDATE: append a wikilink to the new domain.

### 3.D — Inbox / System target

If the user explicitly targets `Inbox/` or `System/` (or their localized equivalents), treat them like any other domain — full interview, full Batch Approval Plan, full index/log update. The page's `categories` simply points to `[[Inbox]]` or `[[System]]`. Triage / promotion across domains is done manually by the user, not by `add-page`.

---

## Step 4 — Batch Approval Plan

Present the proposed changes as a structured plan in the user's locale. The user approves the **batch** once; do not ask file-by-file.

The plan must surface **all** writes — page, index, log, and **bidirectional backlink updates** (Step 5.4). Include a body preview of the new page so the user can review content + cross-references before approval.

### Template 4.A — LOCALE = ja

```markdown
取り込み計画: <ページタイトル>

CREATE:
  - [[<New-Page>]] — <1 行サマリ: 何をカバーするか>
  (新規ドメインなら以下も追加)
  - [[<新ドメイン>]] (索引)
  - [[<新ドメイン>-log]] (ログ)

UPDATE:
  - (該当なし) または
  - [[<Existing-Page>]] — ## 関連 に [[<New-Page>]] を逆 wikilink (双方向リンク)
  - [[<別の関連ページ>]] — 同上
  (※ 親 wiki-index は categories で繋がるため UPDATE 不要)

INDEX: <domain>.md を更新 (+1 件)
LOG:   <domain>-log.md に ingest entry を先頭追加

(出典)
  - URL: <url> (defuddle で raw/<slug>.md に保存)
  または
  - 既存ファイル: raw/<source>
  または
  - 出典なし (from-scratch、relaxed policy)

(本文プレビュー)
---
<新ページの frontmatter + 本文 を実寸表示>
---

この計画で進めて OK ですか？ 修正したい点があれば教えてください。
```

### Template 4.B — LOCALE = en

```markdown
Ingest plan: <page title>

CREATE:
  - [[<New-Page>]] — <one-line: what it covers>
  (if new domain, also)
  - [[<new-domain>]] (wiki-index)
  - [[<new-domain>-log]] (wiki-log)

UPDATE:
  - (none) or
  - [[<Existing-Page>]] — append [[<New-Page>]] backlink under ## Related (bidirectional sync)
  - [[<other-peer-page>]] — same
  (parent wiki-index is omitted — categories already encodes that link)

INDEX: update <domain>.md (+1 entry)
LOG:   prepend ingest entry to <domain>-log.md

(Provenance)
  - URL: <url> (saved to raw/<slug>.md via defuddle)
  or
  - Existing file: raw/<source>
  or
  - No source (from-scratch, relaxed policy)

(Body preview)
---
<frontmatter + body of the new page, full size>
---

Proceed with this plan? Or let me know what to change.
```

If the user requests changes, revise the plan and present again. Loop until approved or stopped.

---

## Step 5 — Write pass (kepano `obsidian-cli` first-class)

On approval, write files in this order. Each write uses the CLI when possible; degraded fallback uses Edit/Write tools.

### 5.1 — Page write (collision-safe, 64KB-safe)

Critical CLI constraint: `obsidian create content="<long>"` silently fails when content exceeds ~64KB (Electron IPC pipe buffer limit; exit code 0 but file not written). **Use skeleton + chunked append.**

1. **Collision check:**
   ```bash
   obsidian unique name="<Page-Title>" path="<dir>"
   ```
   If a duplicate exists, suggest a suffix (`<Page-Title>-2.md`) and re-confirm with the user.
2. **Skeleton write:**
   ```bash
   obsidian create path="<dir>/<Page-Title>.md" content="<frontmatter + H1 only>" silent
   ```
   The skeleton is < 1KB so it's well under the 64KB threshold.
3. **Body append (chunked):**
   ```bash
   obsidian append file="<Page-Title>" content="<chunk>"
   ```
   Split the body into ≤ 50KB chunks. Most defuddle outputs (5-20KB) fit in one chunk; long PDFs may need multiple.

### 5.2 — Index update (`<domain>/<domain>.md`)

Insert a new bullet under the `## ページ` (JP) / `## Pages` (EN) section of the parent wiki-index.

1. Get the section line number:
   ```bash
   obsidian outline file="<domain>" format=json
   ```
   Parse the JSON for the `## ページ` or `## Pages` heading and note its line.
2. Use Edit tool to insert one line directly after that heading:
   ```
   - [[<Page-Title>]] — <1-line summary>
   ```
   (CLI lacks section-scoped append; Edit is the most reliable path.)

### 5.3 — Log prepend (`<domain>/<domain>-log.md`)

The log is newest-first; new entries go at the **top**, after the frontmatter and `# <domain> log` heading.

```bash
obsidian prepend file="<domain>-log" content="<new entry>"
```

Entry format:

```markdown
## [YYYY-MM-DD] ingest | <ソースタイトル or topic>
- Created: [[<New-Page>]]
- Updated: [[<Existing-Page>]] (if any)
- Source: <url or raw/<source> or "from-scratch">
```

For the new-domain branch, prepend two entries (init then ingest) so the chronology is `init` (domain creation) at top after a fresh `# <domain> log` header.

### 5.4 — Bidirectional linking (backlinks into existing pages)

When the new page's body links to existing wiki pages (via `[[Existing-Page]]` in `## 関連` / `## Related` or inline), append a backlink to each target's `## 関連` / `## Related` section so the relationship is symmetric.

1. **Detect targets:** Parse the new page's body for `[[wikilinks]]` that resolve to existing wiki pages (skip wiki-indexes and the page's own parent — the `categories` link already handles that).
2. **For each target:**
   - `obsidian outline file="<Target>" format=json` → find the `## 関連` / `## Related` section line. If absent, append a new `## 関連` (JP) or `## Related` (EN) section at the end of the file.
   - Edit tool to add `- [[<New-Page>]]` (with optional 1-line annotation) under that section.
   - **Sync the target's frontmatter `関連:` / `contexts:`** to include `[[<New-Page>]]` (bare form) per the mirroring rule in the Frontmatter rules section — append if the field exists, create the field if absent.
   - `obsidian property:set name="更新日"/"updated" value="YYYY-MM-DD" file="<Target>"` to bump.
3. **Pre-declare in Batch Approval Plan:** Each backlink touch is an UPDATE entry in Step 4's plan, so the user approves the bidirectional sync as part of the batch.

**Discipline (don't mirror everything):**

- Only mirror "peer" wikilinks — pages at the same hierarchy level (siblings, related-domain pages). Do **not** mirror references to the parent wiki-index (the `categories` field already encodes that relationship).
- Do not mirror wikilinks that already exist in the target's `## 関連` (idempotent — re-running the same ingest doesn't accumulate duplicates).
- For ambiguous cases (cross-domain wikilinks, glossary references), include in Batch Approval Plan and let user confirm/decline.

### 5.5 — `updated` field bumps

Every file that was modified — page (created), index (updated), log (prepended), **and any existing pages backlinked in 5.4** — gets its frontmatter `updated` / `更新日` bumped to today's date.

```bash
obsidian property:set name="<key>" value="YYYY-MM-DD" file="<file>"
```

`<key>` is `更新日` for JP locale, `updated` for EN. Per canonical's `updated` semantics (only bump on content changes, not schema fixes), backlink additions count as content changes.

### 5.6 — Important: do not write `cssclasses`

kepano's `obsidian-markdown` skill lists `cssclasses` as a default frontmatter property. claude-wiki **does not write `cssclasses`** — it was retired from the canonical schema (it was dead metadata). Drop it from any frontmatter the page draft emits, even if existing pages in the vault still have it.

### 5.7 — Obsidian app launches mid-session

If `obsidian` commands started failing mid-write (e.g., `screen module... before app ready`), pause, ask the user to restart Obsidian, and resume. Do not silently retry.

---

## Step 6 — Post-write checks

### 6.1 — Sub-wiki threshold nudge

Count files in the target domain folder (excluding subfolders like `raw/`):

```bash
obsidian folder path="<domain>" info=files
```

If the count is **4 or more** (typically `<domain>.md` + `<domain>-log.md` + 2+ wiki pages), surface a nudge with **concrete suggestions specific to the page topics in that domain**, not a generic message. The Claude that runs `/add-page` has just touched the new page and existing pages, so it knows what the domain is about — use that context.

**LOCALE = ja example shape (don't paste verbatim — adapt to the actual domain content):**

> 💡 `<domain>` フォルダ直下が 4 ファイル (`<files-listed>`) になりました。sub-wiki 化を検討するタイミングです。具体的には:
> - <topic-based suggestion 1: e.g.「症状別ページが今後増えるなら `<domain>/症状/` のサブドメイン」>
> - <topic-based suggestion 2: e.g.「ガイドライン系は `<domain>/参照/` に分離」>
> - <topic-based suggestion 3: e.g.「個人観察ログを別構造に」>
> 現状はまだ実害なし。`/lint-vault` (今後 ship 予定) で構造提案を受けられる予定です。

**LOCALE = en example shape:**

> 💡 `<domain>/` now has 4 top-level files (`<files-listed>`). Consider sub-wiki expansion. Specifically:
> - <topic-based suggestion 1>
> - <topic-based suggestion 2>
> - <topic-based suggestion 3>
> No urgent action needed. `/lint-vault` (coming soon) will offer structural suggestions.

**Discipline:**
- Generate suggestions from what's actually in the domain, not boilerplate
- Mention `raw/` only if the existing pages cite raw sources but no `raw/` folder exists yet
- Do not act on the nudge — sub-wiki expansion is a deliberate user decision

### 6.2 — Confirmation message

Show an ASCII tree of the files written, with `computer://` links to each:

> **JP:**
> ```
> ✅ 取り込み完了。
>
> <domain>/
> ├── <Page-Title>.md       [computer://path]
> ├── <domain>.md (更新)    [computer://path]
> └── <domain>-log.md (追記) [computer://path]
> ```

> **EN:**
> ```
> ✅ Ingest complete.
>
> <domain>/
> ├── <Page-Title>.md       [computer://path]
> ├── <domain>.md (updated) [computer://path]
> └── <domain>-log.md (prepended) [computer://path]
> ```

### 6.3 — Next-step hint

Mention companion skills, flagged with their ship status:

> **JP:** ページのレビューは Obsidian で。クエリは `/query-wiki` (今後 ship 予定)、品質チェックは `/lint-vault` (今後 ship 予定) で。
>
> **EN:** Review the page in Obsidian. For queries use `/query-wiki` (coming soon); for quality checks use `/lint-vault` (coming soon).

---

## Frontmatter templates

The full text of each frontmatter scaffold is in **`references/templates.md`** — read that file when you need the exact body to write.

Templates available:

- **Template F.A** — wiki-page, LOCALE = ja (`タイプ: wikiページ`)
- **Template F.B** — wiki-page, LOCALE = en (`type: wiki-page`)
- **Template F.C** — new wiki-index, LOCALE = ja (new-domain branch, includes empty `## ページ` body)
- **Template F.D** — new wiki-index, LOCALE = en
- **Template F.E** — new wiki-log, LOCALE = ja (new-domain branch, includes init + first ingest entries)
- **Template F.F** — new wiki-log, LOCALE = en

All wiki-page templates include `関連: []` / `contexts: []` placeholder; populate it per the Frontmatter rules below.

---

## Frontmatter rules (apply to every file written)

- **Date strings always quoted:** `更新日: '2026-04-30'` / `updated: '2026-04-30'`. YAML 1.1 parsers coerce unquoted dates to timestamps.
- **JP keys are quoted:** `"タイプ": wikiページ`. EN keys are unquoted: `type: wiki-page`.
- **Wiki-link arrays:** `カテゴリ: ["[[親ドメイン]]"]` / `categories: ["[[parent-domain]]"]`.
- **Mirror `## 関連` body wikilinks to `関連` / `contexts` frontmatter:** When the page body has a `## 関連` (JP) or `## Related` (EN) section listing peer-page wikilinks (e.g. `- [[耳鳴り]]` or `- [[耳鳴り]] (誘因として直接関与)`), include **all** those wikilinks in the frontmatter `関連:` / `contexts:` array, in **bare form** — drop trailing annotations. The annotations stay in the body section (they explain WHY pages are related and are valuable to human readers); the frontmatter array is the machine-readable signal that activates Claude's auto-read trigger (canonical L85) and the v0.1.1+ auto-read hook. Skip only: (a) the parent wiki-index (already in `categories`), and (b) wikilinks that appear inline in body text outside the `## 関連` / `## Related` section (those are casual mentions, not declared peer relationships).
- **No `cssclasses`** — retired from canonical (dead metadata). Do not emit even when kepano's obsidian-markdown skill suggests it.
- **No trailing whitespace inside frontmatter.**

### Frontmatter mapping (LOCALE = ja vs en)

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
| **Type: wiki page** | **`wikiページ`** | **`wiki-page`** |
| Status: draft | `下書き` | `draft` |
| Status: in review | `レビュー中` | `review` |
| Status: verified | `確認済み` | `verified` |
| Status: archived | `アーカイブ済み` | `archived` |

> **Note:** The wiki-page values (`wikiページ` / `wiki-page`) diverge intentionally from canonical's bare `wiki` (per `~/.claude/rules/claude-wiki.md`) for semantic clarity. Other type values match canonical.

---

## Out of scope (deferred to v0.1.1+)

- Capture / Deep ingest tiers (only Compile-tier in v0.1.0; default `status` is always `draft` / `下書き`)
- Domain auto-classification (e.g., `self/health/` → deep)
- Verified-page auto-reset on edit
- Multi-page ingest in one batch (1 source → 1 page only)
- Sub-wiki **automatic** scaffolding (Step 6.1 only nudges; user runs it manually)
- Verified-status weighting in style inference (currently mtime-only)

These follow in `query-wiki`, `lint-vault`, and the v0.1.1+ Pro profile.
