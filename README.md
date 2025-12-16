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
| `-h, --help` | ヘルプを表示 | - |

### 実行例

```bash
# デフォルト設定で実行
./generate-review.sh

# ファイルと年を指定
./generate-review.sh --file ./my-archive/tweets.js --year 2024
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
    ├── weekly-summaries/      # 週次サマリー
    │   └── {YEAR}-W{XX}.md
    ├── {YEAR}-{MM}-review.md  # 月次レポート
    ├── annual-summary.md      # 年間サマリー
    ├── glossary.json          # 用語辞書
    └── logs/                  # 実行ログ・統計
        └── stats_summary.json
```

## 機能

- **累積コンテキスト**: 過去の週・月のサマリーを参照しながら分析
- **前年データ参照**: 前年のサマリー・用語辞書を継承
- **統計収集**: トークン使用量・コスト・実行時間を記録
- **テンプレート対応**: `templates/`配下のテンプレートでプロンプトをカスタマイズ可能
