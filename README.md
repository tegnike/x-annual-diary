# x-annual-diary

Twitter（X）のアーカイブデータから年間振り返りレポートを自動生成するツールです。

## 必要な環境

- **jq**: JSONパーサー
- **Claude Code CLI**: AI処理に使用

## 使い方

```bash
./generate-review.sh [options]
```

### オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `-f, --file <path>` | tweets.jsファイルのパス | `twitter-*/data/tweets.js` |
| `-y, --year <year>` | 対象年 | `2025` |
| `-m, --month <month>` | 対象月（1-12） | 全月処理 |
| `-g, --granularity <type>` | 処理粒度（`weekly` / `daily`） | `weekly` |
| `-a, --annual-only` | 既存の月次レポートから年次サマリーのみ生成 | - |
| `-i, --image` | 添付画像をサブエージェントで解析し、説明をツイート情報に追加 | 無効 |
| `-h, --help` | ヘルプを表示 | - |

### 実行例

```bash
# デフォルト設定で実行（週単位・全月）
./generate-review.sh

# ファイルと年を指定
./generate-review.sh --file ./my-archive/tweets.js --year 2024

# 特定の月のみ処理
./generate-review.sh -y 2024 -m 6

# 日単位で詳細分析
./generate-review.sh -g daily -m 12

# 画像解析を有効化（画像内容をテキスト化してツイート情報に追加）
./generate-review.sh -y 2024 -m 12 --image

# 既存の月次レポートから年次サマリーのみ再生成
./generate-review.sh -y 2024 --annual-only
```

## 処理の流れ

1. **入力解析**: `tweets.js`を読み込み、指定年のツイートを抽出
2. **週次処理**: 月ごとに週単位でツイートを分析し、週次サマリーを生成
3. **月次処理**: 週次サマリーを統合し、月次レポートを生成
4. **年間処理**: 全月のレポートから年間サマリーを生成
5. **用語管理**: 未知の用語をWeb検索し、用語辞書を更新

## 出力構造

```
output/
└── {YEAR}/
    ├── weekly-summaries/      # 週次サマリー（-g weekly時）
    │   └── {YEAR}-W{XX}.md
    ├── daily-summaries/       # 日次サマリー（-g daily時）
    │   └── {YYYY}-{MM}-{DD}.md
    ├── {YEAR}-{MM}-review.md  # 月次レポート
    ├── annual-summary.md      # 年間サマリー
    ├── glossary.json          # 用語辞書
    ├── image-cache.json       # 画像解析キャッシュ（-i使用時）
    └── logs/                  # 実行ログ・統計
        └── stats_summary.json
```

## 機能

- **引用ツイート対応**: 引用元ツイートを自動検索し、セットで表示
- **画像解析**: 添付画像をサブエージェントで解析し、説明をツイート情報に追加（引用ツイートの画像も対象、キャッシュ対応）
- **粒度選択**: 週単位/日単位で処理粒度を選択可能
- **月指定**: 特定の月のみを処理可能（年間サマリーはスキップ）
- **年次サマリー単独生成**: 既存の月次レポートから年次サマリーのみ再生成可能
- **累積コンテキスト**: 過去の週・月のサマリーを参照しながら分析
- **前年データ参照**: 前年のサマリー・用語辞書を継承
- **統計収集**: トークン使用量・コスト・実行時間を記録
- **テンプレート対応**: `templates/`配下のテンプレートでプロンプトをカスタマイズ可能
