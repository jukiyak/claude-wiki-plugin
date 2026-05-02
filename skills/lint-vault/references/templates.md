# lint-vault Batch Approval Templates

The full text of all lint Batch Approval Plan templates. The main SKILL.md links here from Step 4 — read this file when you need the exact body to render.

Two modes determined by total findings count:
- **≤ 20 findings → file-level mode** (Templates L.A / L.B inline; no dry-run file)
- **> 20 findings → rule-level mode** (lint-report.md dry-run + inline tier-grouped summary)

## File-level mode (≤ 20 findings)

For small vaults or incremental lint passes. Show all findings inline grouped by tier, then by rule, no domain grouping. User approves once.

### Template L.A — file-level, LOCALE = ja

```markdown
Lint レポート: <vault-path>

スキャン: 17 rules、<N> files、<X> 件 findings (🟢 Trivial: <T>、🟡 Standard: <S>、🔴 Review: <R>)

🟢 Trivial (<T> 件、機械的 fix)
### A4 [Date unquoted]
- <file-1>: `更新日: 2026-04-30` → `'2026-04-30'`

### A7 [Retired keys]
- <file-1>: `cssclasses` drop

🟡 Standard (<S> 件、deterministic populate)
### A1 [Required field 不在]
- <file-1>: `タグ` 追加 (default `[]`)

### A8 [関連 mirroring (dev.9 fix)]
- <file-1>: body `## 関連` の 4 wikilinks を frontmatter `関連:` に populate
- <file-2>: 同上、5 wikilinks

🔴 Review (<R> 件、判断必要 — 報告のみ default)
### A2 [Type enum 不正値]
- <file-1>: `type: reference` (canonical: `wiki-page`?)

### B1 [Orphan pages]
- [[<page-1>]]

### C1 [Sub-wiki threshold]
- `<domain>/`: 7+ wiki-pages — split / wiki/ bucket / status-quo (see CANONICAL.md → Sub-Wiki Criteria for the three options)

🔧 Trivial と Standard をまとめて適用しますか？ Review 項目も一緒に walkthrough したい場合は「Review も見たい」と教えてください。特定の rule だけ適用したい場合は「A4 と A8 だけ」のように、何もしない場合はその旨を伝えてもらえれば。
```

### Template L.B — file-level, LOCALE = en

```markdown
Lint report: <vault-path>

Scan: 17 rules, <N> files, <X> findings (🟢 Trivial: <T>, 🟡 Standard: <S>, 🔴 Review: <R>)

🟢 Trivial (<T>, mechanical)
### A4 [Date unquoted]
- <file-1>: `updated: 2026-04-30` → `'2026-04-30'`
### A7 [Retired keys]
- <file-1>: drop `cssclasses`

🟡 Standard (<S>, deterministic populate)
### A1 [Missing required field]
- <file-1>: add `tags` (default `[]`)
### A8 [contexts mirroring]
- <file-1>: populate `contexts:` from 4 body `## Related` wikilinks

🔴 Review (<R>, judgment required — report-only default)
### A2 [Invalid type enum]
- <file-1>: `type: reference` (canonical: `wiki-page`?)
### B1 [Orphan pages]
- [[<page-1>]]
### C1 [Sub-wiki threshold]
- `<domain>/`: 7+ wiki-pages — split / wiki/ bucket / status-quo (see CANONICAL.md → Sub-Wiki Criteria for the three options)

🔧 Apply Trivial + Standard together? If you'd like to walk through Review items too, just say so. To apply only specific rules, e.g. "only A4 and A8". Or just say "skip" to leave things as-is.
```

## Rule-level mode (> 20 findings) — initial migration UX

For large vaults. Two outputs in parallel:

1. **lint-report.md** written to vault root — full structured report for offline review in Obsidian
2. **Inline rule-level summary** in chat — interactive approval per tier and per rule

### Step 4.1 — Write lint-report.md (dry-run artifact)

Overwrite (single snapshot per `/lint-vault` invocation):

```yaml
---
"タイプ": ログ
"タグ": [lint, dry-run, vault-health]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "Lint dry-run report — review in Obsidian, then approve in chat"
"出典": []
"エイリアス": []
---

# Lint dry-run report

Generated: <YYYY-MM-DD HH:MM>
Mode: rule-level (<X> findings > 20 threshold)
Vault: <vault-path>

## Tier counts
- 🟢 Trivial:  <T>
- 🟡 Standard: <S>
- 🔴 Review:   <R>

## 🟢 Trivial fixes (will batch-apply on approval)

### A4 [Date unquoted]: <n> items
- <file-1>
- <file-2>
…

### A7 [Retired keys]: <n> items
- …

## 🟡 Standard fixes (will batch-apply per rule, per domain on approval)

