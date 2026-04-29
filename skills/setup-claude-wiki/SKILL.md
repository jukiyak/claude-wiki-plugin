---
name: setup-claude-wiki
description: Use this skill when the user wants to set up claude-wiki in a folder, initialize a knowledge-base vault, start a new wiki, or convert an empty folder into a Claude-managed Obsidian vault. The skill conducts an interactive interview — asks the user's language (日本語 / English), elicits which domains they want to track in their own words, helps them name top-level folders in vocabulary that feels natural, and writes only the minimum scaffold (one root index per top folder + one wiki-index and wiki-log per domain). No bundled templates, no domain presets — the user's structure and vocabulary drive the result. English triggers include "set up claude-wiki", "init claude-wiki", "start a wiki", "/setup-claude-wiki". Japanese triggers include "claude-wiki をセットアップ", "セットアップ", "Vault をセットアップ", "knowledge base をセットアップ", "wiki を始める", "初期化".
---

# Setup claude-wiki Vault (interview-driven)

> Conducts an interactive interview, then writes the minimum scaffold the user has approved. Honors Karpathy's LLM Wiki principle that **the user curates and the LLM bookkeeps** — structure must be elicited, not imposed.

## Behavior summary

The skill walks the user through eight steps, in order:

1. **Folder gate** — confirm the user has a folder selected in Cowork
2. **Empty-folder check** — if non-empty, summarize and confirm before proceeding
3. **Language selection** — JP or EN, locks the vault's locale for filenames + frontmatter keys + values + body
4. **Orientation** — two-line description of the three-layer ownership model
5. **Elicit domains** — free-form: what areas does the user want to track?
6. **Categorize and name** — propose a folder structure with user-friendly names; iterate until approved
7. **Write the minimum scaffold** — only the files the user approved; nothing else
8. **Confirmation message** — show the tree, suggest next steps

No domain presets. No bundled wiki-page or daily-log templates — those emerge through first-use interviews in `daily-log` and `add-page` (later plugin versions).

---

## Step 1 — Folder gate

Confirm Cowork has a folder selected and writeable. If not, instruct the user:

> 日本語: Cowork のフォルダピッカー (Customize → Folders → `+`) で空のフォルダを選択してから、もう一度このスキルを呼び出してください。
>
> English: Pick an empty folder in Cowork's folder picker (Customize → Folders → `+`) and re-run this skill.

Stop and do not write anything.

---

## Step 2 — Empty-folder check

List the contents of the selected folder. If it is **not** empty:

- Summarize what is there in 3-5 lines (top-level files and folders, count of `.md` files).
- Ask the user via AskUserQuestion:
  - Option A: "Set up alongside existing files (won't overwrite anything that already exists)"
  - Option B: "Stop — let me pick a different empty folder"
  - Option C: "Stop — I'll re-run after I clean this folder up"

**Default to stopping.** If the response is unclear or partial, do **not** proceed. Never overwrite silently. Never delete or move existing files.

If the folder is empty, proceed to Step 3 with no message.

---

## Step 3 — Language selection

Use AskUserQuestion with two options:

- 日本語 (Japanese)
- English

Bind the result to a variable `LOCALE ∈ { ja, en }` for the rest of the skill. The choice locks the vault's language for **all** files written by setup:

- Filenames (e.g. `健康.md` vs `health.md`)
- Frontmatter keys (e.g. `タイプ:` vs `type:`)
- Frontmatter values (e.g. `下書き` vs `draft`)
- Body markdown

This is a one-way commit for v0.1.0. A migration skill is planned for v0.2.0+.

The skill itself (this SKILL.md) and plugin metadata stay in English regardless — they are plugin internals, not vault contents.

---

## Step 4 — Orientation

Send a short message in the chosen locale.

**LOCALE = ja:**
```
これから、あなたの knowledge base を作るための簡単なインタビューを行います。

claude-wiki の役割分担:
- あなた → 何を記録する価値があるかを決める / ソースを集める
- Claude → ファイリング、相互参照、ログを担当
- Obsidian → 形を表示する

まず最小スカフォールドだけを作ります。各ドメインに「索引」と「ログ」の 2 ファイルだけ。中身は実際にコンテンツが集まってから足します。
```

