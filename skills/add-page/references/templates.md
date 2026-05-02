# add-page Frontmatter Templates

The full text of frontmatter scaffolds emitted by `add-page`. The main SKILL.md links here from Step 3 / Step 5; read this file when you need the exact frontmatter to write.

These templates follow the canonical schema bundled with the plugin at `${CLAUDE_PLUGIN_ROOT}/CANONICAL.md` (`Wiki Page Frontmatter` section). Plugin v0.1.0-dev.6+ uses `wiki-page` / `wikiページ` for the wiki page type — earlier canonical drafts used a bare `wiki` value.

The `関連:` / `contexts:` field appears with `[]` empty default — populate it from the body's `## 関連` / `## Related` wikilinks per the Frontmatter rules in SKILL.md (drop annotations, skip parent wiki-index).

## Template F.A — wiki-page, LOCALE = ja

```yaml
---
"タイプ": wikiページ
"タグ": []
"カテゴリ": ["[[<親ドメイン索引>]]"]
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<1 行サマリ>"
"出典": []  # or ["[[raw/<source>]]"]
"関連": []  # populate with bare wikilinks from body's ## 関連 section per Frontmatter rules. Drop annotations. Skip parent wiki-index.
"エイリアス": []
---
```

## Template F.B — wiki-page, LOCALE = en

```yaml
---
type: wiki-page
tags: []
categories: ["[[<parent-wiki-index>]]"]
status: draft
updated: 'YYYY-MM-DD'
summary: "<one-line summary>"
sources: []  # or ["[[raw/<source>]]"]
contexts: []  # populate with bare wikilinks from body's ## Related section per Frontmatter rules. Drop annotations. Skip parent wiki-index.
aliases: []
---
```

## Template F.C — new wiki-index (new-domain branch only), LOCALE = ja

```yaml
---
"タイプ": 索引
"タグ": []
"カテゴリ": ["[[<上位フォルダ名>]]"]
"ステータス": 下書き
"更新日": 'YYYY-MM-DD'
"まとめ": "<ユーザーが Step 3 で説明した、このドメインの 1 行サマリ>"
"出典": []
"エイリアス": []
---

# <ドメイン名>

このドメインで追跡している内容のホームページです。

## ページ

- [[<最初のページ>]] — <1 行サマリ>

## 出典

(まだなし)

## ログ

[[<ドメイン名>-log]]
```

## Template F.D — new wiki-index, LOCALE = en

```yaml
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

Home for everything tracked under this domain.

## Pages

- [[<first-page>]] — <one-line summary>

## Sources

(none yet)

## Log

[[<domain-name>-log]]
```

## Template F.E — new wiki-log (new-domain branch), LOCALE = ja

```yaml
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

## [YYYY-MM-DD] ingest | <最初のページのソースタイトル>
- Created: [[<最初のページ>]]
- Source: <url or raw/<source> or "from-scratch">

## [YYYY-MM-DD] init | <ドメイン名> セットアップ
- claude-wiki/add-page で新規ドメインとして作成
- ユーザーの意図: <Step 3 でユーザーが表現した目的の 1 行要約>
```

## Template F.F — new wiki-log, LOCALE = en

```yaml
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

## [YYYY-MM-DD] ingest | <first page source title>
- Created: [[<first-page>]]
- Source: <url or raw/<source> or "from-scratch">

## [YYYY-MM-DD] init | <domain-name> setup
- Created via claude-wiki/add-page as a new domain
- User-stated intent: <one-line paraphrase of the user's Step 3 description>
```