### A1 [Required field 不在]: <n> items
#### Inbox/ (<n>)
- …
#### システム/ (<n>)
- …
#### パーソナル/ (<n>)
- …

### A8 [関連 mirror]: <n> items
#### …

## 🔴 Review (manual decision; opt-in apply available in chat)

### A2 [Type enum drift]: <n> items
- <file-1>: `type: reference` → `wiki-page`? (suggested)
…

### B1 [Orphan pages]: <n> items
- [[<page-1>]]
…

### C1 [Sub-wiki threshold]: <n> items
- …

---

To approve: respond in chat. Approve order is Trivial → Standard (per rule, optionally per domain) → optional Review walkthrough.
```

### Step 4.2 — Inline rule-level template, LOCALE = ja

```markdown
Lint レポート: <vault-path>
スキャン: 17 rules、<N> files、<X> 件 findings (Threshold 20 超 → rule-level mode)

📄 詳細レポート: vault/lint-report.md (Obsidian で offline review 推奨)

📊 Tier 集計
  🟢 Trivial:   <T> 件 (A4×<n>、A7×<n>)
  🟡 Standard:  <S> 件 (A1×<n>、A8×<n>)
  🔴 Review:    <R> 件 (A2×<n>、B1×<n>、C1×<n>、…)

═══════════════════════════════════════
🟢 Trivial 一括 apply 提案

  - A4 (date unquoted): <n> 件 (samples: <file-1>, <file-2>, <file-3>)
  - A7 (retired keys):  <n> 件

  Trivial の <T> 件をまとめて適用しましょうか？ 詳しく見たい rule があれば「A4 を見せて」のように教えてください。やめる場合もその旨を。

═══════════════════════════════════════
🟡 Standard (rule + domain ごとに承認)

  A1 [Required field 不在]: <n> 件
    - Inbox/:      <n> 件 (sample: <files>)
    - システム/:    <n> 件 (sample: <files>)
    - パーソナル/:  <n> 件 (sample: <files>)
    - 仕事/:       <n> 件 (sample: <files>)

    A1 を適用しますか？ 「全部」「Inbox とパーソナルだけ」「やめる」「全件見せて」のような答え方で大丈夫です。

  A8 [関連 mirror]: <n> 件
    - <domain breakdown>

    A8 を適用しますか？ 「全部」「<domain> だけ」「やめる」「全件見せて」のように答えてもらえれば。

═══════════════════════════════════════
🔴 Review (報告のみ default)

  A2 [Type enum drift]: <n> 件
    - sample: <file-1>: `type: reference` → `wiki-page`?

  B1 [Orphan pages]: <n> 件
    - sample: [[<page-1>]]

  C1 [Sub-wiki threshold]: <n> 件
    - <sample>

  Review 項目を 1 つずつ見ていきますか？ 黙って終了でも OK です (default は skip)。
```

### Template L.RL.B — rule-level, LOCALE = en

```markdown
Lint report: <vault-path>
Scan: 17 rules, <N> files, <X> findings (Threshold 20 exceeded → rule-level mode)

📄 Detailed report: vault/lint-report.md (recommended for offline review in Obsidian)

📊 Tier counts
  🟢 Trivial:   <T> (A4×<n>, A7×<n>)
  🟡 Standard:  <S> (A1×<n>, A8×<n>)
  🔴 Review:    <R> (A2×<n>, B1×<n>, C1×<n>, …)

═══════════════════════════════════════
🟢 Trivial bulk-apply proposal

  - A4 (date unquoted): <n> findings (samples: <file-1>, <file-2>, <file-3>)
  - A7 (retired keys):  <n> findings

  Apply all <T> Trivial fixes? Let me know if you want to see a specific rule's details (e.g. "show me A4"). "Skip" if you'd rather leave them.

═══════════════════════════════════════
🟡 Standard (per-rule, optionally per-domain)

  A1 [Missing required field]: <n> findings
    - inbox/:    <n> (sample: <files>)
    - system/:   <n> (sample: <files>)
    - personal/: <n> (sample: <files>)
    - work/:     <n> (sample: <files>)

    Apply A1? "All of them", "just inbox and personal", "skip", or "show all" — natural-language answers OK.

  A8 [contexts mirror]: <n> findings
    - <domain breakdown>

    Apply A8? "All", "<domain> only", "skip", or "show all".

═══════════════════════════════════════
🔴 Review (report-only by default)

  A2 [Type enum drift]: <n> findings
    - sample: <file-1>: `type: reference` → `wiki-page`?

  B1 [Orphan pages]: <n> findings
    - sample: [[<page-1>]]

  C1 [Sub-wiki threshold]: <n> findings
    - <sample>

  Walk through Review items one by one? Saying nothing is fine — default is skip.
```

(Mirrors L.RL.A semantics; same Trivial → Standard → Review sequence with conversational prompts.)