**LOCALE = en:**
```
I'll walk you through a short interview to set up your knowledge base.

claude-wiki's division of labor:
- You — decide what's worth tracking, gather sources
- Claude — handles filing, cross-references, logs
- Obsidian — displays the shape

We start with the absolute minimum: an index and a log per domain. Real content lands later, as you actually capture it.
```

---

## Step 5 — Elicit domains (free-form)

Ask in plain text (not AskUserQuestion — this is a free-form list).

**LOCALE = ja:**
```
この knowledge base で追跡したい領域を 2-8 個、自分の言葉で挙げてください。
例: 仕事、個人、健康、読書、家族
```

**LOCALE = en:**
```
List 2-8 areas you want to track in this knowledge base, in your own words.
Examples: work, personal, health, reading, family.
```

Read the user's reply as a list of domain names. Do not transform their wording — preserve their exact spelling and language. If the user provides fewer than 2 or more than 8, gently ask them to refine (1 domain feels too narrow for a "wiki"; 9+ usually means some can collapse into one).

---

## Step 6 — Categorize and name

Propose a folder structure for the user's domains. The proposal must:

### 6a. Group into top-level folders (when there are ≥4 domains)

Group the user's domains into 2-3 top-level buckets. Suggest natural-language names for each bucket. Do **not** force the canonical English names (`self/`, `work/`, `system/`) — show them as one option among several, and adapt to the user's locale.

**Default candidates (LOCALE = ja):**

| Conceptual bucket | Candidate names (user picks one or supplies their own) |
|:--|:--|
| Personal / private | `パーソナル` (default) / `プライベート` / `個人` / `自分` |
| Work / business | `仕事` (default) / `職場` / `業務` / their business name |
| Cross-domain / meta | `システム` (default) / `共通` / `共有` / `参照` / `Meta` / `基盤` |

