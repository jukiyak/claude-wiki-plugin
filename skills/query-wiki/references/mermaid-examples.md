# Mermaid diagram examples for query-wiki

When a flow/relationship/timeline/visualization trigger fires in `query-wiki` Step 1.2, render a Mermaid block. Pick the diagram type that fits the question. The main SKILL.md links here from Step 3.3 — read this file when you need a concrete syntax pattern.

Mermaid syntax follows the Obsidian native renderer (Mermaid 10+). Each Mermaid block should be followed by a one-line `Sources: [[Page-1]] [[Page-2]] …` so provenance stays visible without the diagram having to encode it.

When unsure about the diagram type, default to `graph LR` for relationships or `flowchart TD` for processes.

## Concept relationships (`〜の関係`, `relationship between`)

````markdown
```mermaid
graph LR
  ストレス --> 睡眠不足
  睡眠不足 --> 頭痛
  カフェイン過剰 --> 睡眠不足
  カフェイン過剰 --> 頭痛
```
````

## Process flow (`〜の流れ`, `flow`, `flowchart`)

````markdown
```mermaid
flowchart TD
  A[ソース raw/ に配置] --> B[Claude が読む]
  B --> C[要点抽出 + ファクトチェック]
  C --> D[Batch Approval Plan 提示]
  D --> E{user 承認?}
  E -->|yes| F[page + index + log を一括書き出し]
  E -->|no| G[キャンセル]
```
````

## Timeline (`〜のタイムライン`, `timeline of`)

````markdown
```mermaid
timeline
  2026-04-29 : setup-claude-wiki shipped (dev.5)
  2026-04-30 : add-page shipped (dev.9) : lint-vault shipped (dev.10) : query-wiki shipped (dev.12)
```
````

## Mind map (organizing concepts under a root)

````markdown
```mermaid
mindmap
  root((健康))
    症状
      耳鳴り
      頭痛
    生活習慣
      睡眠不足
      カフェイン
      アルコール
    横断
      ストレス
```
````

## Pre-validate before emitting

Common mistakes that break Mermaid rendering:
- Reserved keywords as node names (`end`, `class`, `style`, `subgraph`) — rename or quote
- Missing arrow direction in `graph` declarations (use `LR`, `TD`, `BT`, `RL`)
- Special characters in node labels — wrap in `[Label]` brackets
- Unescaped quotes in labels — use `&quot;` or rephrase
