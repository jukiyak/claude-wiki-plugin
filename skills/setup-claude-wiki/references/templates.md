# Setup Templates (Step 7 file scaffolds)

This reference file holds the full text of each scaffold file written by `setup-claude-wiki` Step 7. The main SKILL.md links here from Step 7 — read this file when you need the exact body of a template.

All templates pair JP and EN versions. Use the locale chosen in Step 3.

## Template 7.A — `README.md` (vault root)

**LOCALE = ja:**

```markdown
---
"タイプ": wikiページ
"タグ": [claude-wiki, オリエンテーション]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "claude-wiki でセットアップしたセカンドブレインのオリエンテーションページ"
"出典": []
"エイリアス": []
---

# YOUR-VAULT-NAME

claude-wiki プラグインがセットアップしたあなたのセカンドブレイン（第2の脳）です。

## 役割分担 (3 階層モデル)

| 階層 | 担当 | 何を置くか |
|:--|:--|:--|
| Raw sources | あなた | 記事、PDF、トランスクリプト。`raw/` 以下に置く。書き換えない |
| Wiki | Claude | サマリ、索引、相互参照、ログ。スキルが生成・維持する |
| Schema | 両方 | 規約は plugin と https://github.com/jukiyak/claude-wiki-plugin に存在 |

## あなたの vault 構造

(Step 6 で承認した tree をここに ASCII で挿入)

各ドメインフォルダには「索引 (`<ドメイン名>/<ドメイン名>.md`)」と「ログ (`<ドメイン名>/<ドメイン名>-log.md`)」だけが今あります。コンテンツが集まってきたら、Claude がページを増やし、相互参照を維持します。

## 育て方

- 各ドメインフォルダに普通に Markdown を書いていけば OK。Claude が読んでファイリングを手伝います

**今すぐ使えるスキル** (kepano/obsidian-skills + Obsidian 起動中):
- `/add-page` — ページを追加 (interview + Batch Approval)
- `/lint-vault` — vault の schema/hygiene/structural チェック (auto-fix 付き)
- `/query-wiki` — vault に質問 → 引用付き回答 + 必要なら wiki 化

**今後の plugin 更新で追加予定:**
- `/daily-log` — optional の日次ログスキル (v0.1.1+)

詳しい canonical な原則・ルールは https://github.com/jukiyak/claude-wiki-plugin

## 言語ロック

このセットアップでは「日本語」を選びました。frontmatter キー (`タイプ`, `タグ` 等) も日本語です。後から英語に切り替えるには、v0.2.0+ で予定されている移行スキルを待ってください。
```

**LOCALE = en:**

```markdown
---
type: wiki-page
tags: [claude-wiki, orientation]
categories: []
status: draft
updated: 'YYYY-MM-DD'
summary: "Orientation page for the knowledge base set up by the claude-wiki plugin."
sources: []
aliases: []
---

# YOUR-VAULT-NAME

This is your knowledge base, set up by the claude-wiki plugin.

## Three-layer ownership model

| Layer | Owner | What lives here |
|:--|:--|:--|
| Raw sources | You | Articles, PDFs, transcripts under `raw/` folders. Immutable. |
| Wiki | Claude | Summaries, indexes, cross-references, logs. Generated and maintained by skills. |
| Schema | Both | Conventions live in the plugin (https://github.com/jukiyak/claude-wiki-plugin). |

## Your vault structure

(Insert the ASCII tree the user approved in Step 6.)

Each domain folder currently has only an index (`<domain>/<domain>.md`) and a log (`<domain>/<domain>-log.md`). As content arrives, Claude will add pages and maintain cross-references.

## How to grow it

- Write Markdown freely under any domain folder. Claude can read and help file what you produce.

**Available now** (require kepano/obsidian-skills + a running Obsidian):
- `/add-page` — ingest a new page (interview + Batch Approval)
- `/lint-vault` — schema / hygiene / structural health check with auto-fix
- `/query-wiki` — query the vault → cited synthesis, graduate to a wiki page when worth keeping

**Planned in upcoming plugin updates:**
- `/daily-log` — optional daily-journaling skill (v0.1.1+)

Canonical principles and rules: https://github.com/jukiyak/claude-wiki-plugin

## Locale lock

This setup chose `English`. Frontmatter keys (`type`, `tags`, etc.) are in English. To switch later, wait for the migration skill planned for v0.2.0+.
```

## Template 7.B — Inbox root-index (`Inbox/Inbox.md`)

The file lives **inside** the `Inbox/` folder.

**LOCALE = ja:**

```markdown
---
"タイプ": ルート索引
"タグ": [Inbox, 着地点]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "未分類ノートのデフォルト着地場所"
"出典": []
"エイリアス": []
---

# Inbox

未分類のノートをここに置いてください。Claude が読んで、適切なドメインへの仕分けを提案します。

## 使い方

- 思いついたメモ、Web からのクリッピング、議事録の下書きなど、行き先がはっきりしないものをここへ
- 定期的にレビューし、ドメインに振り分けるか、不要なら削除
```

**LOCALE = en:**