The cross-domain bucket holds notes that span both work and private (e.g. sleep logs, glossaries, the wiki's own meta docs). General users usually want one too — propose it.

**Default candidates (LOCALE = en):**

| Conceptual bucket | Candidate names |
|:--|:--|
| Personal / private | `personal` (default) / `private` / `self` |
| Work / business | `work` (default) / business name |
| Cross-domain / meta | `system` (default) / `shared` / `reference` / `meta` |

### 6b. Allow flat structure (when there are ≤3 domains)

Offer flat as an alternative: each domain gets its own folder at the vault root, no top-level grouping. Useful for small wikis. In flat mode, no root-index files for top folders are written — each domain's wiki-index is the closest index to its files.

### 6c. Always include `Inbox/` and `System/` (or locale equivalent)

Two folders are mandatory in every vault, regardless of how the user grouped their domains:

- **`Inbox/`** — landing zone for unsorted notes. Default name `Inbox` (capitalized, JP/EN both). Honor any user override (e.g. `受信箱`, `仮置き`, `unsorted`).
- **`System/`** (LOCALE = en) / **`システム/`** (LOCALE = ja) — cross-domain folder for notes that span work + private (e.g. sleep logs, glossaries, the wiki's own meta docs). Honor any user override from Step 6a's candidates (`共通` / `共有` / `参照` / `Meta` / `基盤` etc., or any name the user supplies).

Both folders are created with their own root-index file inside (e.g. `Inbox/Inbox.md`, `システム/システム.md`). They start empty of sub-domains; the user fills them as content arrives. Skipping either is not a Step 6 option — they are always part of the scaffold.

### 6d. Display the proposal as an ASCII tree

Example (LOCALE = ja, nested):

```
your-vault/
├── README.md               ← オリエンテーション (vault root の唯一の .md)
├── Inbox/
│   └── Inbox.md            ← ルート索引 (default landing zone、必須)
├── システム/
│   └── システム.md         ← ルート索引 (横断ノート用、必須)
├── パーソナル/
│   ├── パーソナル.md       ← ルート索引
│   ├── 健康/
│   │   ├── 健康.md         ← 索引
│   │   └── 健康-log.md     ← ログ
│   └── 読書/
│       ├── 読書.md
│       └── 読書-log.md
└── 仕事/
    ├── 仕事.md
    ├── プロジェクト/
    │   ├── プロジェクト.md
    │   └── プロジェクト-log.md
    └── 顧客対応/
        ├── 顧客対応.md
        └── 顧客対応-log.md
```

Example (LOCALE = en, flat for 2-3 domains):

```
your-vault/
├── README.md
├── Inbox/
│   └── Inbox.md
├── system/
│   └── system.md
├── work/
│   ├── work.md
│   └── work-log.md
└── personal/
    ├── personal.md
    └── personal-log.md
```

**File-placement rule:** every `.md` file (except `README.md`) lives **inside the folder it indexes or logs**. Vault root holds exactly one file: `README.md`.

### 6e. Iterate until approved

Ask via AskUserQuestion:
- Option A: "Approve as-is — write the scaffold"
- Option B: "Modify — I want to rename a folder, move a domain, drop one, or add one"
- Option C: "Restart from Step 5"

If Modify, ask the user in plain text what changes they want, apply them to the proposal, and show the updated tree. Loop until Approve or Restart. Do **not** write any files until the user picks Approve.

### 6f. Filename safety

Each approved domain name will become a folder name **and** a markdown filename (e.g. domain `健康` → `パーソナル/健康/健康.md`). Before writing in Step 7, check each name for filesystem-unsafe characters: `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`, leading/trailing whitespace, leading dot. If any name is unsafe, show the offending name and ask the user for a safer replacement before proceeding.

### 6g. Downstream-skill independence

The plugin's other skills (`lint-vault`, `query-wiki`, `daily-log`, `add-page`) detect domain roots by **frontmatter `タイプ: ルート索引` / `type: root-index`**, not by hard-coded folder names. The user's chosen vocabulary will work — the plugin does not rely on the names matching `self`/`work`/`system`.

---

## Step 7 — Write the minimum scaffold

For the user-approved tree, write **only** the files listed below. Compute today's date as `YYYY-MM-DD` (use the Cowork session date) and quote it in every `更新日:` / `updated:` field.

### Files to write

The vault root holds exactly **one** file: `README.md`. Every other file lives inside the folder it indexes or logs.

For all setups (always created, regardless of nesting choice or domain list):
1. `README.md` (vault root) — orientation, see template 7.A
2. `Inbox/Inbox.md` (or user-chosen folder name with the matching index name inside) — root-index for the inbox folder, see template 7.B
3. `<system-folder>/<system-folder>.md` (default `System/System.md` for EN, `システム/システム.md` for JP) — root-index for the cross-domain folder, see template 7.B-2

For nested setups (≥4 domains):
4. For each top-level folder F that the user named: `F/F.md` — root-index, see template 7.C
5. For each domain D inside F: `F/D/D.md` — wiki-index, see template 7.D; and `F/D/D-log.md` — wiki-log, see template 7.E

For flat setups (≤3 domains, user chose flat):
4. For each domain D: `D/D.md` — wiki-index (template 7.D, with `categories: []` since there is no parent root-index above it) and `D/D-log.md` (template 7.E)

The Inbox and System folders are created with only their own root-index file. They start with no sub-domains; the user populates them as content arrives. Empty top-level folders (e.g. `パーソナル/`) only exist when at least one wiki-index file is written inside (the folder is created implicitly with the file write).

### Frontmatter rules (apply to every file written)

- **Date strings always quoted.** `更新日: '2026-04-29'` (not `更新日: 2026-04-29`). Same for `updated:`. YAML 1.1 parsers coerce unquoted dates to timestamps.
- **JP keys are quoted.** Use `"タイプ": 索引` form for JP-mode frontmatter to maximize parser compatibility. (Will be revisited after dogfood — if Obsidian's Properties panel renders unquoted JP keys cleanly, this constraint can relax in v0.1.1.)
- **EN keys are unquoted.** Use the standard form `type: wiki-index`.
- **Wiki-link arrays.** `カテゴリ: ["[[パーソナル]]"]` / `categories: ["[[personal]]"]`. Each link references the parent root-index file by name (no `.md` extension).
- **No trailing whitespace inside frontmatter.** YAML linters flag it.

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
| Type: wiki page | `ページ` | `wiki` |
| Status: draft | `下書き` | `draft` |
| Status: in review | `レビュー中` | `review` |
| Status: verified | `確認済み` | `verified` |
| Status: archived | `アーカイブ済み` | `archived` |

---

### Template 7.A — `README.md` (vault root)

**LOCALE = ja:**

```markdown
---
"タイプ": ページ
"タグ": [claude-wiki, オリエンテーション]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "claude-wiki でセットアップした knowledge base のオリエンテーションページ"
"出典": []
"エイリアス": []
---

# YOUR-VAULT-NAME

claude-wiki プラグインがセットアップしたあなたの knowledge base です。

## 役割分担 (3 階層モデル)

| 階層 | 担当 | 何を置くか |
|:--|:--|:--|
| Raw sources | あなた | 記事、PDF、トランスクリプト。`raw/` 以下に置く。書き換えない |
| Wiki | Claude | サマリ、索引、相互参照、ログ。スキルが生成・維持する |
| Schema | 両方 | 規約は plugin と `~/.claude/rules/` に存在 |

## あなたの vault 構造

(Step 6 で承認した tree をここに ASCII で挿入)

各ドメインフォルダには「索引 (`<ドメイン名>/<ドメイン名>.md`)」と「ログ (`<ドメイン名>/<ドメイン名>-log.md`)」だけが今あります。コンテンツが集まってきたら、Claude がページを増やし、相互参照を維持します。

## 育て方

- 各ドメインフォルダに普通に Markdown を書いていけば OK。Claude が読んで filing を手伝います
- 関連スキル (`/daily-log`, `/add-page`, `/query-wiki`, `/lint-vault`) は今後の plugin 更新で届きます
- 詳しい canonical な原則・ルールは https://github.com/jukiyak/claude-wiki-plugin

## 言語ロック

このセットアップでは「日本語」を選びました。frontmatter キー (`タイプ`, `タグ`, etc.) も日本語です。後から英語に切り替えるには、v0.2.0+ で予定されている migration skill を待ってください。
```

**LOCALE = en:**

```markdown
---
type: wiki
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
| Schema | Both | Conventions live in the plugin and `~/.claude/rules/`. |

## Your vault structure

(Insert the ASCII tree the user approved in Step 6.)

Each domain folder currently has only an index (`<domain>/<domain>.md`) and a log (`<domain>/<domain>-log.md`). As content arrives, Claude will add pages and maintain cross-references.

## How to grow it

- Write Markdown freely under any domain folder. Claude can read and help file what you produce.
- Companion skills (`/daily-log`, `/add-page`, `/query-wiki`, `/lint-vault`) ship in upcoming plugin releases.
- Canonical principles and rules: https://github.com/jukiyak/claude-wiki-plugin

## Locale lock

This setup chose `English`. Frontmatter keys (`type`, `tags`, etc.) are in English. To switch later, wait for the migration skill planned for v0.2.0+.
```

### Template 7.B — Inbox root-index (`Inbox/Inbox.md`)

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

### Template 7.B-2 — System root-index (`システム/システム.md` / `System/System.md`)

The cross-domain folder is mandatory. Default name `システム` (JP) / `System` (EN); honor any user override from Step 6c.

**LOCALE = ja:**

```markdown
---
"タイプ": ルート索引
"タグ": [システム, 横断]
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "領域横断ノートの置き場 — 複数ドメインに関わる用語集、振り返り、メタ docs など"
"出典": []
"エイリアス": []
---

# システム

仕事と個人など複数の領域にまたがるノートをここに置きます。

## 使い方

- 用語集、ガイド、振り返りなど、特定ドメインに収まらないもの
- このフォルダ自体のメタ docs (vault の運用ルール、Claude との約束ごと) もここに
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

### Template 7.C — top-folder root-index (`<top-folder>/<top-folder>.md`)

The file lives **inside** the top-level folder it indexes (e.g. `パーソナル/パーソナル.md`, `仕事/仕事.md`, `personal/personal.md`). Use the user's exact folder name (without `.md`) as the title.

**LOCALE = ja:**

```markdown
---
"タイプ": ルート索引
"タグ": []
"カテゴリ": []
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<ユーザーが Step 6 で表現した、この上位フォルダの目的を 1 行で>"
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

### Template 7.D — domain wiki-index (e.g. `健康.md` / `health.md`)

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

### Template 7.E — domain wiki-log (e.g. `健康-log.md` / `health-log.md`)

**LOCALE = ja:**

```markdown
---
"タイプ": ログ
"タグ": []
"カテゴリ": ["[[<ドメイン名>]]"]
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<ドメイン名> ドメインの append-only な活動ログ"
"出典": []
"エイリアス": []
---

# <ドメイン名> ログ

## [YYYY-MM-DD] init | <ドメイン名> セットアップ
- claude-wiki plugin v0.0.1 のセットアップ interview で作成
- ユーザーの意図: <Step 5 でユーザーが表現した目的の 1 行 paraphrase>
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
- Created via claude-wiki plugin v0.0.1 setup interview
- User-stated intent: <one-line paraphrase of the user's Step 5 description>
```

---

## Step 8 — Confirmation message

Print a confirmation. Show the created file tree as a tree-list with `computer://` links to each file. End with a short next-steps suggestion in the chosen locale.

**LOCALE = ja:**
```
✅ セットアップ完了。

(ここに ASCII tree、各ファイルに computer:// リンク)

各ドメインには「索引」と「ログ」しかまだありません — 中身は空です。ここから:

- README を開いて 3-layer モデルを確認
- 任意のドメインフォルダ配下で書き始める。Claude が読んで filing を手伝います
- `/daily-log`, `/add-page`, `/query-wiki`, `/lint-vault` は次の plugin 更新で届きます
```

**LOCALE = en:**
```
✅ Setup complete.

(ASCII tree with computer:// links to each file)

Each domain has only an index and a log so far — no content yet. From here:

- Open the README to read about the three-layer model
- Start writing under any domain folder; Claude can read and help file what you produce
- `/daily-log`, `/add-page`, `/query-wiki`, `/lint-vault` arrive in upcoming plugin updates
```

---

## Implementation notes

- **Never overwrite without explicit consent.** Step 2 catches the existing-files case. If a write target exists at Step 7 time (race condition), skip that file and report it in the Step 8 message.
- **Quote dates.** Every `更新日:` and `updated:` value is a quoted YYYY-MM-DD string, no exceptions.
- **Use the user's exact wording.** Domain names go into filenames, frontmatter values, and wiki-links unchanged. Do not lowercase, transliterate, or normalize.
- **Don't translate the user's choices.** If the user picked `日本語` and named a domain `health` (mixing locales), respect it — write `health.md` with JP frontmatter keys.
- **One language per vault.** The Step 3 selection drives every file. Don't mix EN and JP keys in the same file or across files in the same vault.
- **Always seed a log entry.** Each `*-log.md` gets the `init` entry described in Template 7.E. This honors the principle "the log is the wiki's memory of itself" from day zero.
- **Display the tree before writing.** Step 6 shows the proposal; Step 7 writes; Step 8 echoes. Never write before approval; never write without echoing.

## Why no domain presets, no bundled templates

The original v0.1.0 plan included bundled `wiki-page.md` and `daily-log.md` templates plus pre-baked domain presets (`general`, `coral-marine`, `power-user`). Both were dropped. Reasons:

- Imposing structure top-down violates the principle that the user curates and the LLM bookkeeps. The user's vocabulary should drive the schema, not the reverse.
- Templates that arrive before the user knows what they want will be ignored or fought.
- Presets like `coral-marine` are over-fitted to one early customer; they pollute the design with their assumptions.

Templates emerge later, through first-use interviews in `daily-log` and `add-page` (planned for upcoming plugin releases). The minimum scaffold this skill writes is enough to start; nothing more is needed.
