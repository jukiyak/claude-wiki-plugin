---
name: lint-vault
description: Use this skill when the user wants to health-check or audit a claude-wiki vault — find schema violations (missing required frontmatter, retired keys, type/status enum drift), vault hygiene issues (orphan pages, dead wikilinks, dead-end pages, frontmatter property anomalies), and structural concerns (sub-wiki threshold reached, file-naming mismatches, empty domain folders). The skill runs 17 rules across schema/hygiene/structural categories, presents a Batch Approval Plan with FIX entries grouped by rule, and on user approval applies the auto-fixable corrections (frontmatter populate, retired-key drop, date quoting, missing-field defaults). Manual-review items are listed but not modified. English triggers include "lint vault", "audit vault", "health check vault", "check vault", "/lint-vault". Japanese triggers include "vault を lint", "vault チェック", "vault 監査", "リント", "ヘルスチェック", "/lint-vault". Requires kepano/obsidian-skills (hard dependency) and a running Obsidian app.
---

# Lint a claude-wiki vault (Batch Approval, schema + hygiene + structural)

> Walks 17 lint rules across the vault, groups violations by rule, presents a Batch Approval Plan, and on approval applies auto-fixable corrections. Manual-review items (vault-hygiene gaps that need user judgment) are surfaced but not modified.

## Behavior summary

The skill walks through six steps:

0. **Dependency gate** — verify kepano/obsidian-skills installed and Obsidian app running
1. **Scope determination** — whole vault (default) or path-targeted (`/lint-vault <path>`)
2. **Rule execution** — run schema (A1-A10), kepano hygiene (B1-B4), structural (C1-C3)
3. **Aggregate findings** — group by rule, then by file
4. **Batch Approval Plan** — FIX entries (auto-fixable) + REVIEW entries (manual)
5. **Apply fixes** — on approval, write all auto-fixes in dependency order
6. **Confirmation report** — summarize fixed / skipped / manual-review counts

Auto-fixes touch only frontmatter and isolated keys; the skill **never rewrites body content** without explicit user direction.

---

## Step 0 — Dependency gate

Identical to `add-page` Step 0. Two checks:

### 0.1 — kepano/obsidian-skills installed?

```bash
obsidian help 2>&1 | head -1
```

If not installed:

> **JP:** claude-wiki/lint-vault には [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) が必要です。Cowork で install してから再実行してください。
>
> **EN:** claude-wiki/lint-vault requires [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills). Install via Cowork and retry.

Stop.

### 0.2 — Obsidian app running?

```bash
obsidian read path="README.md" 2>&1 | head -1
```

If `Vault not found`:

> **JP:** Obsidian が起動していないようです。lint-vault は obsidian-cli で vault 全体をスキャンします。Obsidian を開いてから再度実行してください。
>
> **EN:** Obsidian doesn't appear to be running. lint-vault relies on obsidian-cli to scan the vault. Open Obsidian and re-run.

Last-resort fallback (only if user explicitly asks): degraded mode using Glob/Grep/Read. Warn that hygiene rules (B1-B4) require obsidian-cli and will be skipped in degraded mode.

---

## Step 1 — Scope determination

Default: scan the whole vault.

If the user provides a path argument or names a subset:
- `/lint-vault プライベート/健康/` — scan one folder
- `/lint-vault 健康` — scan one domain (resolved by `obsidian search`)
- `/lint-vault @[[耳鳴り]]` — scan one file

For path-targeted scans, hygiene rules B1-B4 still run vault-wide (orphans/dead-wikilinks are inherently vault-scoped) but only file-scoped findings under the target are reported.

For v0.1.0, default scope is whole vault — keep the UX simple. Path filters are nice-to-have.

---

## Step 2 — Rule execution

### Tier classification (assigned per finding, drives Step 4 UX)

Each finding is tagged with one of three tiers based on the safety of its auto-fix:

| Tier | Rules | Why |
|:--|:--|:--|
| 🟢 **Trivial** | A4 (date quote), A5 (JP key quote), A7 (retired key drop), **A9-safe** (remove orphan `verified_date` when `status` ≠ `verified`) | Mechanical text-level fixes with no semantic risk. Bulk-applied with one approval. |
| 🟡 **Standard** | A1 (required-field default population), A8 (`関連`/`contexts` mirror from body) | Adds meaningful frontmatter content but deterministic from existing data. Approved per-rule, optionally per-domain. |
| 🔴 **Review** | A2 (type enum drift), A3 (status enum drift), A6 (locale mix), **A9-add** (add `verified_date` when `status: verified` but date missing), A10 (`categories` unresolved), B1-B4 (kepano hygiene), C1-C3 (structural) | Requires user judgment. Reported only by default; user may opt-in to per-finding apply walkthrough (Step 4 Review opt-in). |