```markdown
---
type: root-index
tags: [Inbox, landing-zone]
categories: []
status: draft
updated: 'YYYY-MM-DD'
summary: "Default landing zone for uncategorized notes."
sources: []
aliases: []
---

# Inbox

Drop uncategorized notes here. Claude can read them and suggest where each belongs.

## How to use

- Quick captures, web clippings, raw meeting notes — anything without an obvious home
- Review periodically; either route to a domain or delete
```

## Template 7.B-2 — System root-index (`システム/システム.md` / `System/System.md`)

The cross-domain folder is mandatory. Default name `システム` (JP) / `System` (EN); honor any user override from Step 6c.

**LOCALE = ja:**

```markdown
---
"タイプ": ルート索引
"タグ": [システム, 横断]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "領域横断ノートの置き場 — 複数ドメインに関わる用語集、振り返り、メタ文書 など"
"出典": []
"エイリアス": []
---

# システム

仕事と個人など複数の領域にまたがるノートをここに置きます。

## 使い方

- 用語集、ガイド、振り返りなど、特定ドメインに収まらないもの
- このフォルダ自体のメタ文書 (vault の運用ルール、Claude との約束ごと) もここに
```

**LOCALE = en:**

```markdown
---
type: root-index
tags: [system, cross-domain]
categories: []
status: draft
updated: 'YYYY-MM-DD'
summary: "Cross-domain landing zone — glossaries, retrospectives, meta-docs that span multiple domains."
sources: []
aliases: []
---

# System

Holds notes that span more than one domain (work + personal, or any cross-cutting topic).

## How to use

- Glossaries, guides, retrospectives — anything that doesn't sit inside a single domain
- Meta-docs about the vault itself (operating rules, conventions you've agreed with Claude) live here
```

## Template 7.C — top-folder root-index (`<top-folder>/<top-folder>.md`)

The file lives **inside** the top-level folder it indexes (e.g. `パーソナル/パーソナル.md`, `仕事/仕事.md`, `personal/personal.md`). Use the user's exact folder name (without `.md`) as the title.

**LOCALE = ja:**

```markdown
---
"タイプ": ルート索引
"タグ": []
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<Step 6 で ユーザーが述べた、このフォルダの目的>"
"出典": []
"エイリアス": []
---

# <FOLDER-NAME>

このフォルダのドメイン:

- [[<domain-1>]]
- [[<domain-2>]]
...
```

**LOCALE = en:**

```markdown
---
type: root-index
tags: []
categories: []
status: draft
updated: 'YYYY-MM-DD'
summary: "<one-line user-supplied purpose for this top-level folder>"
sources: []
aliases: []
---

# <folder-name>

Domains in this folder:

- [[<domain-1>]]
- [[<domain-2>]]
...
```

## Template 7.D — domain wiki-index (e.g. `健康.md` / `health.md`)

**LOCALE = ja:**

```markdown
---
"タイプ": 索引
"タグ": []
"カテゴリ": ["[[<上位フォルダ名>]]"]
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<ユーザーが Step 5 で説明した、このドメインの 1 行サマリ>"
"出典": []
"エイリアス": []
---

# <ドメイン名>

このドメインで追跡している内容のホームページです。コンテンツが集まると、Claude がここにページの索引を追加します。

## ページ

(まだなし — 初めてのページが追加されたら自動で記載されます)

## 出典

(まだなし)

## ログ

[[<ドメイン名>-log]]
```

For flat-mode setups, replace `"カテゴリ": ["[[<上位フォルダ名>]]"]` with `"カテゴリ": []`.

**LOCALE = en:**

```markdown
---
type: wiki-index
tags: []
categories: ["[[<top-folder-name>]]"]
status: draft
updated: 'YYYY-MM-DD'
summary: "<one-line user-supplied summary for this domain>"
sources: []
aliases: []
---

# <domain-name>

Home for everything tracked under this domain. As content arrives, Claude will list pages here.

## Pages

(none yet — added automatically when the first page lands)

## Sources

(none yet)

## Log

[[<domain-name>-log]]
```

For flat-mode setups, replace `categories: ["[[<top-folder-name>]]"]` with `categories: []`.

## Template 7.E — domain wiki-log (e.g. `健康-log.md` / `health-log.md`)

**LOCALE = ja:**

```markdown
---
"タイプ": ログ
"タグ": []
"カテゴリ": ["[[<ドメイン名>]]"]
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<ドメイン名> ドメインの追記専用ログ"
"出典": []
"エイリアス": []
---

# <ドメイン名> ログ

## [YYYY-MM-DD] init | <ドメイン名> セットアップ
- claude-wiki プラグインのセットアップインタビューで作成
- ユーザーの意図: <Step 5 でユーザーが表現した目的の 1 行要約>
```

**LOCALE = en:**

```markdown
---
type: wiki-log
tags: []
categories: ["[[<domain-name>]]"]
status: draft
updated: 'YYYY-MM-DD'
summary: "Append-only activity log for the <domain-name> domain."
sources: []
aliases: []
---

# <domain-name> log

## [YYYY-MM-DD] init | <domain-name> setup
- Created via claude-wiki plugin setup interview
- User-stated intent: <one-line paraphrase of the user's Step 5 description>
```