A9 splits across tiers because removing an orphan `verified_date` is mechanical (Trivial) but adding one to a verified page is a meaningful claim (Review).

### Scope exclusions (apply globally to A1-A10 and C2)

Before running schema rules, **exclude files under any `raw/` subfolder** anywhere in the vault. Raw sources are user-managed primary documents (PDF text extracts, defuddle outputs, web clippings) with their own provenance metadata (`source_url`, `fetched_at`, `revision_id`, `license` etc.) and intentionally do not follow claude-wiki's schema (タイプ/タグ/カテゴリ/...). Treat `raw/**/*.md` as out-of-scope for schema validation.

**Still scan raw/ for:**
- B1-B4 hygiene rules (kepano CLI inherently considers all files; orphan/dead-link checks remain meaningful for raw/)
- C1 4-file threshold (raw/ subfolder *count* matters when deciding sub-wiki promotion, but raw/ contents don't)
- C3 empty domain folder (a `raw/` containing only attachments isn't an "empty domain")

**Path detection:** any file whose path contains a `/raw/` segment (case-sensitive — convention is lowercase).

Run rules in three groups. Collect findings into a structured list:

```python
finding = {
  "rule_id": "A8",
  "rule_name": "関連 mirroring",
  "file": "プライベート/健康/耳鳴り.md",
  "severity": "auto",  # "auto" or "review"
  "description": "body `## 関連` lists 4 wikilinks not mirrored to frontmatter `関連:`",
  "fix_action": "populate frontmatter `関連: [[[頭痛]], [[睡眠不足]], [[カフェイン]], [[アルコール]]]`",
}
```

### A. Schema rules (10) — claude-wiki specific

For each `.md` file in scope, parse frontmatter (YAML) and run:

#### A1 — Required frontmatter fields present

Required keys (per locale):
- JP: `タイプ`, `タグ`, `カテゴリ`, `ステータス`, `更新日`, `まとめ`, `出典`
- EN: `type`, `tags`, `categories`, `status`, `updated`, `summary`, `sources`

If any required key is absent, **auto-fix**: add the missing key with sensible default:
- `タグ`/`tags` → `[]`
- `カテゴリ`/`categories` → resolve via **folder-walk-up algorithm**:
  1. Start at the file's parent directory
  2. Walk up the directory tree level by level
  3. At each level, check whether `<dirname>/<dirname>.md` exists in that directory AND has `type: wiki-index` or `root-index` (or JP equivalents `索引` / `ルート索引`)
  4. If found: set `categories: ["[[<dirname>]]"]` (the first match)
  5. If reach vault root with no match: leave `categories: []`
  6. Stop the walk at hardcoded domain root boundaries when present (`inbox`, `system`, `work`, `self`, `_pending` per canonical, plus user-configured root-indexes detected via Step 2.3 inventory)
- `ステータス`/`status` → `下書き`/`draft`
- `更新日`/`updated` → today's date (quoted)
- `まとめ`/`summary` → empty string `""`
- `出典`/`sources` → `[]`

`タイプ`/`type` is harder to default — if missing, mark as **review** (user decides which type).

#### A2 — Type enum value valid

Valid values:
- JP: `ルート索引`, `索引`, `ログ`, `wikiページ`
- EN: `root-index`, `wiki-index`, `wiki-log`, `wiki-page`

If invalid (e.g. legacy `reference`, `wiki` (canonical bare value, plugin uses `wiki-page`), or arbitrary), mark as **review** with a suggested correction inferred from filename + folder context:

- File ends with `-log.md` → suggest `wiki-log` / `ログ`
- File basename equals parent dir name (`health/health.md`) → suggest `wiki-index` / `索引`
- File at vault top-level domain root (under `inbox/`, `system/`, etc., basename matches dir) → suggest `root-index` / `ルート索引`
- Otherwise → suggest `wiki-page` / `wikiページ`

If the suggestion confidence is low (e.g. the file doesn't match any pattern), surface as Review with no suggestion — let the user decide.

#### A3 — Status enum value valid

Valid values:
- JP: `下書き`, `レビュー中`, `確認済み`, `アーカイブ済み`
- EN: `draft`, `review`, `verified`, `archived`

Invalid → **review** with suggested correction.

#### A4 — Date strings quoted

Detect frontmatter keys ending in `日` (JP: `更新日`, `確認日`, `アーカイブ日`) or matching EN keys (`updated`, `verified_date`, `archived_date`) where the value is an unquoted date string (e.g. `更新日: 2026-04-30`).

**Auto-fix**: wrap value in single quotes (`'2026-04-30'`).

#### A5 — JP keys quoted

Per plugin convention, JP frontmatter keys must be quoted: `"タイプ": ...`. If a JP key appears unquoted, **auto-fix** by adding double quotes around the key.

Skip this rule for vaults in EN locale (detected via majority vote, see add-page Step 2.1).

#### A6 — Locale consistency

Within one file, all frontmatter keys should be JP or all EN — never mixed (e.g. `タイプ: ...\ntags: ...`). Mixed → **review**, with a **suggested target locale** based on the **vault-wide majority vote** from Step 2.1 (the locale used by most files wins). User decides whether to accept the suggestion or pick the other locale; v0.2.0+ will ship an automated migration skill that applies this choice atomically.

#### A7 — Retired keys dropped

Detect frontmatter keys that have been retired in canonical:
- `cssclasses` (retired 2026-04-16, was dead metadata)
- `role` (replaced by `type`)
- `related` (EN, replaced by `contexts`; note: JP `関連` is the *current* mapping for `contexts`, do not drop)

**Auto-fix**: drop the field.

#### A8 — `関連` / `contexts` ↔ body `## 関連` sync (dev.9 deferred fix)

For each page, parse the body for a `## 関連` (JP) or `## Related` (EN) section and extract the wikilinks (e.g. `- [[耳鳴り]]`, `- [[頭痛]] (annotation)`).

Compare with the frontmatter `関連:` (JP) / `contexts:` (EN) array.

**Auto-fix conditions:**
- If body has wikilinks but frontmatter is empty/missing → populate frontmatter (drop annotations, bare wikilinks only, skip parent wiki-index).
- If frontmatter has wikilinks but body section is missing → **review** (user may have intentionally deleted the body section; don't auto-add).
- If both present but differ → populate frontmatter to match body (body is canonical for this rule, since add-page writes body first).

This rule closes the dev.6→9 add-page limitation in a procedural pass.

#### A9 — `verified_date` consistency

Two checks:
- If `status: verified` (JP: `確認済み`) but no `verified_date` (JP: `確認日`) → **auto-fix** by adding `verified_date: '<today>'` (or **review** if user prefers manual back-dating).
- If `verified_date` present but `status` is not `verified` → **auto-fix** by removing `verified_date`.

For v0.1.0, prefer **review** for the first case (adding a verified_date is a meaningful claim). Auto-fix the second (removing unjustified verified_date is safe cleanup).

#### A10 — `categories` link resolves

Each `[[X]]` wikilink in `categories` should resolve to an existing wiki-index file (`<X>/<X>.md` with `type: wiki-index` or `root-index`). If unresolved or points to a non-index file → **review**.

**Suggested correction strategy:**
1. Run `obsidian search query="X"` to find any file with that title (not just wiki-indexes)
2. If a wiki-index exists with similar name (typo distance ≤ 2 chars), suggest the close match
3. If the file's folder-walk-up (per A1 algorithm) yields a different valid parent, suggest that
4. Otherwise: surface as Review with no suggestion ("manual decision needed")

### B. Kepano hygiene rules (4) — delegated to obsidian-cli

These are vault-wide queries; cache results once per `/lint-vault` invocation.

#### B1 — Orphan pages

```bash
obsidian orphans
```

Lists pages with no inbound wikilinks. **Review** — user decides whether to add inbound links from related pages, archive, or accept as a stub.

#### B2 — Dead wikilinks

```bash
obsidian unresolved
```

Lists wikilinks pointing to non-existent files. **Review** — typo, deleted page, or planned page? User decides.

#### B3 — Dead-end pages

```bash
obsidian deadends
```

Lists pages with no outgoing wikilinks. **Review** — pages with no out-links may be isolated nodes; user decides whether to add cross-references.

#### B4 — Frontmatter property anomaly

```bash
obsidian properties counts format=tsv
```

Parse the TSV output for property usage counts. Flag properties that:
- Appear in only 1-2 files vault-wide (likely typos: `tagss`, `aliassses`)
- Have inconsistent value types (string vs array)

**Review** — user decides whether to rename/normalize.

### C. Structural rules (3)

#### C1 — Sub-wiki 4-file threshold

For each domain folder containing a `<domain>.md` wiki-index, count top-level `.md` files (exclude `raw/` subfolder).

```bash
obsidian folder path="<domain>" info=files
```

If count ≥ 4, **review** with sub-wiki promotion suggestion (concrete topic-based grouping suggestions per add-page Step 6.1 nudge style).

#### C2 — File naming convention

For each folder, the index file should be named `<dirname>/<dirname>.md` and the log should be `<dirname>-log.md`.

Detect mismatches (e.g. a wiki-index named `index.md` instead of `<dirname>.md`). **Review** — propose rename, but renames break wikilinks so user must approve.

#### C3 — Empty domain folders

Walk vault folder tree; flag folders containing no `.md` files (empty placeholders). **Review** — user decides whether to delete or populate.

---

## Step 3 — Aggregate findings

Group all findings:

1. **Primary**: by tier (🟢 Trivial → 🟡 Standard → 🔴 Review)
2. **Secondary**: by rule_id (A1, A2, ..., C3) within each tier
3. **Tertiary** (Standard tier only): by **top-level folder** (Inbox, システム, パーソナル, 仕事, …) — derived from the first path segment of each finding's file
4. **Per-finding**: file path, description, fix_action

Compute counts:
- Total files scanned
- Total findings
- Per-tier counts (Trivial / Standard / Review)
- Per-rule counts within each tier
- Per-domain counts within each Standard rule

**Mode determination based on total findings:**

- ≤ **20 findings** → **file-level mode** (existing inline format from dev.10, no dry-run file)
- > 20 findings → **rule-level mode** with tier+domain grouping AND lint-report.md dry-run file written first

---

## Step 4 — Batch Approval Plan

Present findings in one of two modes based on total count (Step 3):

- ≤ 20 findings → **file-level mode** (Templates L.A / L.B, inline only)
- > 20 findings → **rule-level mode** (Templates L.RL.A / L.RL.B + lint-report.md dry-run file)

The full text of each template is in **`references/templates.md`** — read that file when you need the exact body to render.

Templates available:

- **L.A / L.B** — file-level mode (≤20 findings; tier-grouped inline, no dry-run file), JP and EN
- **lint-report.md (dry-run)** — written to vault root in rule-level mode; full structured report for offline review in Obsidian
- **L.RL.A / L.RL.B** — rule-level mode (>20 findings; tier + per-domain breakdown, conversational per-rule prompts), JP and EN

User flow (natural language で interpret):

1. **Trivial**: 一括適用 / やめる / 特定 rule の詳細表示 (例「A4 を見せて」) のいずれかを user の言葉で受ける
2. **Standard per-rule**: 「全部」「特定 domain だけ」「やめる」「全件見せて」のような answer を解釈
3. **Review (opt-in)**: Standard 完了後に walkthrough 提案 → 同意なら per-rule で per-finding 確認 (適用 / 飛ばす / この rule もう終わり、のような answer)

Within Review walkthrough:
- A2/A3/A6/A9-add/A10 (applicable Review rules): per-finding 修正案を提示、user の judgment 求める
- B1-B4/C1-C3 (advisory Review rules): 表示のみ、auto-skip apply (修正案 propose せず、user 手動 fix 前提)

---

## Step 5 — Apply fixes

For each approved auto-fix finding, write changes via kepano `obsidian-cli` (preferred) or Edit tool (fallback).

### 5.1 — Frontmatter writes

For per-key changes (add field, drop field, change value):

```bash
obsidian property:set name="<key>" value="<value>" file="<file>"
obsidian property:remove name="<key>" file="<file>"
```

For complex frontmatter rewrites (multi-key addition with array values), use Edit tool to manipulate the YAML block directly — `obsidian property:set` may not handle arrays cleanly across CLI versions.

### 5.2 — `関連` / `contexts` populate (A8)

For each affected file:

1. `obsidian read path="<file>"` to get current state
2. Parse body `## 関連` / `## Related` section, extract bare wikilinks (drop annotations)
3. Filter out parent wiki-index (the `categories` first entry)
4. Edit tool to insert/replace the `関連:` / `contexts:` frontmatter array

### 5.3 — Order of operations (tier-driven)

Apply in tier order; each tier completes before the next begins:

1. **🟢 Trivial tier** (if user approved at Step 4): apply A4, A5, A7, A9-safe in one pass — text-level mechanical fixes
2. **🟡 Standard tier** (per-rule, per-domain user approvals from Step 4): apply A1, A8 in approved scope
3. **🔴 Review tier** (only if user opted in at Step 4): walk per-finding with conversational prompts (適用しますか / 次の rule に進みますか / この rule もう終わり、など自然語の answer を受ける); apply A2/A3/A6/A9-add/A10 as confirmed; B1-B4 and C1-C3 are advisory-only and produce no writes
4. **Bump `updated` / `更新日`** on every file actually modified — content changed per canonical L96. Skip files where all approved fixes were no-ops or skipped.
5. **Log the lint pass** to vault-level `lint-log.md` (see 5.4)
6. **Mode-specific cleanup**: in rule-level mode, leave `lint-report.md` in place (user may want to keep it as a snapshot); subsequent `/lint-vault` runs overwrite it. Optionally suggest archive (move to `lint-report-<date>.md`) if user requests history.

### 5.4 — Lint log

Append a single lint entry to a vault-level log file (`<vault>/lint-log.md`, create if absent). This is **not** a domain-scoped log; it lives at vault root for cross-domain bookkeeping.

```markdown
## [YYYY-MM-DD] lint | <N> files scanned, mode=<file-level|rule-level>
- Tier counts: 🟢 Trivial <T>, 🟡 Standard <S>, 🔴 Review <R>
- Applied:
  - Trivial: A4×<n>, A5×<n>, A7×<n>, A9-safe×<n>
  - Standard: A1×<n> (Inbox×<n>, パーソナル×<n>, …), A8×<n> (…)
  - Review (opt-in): A2×<n>, A3×<n>, A6×<n>, A9-add×<n>, A10×<n>
- Skipped / deferred: <rule-id>×<n> per user choice
- Advisory (no write): B1×<n>, B2×<n>, B3×<n>, B4×<n>, C1×<n>, C2×<n>, C3×<n>
- Vault snapshot: <total-md-count> files, <wiki-page-count> wiki pages, <wiki-index-count> indexes
- Dry-run report: <yes/no — only "yes" if rule-level mode, points to lint-report.md>
```

If `<vault>/lint-log.md` doesn't exist, create it with this frontmatter:

```yaml
---
"タイプ": ログ
"タグ": [lint, vault-health]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "vault 全体の lint パス記録"
"出典": []
"エイリアス": []
---

# Lint log
```

The lint log is **vault-scoped, not domain-scoped** — it's distinct from `<domain>-log.md` which records ingest/query within a single wiki.

### 5.5 — Important: do not write `cssclasses`

Same divergence as add-page: claude-wiki does not emit `cssclasses` even when kepano's `obsidian-markdown` skill suggests it. Lint actively *removes* it via A7 — never re-adds.

---

## Step 6 — Confirmation report

Summarize the result with tier breakdown:

> **JP:**
> ```
> ✅ Lint 完了。
>
> 📊 集計
>   スキャンファイル:     <N>
>   Mode:                <file-level|rule-level>
>   🟢 Trivial 適用:      <applied> / <T>
>   🟡 Standard 適用:     <applied> / <S> (domain breakdown: Inbox×<n>, パーソナル×<n>, …)
>   🔴 Review 適用 (opt-in): <applied> / <reviewable subset of R>
>   🔴 Review advisory:   <advisory-count> (B1-B4, C1-C3、修正なし)
>   ⏭ スキップ:          <skipped-count>
>
> 修正されたファイル一覧 (<applied-files>):
>   <file-1>: 🟢 A4, 🟡 A1, 🟡 A8 を適用
>   <file-2>: 🟡 A8 を適用
>   ...
>
> 📄 dry-run snapshot: vault/lint-report.md (rule-level mode のみ)
> 📜 履歴: vault/lint-log.md
>
> 💡 次のステップ:
>   - Review advisory 項目 (orphan/dead-link/sub-wiki) は手動判断
>   - 残った Review applicable (A2 enum drift など) は次回 `/lint-vault` で再 walkthrough 可
> ```

> **EN:**
> ```
> ✅ Lint complete.
>
> 📊 Summary
>   Files scanned:        <N>
>   Mode:                 <file-level|rule-level>
>   🟢 Trivial applied:   <applied> / <T>
>   🟡 Standard applied:  <applied> / <S> (domains: Inbox×<n>, …)
>   🔴 Review applied (opt-in): <applied> / <reviewable subset of R>
>   🔴 Review advisory:   <advisory-count> (B1-B4, C1-C3, no writes)
>   ⏭ Skipped:           <skipped-count>
>
> Modified files (<applied-files>):
>   <file-1>: applied 🟢 A4, 🟡 A1, 🟡 A8
>   ...
>
> 📄 Dry-run snapshot: vault/lint-report.md (rule-level mode only)
> 📜 History: vault/lint-log.md
>
> 💡 Next steps:
>   - Review advisory items (orphans/dead-links/sub-wiki) are manual decisions
>   - Remaining Review applicable items (A2 enum drift, etc.) can be walked again next `/lint-vault`
> ```

---

## Frontmatter rules (apply to lint-log.md and any rewrites)

Same as add-page:

- Date strings always quoted: `更新日: '2026-04-30'` / `updated: '2026-04-30'`
- JP keys quoted: `"タイプ": ログ`
- EN keys unquoted: `type: wiki-log`
- Wiki-link arrays: `カテゴリ: ["[[parent]]"]`
- **No `cssclasses`** (retired)
- `関連` / `contexts` only when populated; empty array OK as placeholder

---

## Out of scope (deferred to v0.1.1+)

- **D. Staleness rules** — `updated > verified_date` flag, fast-moving topic 6-month re-verification (canonical L151-153). Vault that's all `draft` (typical v0.1.0 dogfood) doesn't yet exercise these.
- **`_lint_skip: true` honored** — file-level opt-out from lint (canonical L155). Add when staleness ships.
- **Auto-fix for B (kepano hygiene)** — orphans/dead-links/dead-ends require user judgment, can't auto-fix safely.
- **Custom rule plugins** — third-party rule extensions, fixed rule set in v0.1.0.
- **Verified-page promotion gate** — A9 currently auto-removes orphan `verified_date` but doesn't auto-promote `draft` → `verified`.
- **Severity tiers** (`error` / `warning` / `info`) — flat `auto` vs `review` split is enough for v0.1.0; finer severity in v0.2.0 if needed.
- **Raw-source schema validation** — raw/ files are excluded from A1-A10 (see Step 2 scope exclusions). v0.2.0+ may add a separate raw-source schema (e.g. require `source_url` for clipped content) once conventions stabilize.

---

## Implementation notes

- **Idempotent**: running `/lint-vault` twice in a row should produce no findings on the second pass for Trivial + Standard tiers (assuming no external changes between). Review tier always re-surfaces if the underlying issue persists.
- **Read-mostly until Step 4.1**: in file-level mode, no writes before Step 5 (apply pass). In rule-level mode, the only Step 4 write is `lint-report.md` (dry-run artifact, overwritable). All other writes wait for user approval.
- **Performance**: kepano hygiene queries (B1-B4) are vault-wide; cache results per invocation. Per-file YAML parsing (A1-A10) is the main cost — can parallelize across files if vault is large (>100 pages). Initial migration of a 1000-page vault may take 1-2 minutes for full scan.
- **Error handling**: if a single file's YAML is malformed, surface as 🔴 Review with the parse error, do not crash. Skip subsequent rules for that file.
- **Mode switching**: threshold is 20 total findings. Edge case: if findings = 19 with Review tier dominant (≥15 Review items), still use file-level mode — Review items are report-only and don't bloat the inline display significantly.
- **Domain detection** (top-level folder): use `obsidian properties counts` if available; otherwise the first path segment after vault root. Files at vault root (e.g. `README.md`, `lint-log.md`, `lint-report.md`) belong to a synthetic `<root>/` group.
- **Testing**:
  - Small (≤ 20): dogfood vault `~/Documents/claude-wiki-dogfood-2026-04-30/` — file-level mode, verifies tier classification. After dev.10, only Review items remain (C1, A1/A2 raw — covered by raw/ exclusion in dev.10).
  - Large (> 20): synthetic test against an existing personal vault on first migration — verifies rule-level mode + lint-report.md + per-domain breakdown + Review opt-in walkthrough.
