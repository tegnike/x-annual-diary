#!/bin/bash
# generate-review.sh
# Twitter年間振り返りレポート自動生成スクリプト
# Usage: ./generate-review.sh [--file tweets.js] [--year 2025]

# set -eはmain関数内で設定（テスト時のsource対応）

# =============================================================================
# 設定
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# デフォルト値
TWEETS_FILE="$SCRIPT_DIR/twitter-*/data/tweets.js"
YEAR="2025"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$SCRIPT_DIR/templates}"

# =============================================================================
# 引数パーサー
# =============================================================================
showUsage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -f, --file <path>   tweets.js file path (default: twitter-*/data/tweets.js)
  -y, --year <year>   Target year (default: 2025)
  -h, --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            TWEETS_FILE="$2"
            shift 2
            ;;
        -y|--year)
            YEAR="$2"
            shift 2
            ;;
        -h|--help)
            showUsage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            showUsage
            exit 1
            ;;
    esac
done

# =============================================================================
# テンプレート管理
# =============================================================================

# 月次レポートテンプレートを読み込む
loadMonthlyTemplate() {
    local template_file="$TEMPLATES_DIR/monthly-template.md"
    if [[ -f "$template_file" ]]; then
        cat "$template_file"
    else
        echo ""
    fi
}

# 週次プロンプトテンプレートを読み込む
loadWeeklyPromptTemplate() {
    local template_file="$TEMPLATES_DIR/weekly-prompt.md"
    if [[ -f "$template_file" ]]; then
        cat "$template_file"
    else
        echo ""
    fi
}

# 月次プロンプトテンプレートを読み込む
loadMonthlyPromptTemplate() {
    local template_file="$TEMPLATES_DIR/monthly-prompt.md"
    if [[ -f "$template_file" ]]; then
        cat "$template_file"
    else
        echo ""
    fi
}

# テンプレート変数を置換する
# 使用法: applyTemplate "$template" "VAR1=value1" "VAR2=value2"
applyTemplate() {
    local template="$1"
    shift
    local result="$template"

    for arg in "$@"; do
        local key="${arg%%=*}"
        local value="${arg#*=}"
        result="${result//\{\{$key\}\}/$value}"
    done

    echo "$result"
}

# =============================================================================
# ユーティリティ関数
# =============================================================================

# エラー終了
exitWithError() {
    echo "Error: $1" >&2
    exit 1
}

# 進捗表示
showProgress() {
    local month="$1"
    local week="$2"
    if [[ -n "$week" ]]; then
        echo "[Progress] Processing: ${YEAR}年${month}月 第${week}週"
    else
        echo "[Progress] Processing: ${YEAR}年${month}月"
    fi
}

# =============================================================================
# バリデーション関数
# =============================================================================

# 入力ファイル検証
validateInput() {
    # グロブパターンを展開
    local expanded_file
    expanded_file=$(echo $TWEETS_FILE)

    if [[ ! -f "$expanded_file" ]]; then
        exitWithError "tweets.js not found at $TWEETS_FILE"
    fi

    # 展開されたパスを設定
    TWEETS_FILE="$expanded_file"
    echo "[Info] Input file: $TWEETS_FILE"
}

# 依存ツール確認
validateDependencies() {
    if ! command -v jq &> /dev/null; then
        exitWithError "jq is not installed. Please install jq first."
    fi

    if ! command -v claude &> /dev/null; then
        exitWithError "claude CLI is not installed. Please install Claude Code first."
    fi

    echo "[Info] Dependencies check passed"
}

# =============================================================================
# ディレクトリ管理
# =============================================================================

# 出力ディレクトリ作成（年別構造）
ensureOutputDir() {
    # 年別ディレクトリ構造: output/YYYY/
    local year_dir="$OUTPUT_DIR/$YEAR"
    mkdir -p "$year_dir"
    mkdir -p "$year_dir/weekly-summaries"
    mkdir -p "$year_dir/logs"

    # YEAR_OUTPUT_DIRをグローバルに設定
    YEAR_OUTPUT_DIR="$year_dir"

    echo "[Info] Output directory: $YEAR_OUTPUT_DIR"
}

# =============================================================================
# 前年データ参照機能
# =============================================================================

# 前年の年間サマリーを読み込む
# 引数: 対象年
# 出力: 前年のサマリーテキスト（存在しない場合は空文字）
loadPreviousYearSummary() {
    local target_year="$1"
    local prev_year=$((target_year - 1))
    local prev_summary_file="$OUTPUT_DIR/$prev_year/annual-summary.md"

    if [[ -f "$prev_summary_file" ]]; then
        echo "[Info] Found previous year ($prev_year) summary" >&2
        cat "$prev_summary_file"
    else
        echo ""
    fi
}

# 前年の用語辞書を読み込む（継続利用）
# 引数: 対象年
# 出力: 前年の用語辞書JSON（存在しない場合は空オブジェクト）
loadPreviousYearGlossary() {
    local target_year="$1"
    local prev_year=$((target_year - 1))
    local prev_glossary_file="$OUTPUT_DIR/$prev_year/glossary.json"

    if [[ -f "$prev_glossary_file" ]]; then
        echo "[Info] Loading previous year ($prev_year) glossary" >&2
        cat "$prev_glossary_file"
    else
        echo "{}"
    fi
}

# =============================================================================
# 統計・ログ管理
# =============================================================================

# グローバル統計変数
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
TOTAL_CACHE_CREATION_TOKENS=0
TOTAL_CACHE_READ_TOKENS=0
TOTAL_COST_USD=0
TOTAL_API_DURATION_MS=0
CLAUDE_CALL_COUNT=0
START_TIME=0

# 統計の初期化
initStats() {
    START_TIME=$(date +%s)
    TOTAL_INPUT_TOKENS=0
    TOTAL_OUTPUT_TOKENS=0
    TOTAL_CACHE_CREATION_TOKENS=0
    TOTAL_CACHE_READ_TOKENS=0
    TOTAL_COST_USD=0
    TOTAL_API_DURATION_MS=0
    CLAUDE_CALL_COUNT=0
}

# 統計の更新（JSON結果から）
updateStats() {
    local json_result="$1"

    local input_tokens output_tokens cache_creation cache_read cost duration
    input_tokens=$(echo "$json_result" | jq -r '.usage.input_tokens // 0')
    output_tokens=$(echo "$json_result" | jq -r '.usage.output_tokens // 0')
    cache_creation=$(echo "$json_result" | jq -r '.usage.cache_creation_input_tokens // 0')
    cache_read=$(echo "$json_result" | jq -r '.usage.cache_read_input_tokens // 0')
    cost=$(echo "$json_result" | jq -r '.total_cost_usd // 0')
    duration=$(echo "$json_result" | jq -r '.duration_api_ms // 0')

    TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + input_tokens))
    TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + output_tokens))
    TOTAL_CACHE_CREATION_TOKENS=$((TOTAL_CACHE_CREATION_TOKENS + cache_creation))
    TOTAL_CACHE_READ_TOKENS=$((TOTAL_CACHE_READ_TOKENS + cache_read))
    TOTAL_COST_USD=$(echo "$TOTAL_COST_USD + $cost" | bc -l)
    TOTAL_API_DURATION_MS=$((TOTAL_API_DURATION_MS + duration))
    CLAUDE_CALL_COUNT=$((CLAUDE_CALL_COUNT + 1))
}

# ログをファイルに保存
saveLog() {
    local log_type="$1"
    local identifier="$2"
    local content="$3"
    local json_result="$4"

    local timestamp
    timestamp=$(date "+%Y%m%d_%H%M%S")
    local log_file="$YEAR_OUTPUT_DIR/logs/${timestamp}_${log_type}_${identifier}.json"

    # ログをJSON形式で保存
    jq -n \
        --arg type "$log_type" \
        --arg id "$identifier" \
        --arg timestamp "$(date -Iseconds)" \
        --arg content "$content" \
        --argjson result "$json_result" \
        '{
            type: $type,
            identifier: $id,
            timestamp: $timestamp,
            prompt_preview: ($content | split("\n")[0:5] | join("\n")),
            result: $result
        }' > "$log_file"

    echo "$log_file"
}

# ログファイルから統計を再計算
# サブシェルでの変数更新が親シェルに反映されないため、最終集計時にログから再計算
recalculateStatsFromLogs() {
    local logs_dir="$YEAR_OUTPUT_DIR/logs"

    # ログファイルが存在しない場合はスキップ
    if [[ ! -d "$logs_dir" ]]; then
        return
    fi

    # 全ログファイルから統計を集計（stats_summary.jsonを除外）
    # modelUsageから実際のトークン数を取得（キャッシュ使用時もinputTokensに正しい値が入る）
    local stats
    stats=$(find "$logs_dir" -name "*.json" -type f -not -name "stats_summary.json" -exec cat {} + 2>/dev/null | \
        jq -s 'map(select(.result) | .result) | {call_count: length, input_tokens: (map([.modelUsage[]?.inputTokens // 0] | add) | add), output_tokens: (map([.modelUsage[]?.outputTokens // 0] | add) | add), cache_creation: (map(.usage.cache_creation_input_tokens // 0) | add), cache_read: (map(.usage.cache_read_input_tokens // 0) | add), total_cost: (map(.total_cost_usd // 0) | add), api_duration_ms: (map(.duration_api_ms // 0) | add)}' 2>/dev/null)

    if [[ -n "$stats" && "$stats" != "null" ]]; then
        CLAUDE_CALL_COUNT=$(echo "$stats" | jq -r '.call_count // 0')
        TOTAL_INPUT_TOKENS=$(echo "$stats" | jq -r '.input_tokens // 0')
        TOTAL_OUTPUT_TOKENS=$(echo "$stats" | jq -r '.output_tokens // 0')
        TOTAL_CACHE_CREATION_TOKENS=$(echo "$stats" | jq -r '.cache_creation // 0')
        TOTAL_CACHE_READ_TOKENS=$(echo "$stats" | jq -r '.cache_read // 0')
        TOTAL_COST_USD=$(echo "$stats" | jq -r '.total_cost // 0')
        TOTAL_API_DURATION_MS=$(echo "$stats" | jq -r '.api_duration_ms // 0')
    fi
}

# 最終統計を出力・保存
saveStatsSummary() {
    # サブシェル問題を回避するため、ログから統計を再計算
    recalculateStatsFromLogs

    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))

    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))
    local formatted_duration
    formatted_duration=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)

    local api_duration_sec
    api_duration_sec=$(echo "scale=2; $TOTAL_API_DURATION_MS / 1000" | bc -l)

    local stats_file="$YEAR_OUTPUT_DIR/logs/stats_summary.json"

    jq -n \
        --arg start_time "$(date -r $START_TIME -Iseconds 2>/dev/null || date -d @$START_TIME -Iseconds)" \
        --arg end_time "$(date -Iseconds)" \
        --argjson total_duration "$total_duration" \
        --arg formatted_duration "$formatted_duration" \
        --argjson claude_calls "$CLAUDE_CALL_COUNT" \
        --argjson input_tokens "$TOTAL_INPUT_TOKENS" \
        --argjson output_tokens "$TOTAL_OUTPUT_TOKENS" \
        --argjson cache_creation "$TOTAL_CACHE_CREATION_TOKENS" \
        --argjson cache_read "$TOTAL_CACHE_READ_TOKENS" \
        --arg total_cost "$TOTAL_COST_USD" \
        --arg api_duration_sec "$api_duration_sec" \
        '{
            execution: {
                start_time: $start_time,
                end_time: $end_time,
                total_duration_seconds: $total_duration,
                formatted_duration: $formatted_duration
            },
            claude_api: {
                total_calls: $claude_calls,
                total_api_duration_seconds: ($api_duration_sec | tonumber)
            },
            tokens: {
                input: $input_tokens,
                output: $output_tokens,
                cache_creation: $cache_creation,
                cache_read: $cache_read,
                total: ($input_tokens + $output_tokens + $cache_creation + $cache_read)
            },
            cost: {
                total_usd: ($total_cost | tonumber),
                total_jpy_approx: (($total_cost | tonumber) * 150 | floor)
            }
        }' > "$stats_file"

    echo ""
    echo "=== 実行統計 ==="
    echo "総実行時間: $formatted_duration"
    echo "Claude API呼び出し回数: $CLAUDE_CALL_COUNT"
    echo "API処理時間合計: ${api_duration_sec}秒"
    echo ""
    echo "=== トークン使用量 ==="
    echo "入力トークン: $TOTAL_INPUT_TOKENS"
    echo "出力トークン: $TOTAL_OUTPUT_TOKENS"
    echo "キャッシュ作成: $TOTAL_CACHE_CREATION_TOKENS"
    echo "キャッシュ読み取り: $TOTAL_CACHE_READ_TOKENS"
    echo "合計トークン: $((TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS + TOTAL_CACHE_CREATION_TOKENS + TOTAL_CACHE_READ_TOKENS))"
    echo ""
    echo "=== コスト ==="
    printf "総コスト: \$%.4f (約%.0f円)\n" "$TOTAL_COST_USD" "$(echo "$TOTAL_COST_USD * 150" | bc -l)"
    echo ""
    echo "[Info] 詳細統計を保存: $stats_file"
}

# =============================================================================
# データパーサー（DataParser）
# =============================================================================

# tweets.jsを解析してJSON配列を返す
parseTwitterArchive() {
    local input_file="$1"
    # window.YTD.tweets.part0 = を除去してJSONパース
    sed 's/^window\.YTD\.tweets\.part0 = //' "$input_file"
}

# 指定年のツイートのみ抽出
filterByYear() {
    local year="$1"
    jq --arg year "$year" '[.[] | select(.tweet.created_at | contains($year))]'
}

# 月別にツイートを抽出
filterByMonth() {
    local month="$1"
    local month_names=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
    local month_name="${month_names[$month]}"
    jq --arg month "$month_name" '[.[] | select(.tweet.created_at | contains($month))]'
}

# 週番号を計算（ISO週番号、月曜始まり）
# Twitter形式: "Mon Dec 08 22:15:13 +0000 2025"
getWeekNumber() {
    local date_str="$1"
    # jqを使ってISO形式に変換し、週番号を計算
    # 月名を月番号に変換するマッピング
    local month_map="Jan:01 Feb:02 Mar:03 Apr:04 May:05 Jun:06 Jul:07 Aug:08 Sep:09 Oct:10 Nov:11 Dec:12"

    # 日付パーツを抽出: "Mon Dec 08 22:15:13 +0000 2025"
    local parts=($date_str)
    local month_name="${parts[1]}"
    local day="${parts[2]}"
    local year="${parts[5]}"

    # 月名を月番号に変換
    local month_num=""
    for mapping in $month_map; do
        local name="${mapping%:*}"
        local num="${mapping#*:}"
        if [[ "$month_name" == "$name" ]]; then
            month_num="$num"
            break
        fi
    done

    # ISO形式に変換: YYYY-MM-DD
    local iso_date="${year}-${month_num}-${day}"

    # macOS/Linux互換の週番号計算
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: ISO形式から週番号を計算
        date -j -f "%Y-%m-%d" "$iso_date" "+%V" 2>/dev/null || echo "01"
    else
        # Linux
        date -d "$iso_date" "+%V" 2>/dev/null || echo "01"
    fi
}

# ツイートを週別にグループ化
groupByWeek() {
    jq 'group_by(.tweet.created_at | split(" ") | .[0:3] | join(" ")) |
        map({
            week: (.[0].tweet.created_at),
            tweets: .
        })'
}

# 引用ツイートURLを抽出
extractQuotedUrls() {
    jq '[.tweet.entities.urls[]? | select(.expanded_url | test("(x\\.com|twitter\\.com)/[^/]+/status/")) | .expanded_url] // []'
}

# ツイートデータを整形して出力（引用ツイート対応版）
# 引数: 全ツイートJSON（引用元検索用）を標準入力で受け取る
# グローバル変数 ALL_TWEETS_JSON を参照して引用元を検索
formatTweetsForContext() {
    jq -r --argjson allTweets "${ALL_TWEETS_JSON:-[]}" '
        # 引用ツイートのステータスIDを抽出する関数
        def extract_status_id:
            capture("(?:x\\.com|twitter\\.com)/[^/]+/status/(?<id>[0-9]+)") | .id;

        # ステータスIDから該当ツイートを検索
        def find_tweet_by_id(id):
            $allTweets | map(select(.tweet.id_str == id or .tweet.id == id)) | first // null;

        .[] |
        .tweet as $tweet |

        # 引用ツイートURLを抽出
        ([$tweet.entities.urls[]? | select(.expanded_url | test("(x\\.com|twitter\\.com)/[^/]+/status/")) | .expanded_url] // []) as $quote_urls |

        # 基本情報
        "---\n日時: \($tweet.created_at)\n本文: \($tweet.full_text)" +

        # 引用ツイートがあれば追加
        if ($quote_urls | length) > 0 then
            ($quote_urls | map(
                . as $url |
                ($url | extract_status_id) as $status_id |
                (find_tweet_by_id($status_id)) as $quoted |
                if $quoted != null then
                    "\n\n  ┗ 引用ツイート:\n    日時: \($quoted.tweet.created_at)\n    本文: \($quoted.tweet.full_text | gsub("\n"; "\n    "))"
                else
                    "\n\n  ┗ 引用URL: \($url)"
                end
            ) | join(""))
        else
            ""
        end +
        "\n---"
    '
}

# =============================================================================
# 用語辞書管理（GlossaryManager）
# =============================================================================

# 辞書ファイルの読み込み
loadGlossary() {
    local glossary_file="$1"
    if [[ -f "$glossary_file" ]]; then
        cat "$glossary_file"
    else
        echo "{}"
    fi
}

# 辞書を保存
saveGlossary() {
    local glossary_file="$1"
    local glossary_json="$2"
    echo "$glossary_json" | jq '.' > "$glossary_file"
}

# 用語が既存か確認
hasTerm() {
    local glossary_json="$1"
    local term="$2"
    echo "$glossary_json" | jq -e --arg term "$term" 'has($term)' > /dev/null 2>&1
}

# 新規用語を追加
addTerm() {
    local glossary_json="$1"
    local term="$2"
    local definition="$3"
    echo "$glossary_json" | jq --arg term "$term" --arg def "$definition" '. + {($term): $def}'
}

# 週次サマリーMDから新規用語JSONを抽出
extractNewTermsFromSummary() {
    local md_content="$1"
    # "### 新規用語" セクションの ```json ... ``` を抽出
    echo "$md_content" | sed -n '/^### 新規用語/,/^```$/p' | sed -n '/^```json/,/^```$/p' | sed '1d;$d' | jq -c '.' 2>/dev/null || echo "{}"
}

# 既存glossaryに新規用語をマージ
mergeNewTerms() {
    local current_glossary="$1"
    local new_terms="$2"
    if [[ "$new_terms" == "{}" || -z "$new_terms" ]]; then
        echo "$current_glossary"
    else
        echo "$current_glossary $new_terms" | jq -s '.[0] * .[1]' 2>/dev/null || echo "$current_glossary"
    fi
}

# 用語調査失敗をログに記録
logFailedTerm() {
    local log_file="$1"
    local term="$2"
    local reason="$3"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] FAILED: term=\"$term\" reason=\"$reason\"" >> "$log_file"
}

# =============================================================================
# 週次処理（WeeklyProcessor）
# =============================================================================

# 月内の週番号リストを取得
# 引数: ツイートJSON配列, 月番号
# 出力: 週番号のリスト（スペース区切り）
getWeeksInMonth() {
    local tweets_json="$1"
    local month="$2"
    local month_names=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
    local month_name="${month_names[$month]}"

    # 当該月のツイートを抽出し、週番号を計算してユニークなリストを返す
    echo "$tweets_json" | jq -r --arg month "$month_name" '
        [.[] | select(.tweet.created_at | contains($month)) | .tweet.created_at] | unique | .[]
    ' | while read -r date_str; do
        getWeekNumber "$date_str"
    done | sort -n | uniq
}

# 指定週のツイートを取得
# 引数: ツイートJSON配列, 週番号
# 出力: 当該週のツイートJSON配列
getWeekTweets() {
    local tweets_json="$1"
    local target_week="$2"

    # 各ツイートの週番号を計算し、一致するものを抽出
    echo "$tweets_json" | jq -c '.[]' | while read -r tweet; do
        local date_str
        date_str=$(echo "$tweet" | jq -r '.tweet.created_at')
        local week_num
        week_num=$(getWeekNumber "$date_str")
        if [[ "$week_num" == "$target_week" ]]; then
            echo "$tweet"
        fi
    done | jq -s '.'
}

# Claude Code CLI実行
# 引数: プロンプト文字列, タイムアウト秒数, ログタイプ, 識別子
# 出力: 生成されたテキスト
# 副作用: 統計更新、ログ保存
invokeClaudeCode() {
    local prompt="$1"
    local timeout="${2:-300}"  # デフォルト5分
    local log_type="${3:-unknown}"
    local identifier="${4:-}"

    # Claude Code実行（JSON出力モード、Web検索ツール有効）
    local json_result
    if json_result=$(timeout "$timeout" claude -p --allowedTools "WebSearch" --output-format json <<< "$prompt" 2>/dev/null); then
        # 統計を更新
        updateStats "$json_result"

        # ログを保存
        if [[ -n "$identifier" ]]; then
            local log_file
            log_file=$(saveLog "$log_type" "$identifier" "$prompt" "$json_result")
            echo "[Info] Log saved: $log_file" >&2
        fi

        # テキスト結果を抽出して出力
        echo "$json_result" | jq -r '.result // ""'
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo "[Error] Claude Code execution timed out after ${timeout}s" >&2
        else
            echo "[Error] Claude Code execution failed with exit code $exit_code" >&2
        fi
        return 1
    fi
}

# Claude Code用コンテキスト構築
buildWeeklyContext() {
    local tweets="$1"
    local cumulative_summary="$2"
    local glossary="$3"
    local month="$4"
    local week_num="$5"

    # テンプレートファイルを読み込み
    local template
    template=$(loadWeeklyPromptTemplate)

    # テンプレートが存在しない場合はフォールバック
    if [[ -z "$template" ]]; then
        cat <<EOF
あなたはTwitterの週次振り返りレポートを生成するアシスタントです。

## 対象期間
${YEAR}年${month}月 第${week_num}週

## 今週のツイート
$tweets

## これまでの累積サマリー
$cumulative_summary

## 用語辞書
$glossary

## タスク
1. 今週のツイートを分析し、主要なトピックや活動を要約してください
2. 文脈理解に必要な未知の用語があれば、検索して定義を検索してください
3. Markdown形式で週次サマリーを出力してください

## 出力形式
### 週次サマリー（${YEAR}年${month}月 第${week_num}週）
- 主要トピック
- 活動内容
- 注目ツイート

### 新規用語（もしあれば）
{"用語": "定義"}
EOF
        return
    fi

    # テンプレート変数を置換
    local result="$template"
    result="${result//\{\{YEAR\}\}/$YEAR}"
    result="${result//\{\{MONTH\}\}/$month}"
    result="${result//\{\{WEEK\}\}/$week_num}"
    result="${result//\{\{TWEETS\}\}/$tweets}"
    result="${result//\{\{CUMULATIVE_SUMMARY\}\}/$cumulative_summary}"
    result="${result//\{\{GLOSSARY\}\}/$glossary}"

    echo "$result"
}

# 週次レポート生成（Claude Code実行）
processWeek() {
    local week_tweets="$1"
    local cumulative_summary="$2"
    local glossary="$3"
    local month="$4"
    local week_num="$5"

    local context
    context=$(buildWeeklyContext "$week_tweets" "$cumulative_summary" "$glossary" "$month" "$week_num")

    # Claude Code実行（非対話モード）
    local identifier="${YEAR}-M$(printf '%02d' $month)-W$(printf '%02d' $((10#$week_num)))"
    local result
    if result=$(invokeClaudeCode "$context" 300 "weekly" "$identifier"); then
        echo "$result"
    else
        echo "[Warning] Claude Code execution failed for week $week_num" >&2
        echo "## 週次サマリー（${YEAR}年${month}月 第${week_num}週）

処理中にエラーが発生しました。"
    fi
}

# 週次サマリーを保存
saveWeeklySummary() {
    local summary="$1"
    local year="$2"
    local week_num="$3"
    local output_file="$YEAR_OUTPUT_DIR/weekly-summaries/${year}-W$(printf '%02d' $((10#$week_num))).md"
    echo "$summary" > "$output_file"
    echo "[Info] Saved: $output_file"
}

# =============================================================================
# 月次処理（MonthlyAggregator）
# =============================================================================

# 月次レポートファイル名生成
getMonthlyFilename() {
    local year="$1"
    local month="$2"
    printf "%04d-%02d-review.md" "$year" "$month"
}

# 月の開始・終了週番号を取得
# 引数: 年, 月
# 出力: "開始週 終了週" の形式
getMonthWeekRange() {
    local year="$1"
    local month="$2"
    local month_padded
    month_padded=$(printf "%02d" "$month")

    # 月初日と月末日のISO週番号を計算
    local first_day="${year}-${month_padded}-01"
    local last_day

    # 月末日を計算
    if [[ "$month" -eq 12 ]]; then
        last_day="${year}-12-31"
    else
        local next_month=$((month + 1))
        local next_month_padded
        next_month_padded=$(printf "%02d" "$next_month")
        # 次月1日の前日 = 当月末日
        if [[ "$OSTYPE" == "darwin"* ]]; then
            last_day=$(date -j -v-1d -f "%Y-%m-%d" "${year}-${next_month_padded}-01" "+%Y-%m-%d" 2>/dev/null)
        else
            last_day=$(date -d "${year}-${next_month_padded}-01 -1 day" "+%Y-%m-%d" 2>/dev/null)
        fi
    fi

    local start_week end_week
    if [[ "$OSTYPE" == "darwin"* ]]; then
        start_week=$(date -j -f "%Y-%m-%d" "$first_day" "+%V" 2>/dev/null || echo "01")
        end_week=$(date -j -f "%Y-%m-%d" "$last_day" "+%V" 2>/dev/null || echo "52")
    else
        start_week=$(date -d "$first_day" "+%V" 2>/dev/null || echo "01")
        end_week=$(date -d "$last_day" "+%V" 2>/dev/null || echo "52")
    fi

    # 週番号から先頭の0を除去
    start_week=$((10#$start_week))
    end_week=$((10#$end_week))

    echo "$start_week $end_week"
}

# 当該月の週次サマリー読み込み（時系列順）
# 引数: 年, 月
# 出力: 当該月に属する週次サマリーの結合テキスト
loadWeeklySummariesForMonth() {
    local year="$1"
    local month="$2"
    local summaries=""

    # 月の週範囲を取得
    local week_range
    week_range=$(getMonthWeekRange "$year" "$month")
    local start_week end_week
    read -r start_week end_week <<< "$week_range"

    # 年末年始の週番号のラップアラウンド対応
    # 1月で start_week > end_week の場合（例: 52〜2）
    if [[ "$month" -eq 1 && "$start_week" -gt "$end_week" ]]; then
        # 前年の最後の週（52または53）から開始
        start_week=1
    fi
    # 12月で start_week > end_week の場合
    if [[ "$month" -eq 12 && "$start_week" -gt "$end_week" ]]; then
        end_week=53
    fi

    # 週番号順にソートしてファイルを読み込む
    for week_num in $(seq "$start_week" "$end_week"); do
        local week_padded
        week_padded=$(printf "%02d" "$((10#$week_num))")
        local file="$YEAR_OUTPUT_DIR/weekly-summaries/${year}-W${week_padded}.md"

        if [[ -f "$file" ]]; then
            summaries+="$(cat "$file")\n\n"
        fi
    done

    echo -e "$summaries"
}

# 当該月の週次サマリー読み込み（後方互換性のため残す）
loadWeeklySummaries() {
    local year="$1"
    local month="$2"
    local summaries=""

    for file in "$YEAR_OUTPUT_DIR/weekly-summaries/${year}-W"*.md; do
        if [[ -f "$file" ]]; then
            summaries+="$(cat "$file")\n\n"
        fi
    done

    echo -e "$summaries"
}

# 過去月の月次レポートを読み込み（累積文脈用）
# 引数: 年, 対象月（この月より前の月を読み込む）
# 出力: 過去月のサマリーを結合したテキスト
loadPreviousMonthlySummaries() {
    local year="$1"
    local target_month="$2"
    local summaries=""

    # 1月から対象月の前月まで読み込む
    for prev_month in $(seq 1 $((target_month - 1))); do
        local filename
        filename=$(getMonthlyFilename "$year" "$prev_month")
        local filepath="$YEAR_OUTPUT_DIR/$filename"

        if [[ -f "$filepath" ]]; then
            summaries+="## ${prev_month}月のサマリー\n"
            summaries+="$(cat "$filepath")\n\n"
        fi
    done

    echo -e "$summaries"
}

# 月次レポート用コンテキスト構築
# 引数: 月, 週次サマリー, 過去月サマリー
# 出力: Claude Code用プロンプト
buildMonthlyContext() {
    local month="$1"
    local weekly_summaries="$2"
    local previous_summaries="$3"

    # テンプレートファイルを読み込み
    local template
    template=$(loadMonthlyPromptTemplate)

    # テンプレートが存在しない場合はフォールバック
    if [[ -z "$template" ]]; then
        local prev_context=""
        if [[ -n "$previous_summaries" && "$previous_summaries" != "" ]]; then
            prev_context="## 過去月のサマリー（累積文脈）
$previous_summaries

過去月との関連性も考慮して、継続的なトピックや変化を分析してください。"
        fi

        cat <<EOF
あなたはTwitterの月次振り返りレポートを生成するアシスタントです。

## 対象期間
${YEAR}年${month}月

## 週次サマリー
$weekly_summaries

$prev_context

## タスク
週次サマリーを統合し、月次レポートを生成してください。

## 出力形式（Markdown）
# ${YEAR}年${month}月 振り返りレポート

## 今月のハイライト
- 今月最も重要なトピックや出来事を3〜5つ

## 主要トピック
- 今月議論された主要なテーマやトピック

## 活動サマリー
今月の活動内容を文章で要約

## 注目ツイート
- 特に印象的または重要なツイートを抜粋
EOF
        return
    fi

    # テンプレート変数を置換
    local result="$template"
    result="${result//\{\{YEAR\}\}/$YEAR}"
    result="${result//\{\{MONTH\}\}/$month}"
    result="${result//\{\{WEEKLY_SUMMARIES\}\}/$weekly_summaries}"
    result="${result//\{\{PREVIOUS_SUMMARIES\}\}/$previous_summaries}"

    echo "$result"
}

# 月次レポート生成
# 引数: 月番号, 過去月サマリー（オプション、後方互換用）
# 出力: 生成された月次レポート（Markdown）
aggregateMonth() {
    local month="$1"
    local previous_summaries="$2"

    # 新しい関数を使用して週次サマリーを読み込む（月別フィルタリング）
    local weekly_summaries
    weekly_summaries=$(loadWeeklySummariesForMonth "$YEAR" "$month")

    # 過去月のサマリーが渡されていない場合は自動取得
    if [[ -z "$previous_summaries" && "$month" -gt 1 ]]; then
        previous_summaries=$(loadPreviousMonthlySummaries "$YEAR" "$month")
    fi

    # コンテキスト構築（新しい関数を使用）
    local context
    context=$(buildMonthlyContext "$month" "$weekly_summaries" "$previous_summaries")

    # Claude Code実行（非対話モード）
    local identifier="${YEAR}-M$(printf '%02d' $month)"
    local result
    if result=$(invokeClaudeCode "$context" 300 "monthly" "$identifier"); then
        echo "$result"
    else
        echo "[Warning] Monthly report generation failed for month $month" >&2
        cat <<EOF
# ${YEAR}年${month}月 振り返りレポート

処理中にエラーが発生しました。

## 週次サマリー
$weekly_summaries
EOF
    fi
}

# =============================================================================
# 年間サマリー生成
# =============================================================================

generateAnnualSummary() {
    local cumulative_summary="$1"

    # 前年サマリーの抽出（cumulative_summaryに含まれている場合）
    local prev_year_context=""
    if [[ "$cumulative_summary" == *"前年（"* ]]; then
        prev_year_context="
## 前年との比較分析
前年のサマリーが提供されている場合は、以下の観点で比較分析を行ってください：
- 継続しているテーマ・関心事
- 新しく始めたこと
- 終了または減少したこと
- 成長・変化の軌跡"
    fi

    local context
    context=$(cat <<EOF
あなたはTwitterの年間振り返りレポートを生成するアシスタントです。
ツイート内容を詳細に分析し、**できるだけ具体的で詳細な**年間サマリーを生成してください。

## 対象年
${YEAR}年

## 月次サマリー（累積）
$cumulative_summary

## タスク
1年間の活動を総括し、年間サマリーを生成してください。
**抽象的な表現ではなく、具体的な内容・数値・固有名詞を積極的に含めてください。**

## 出力形式（Markdown）

# ${YEAR}年 Twitter年間振り返り

## 年間ハイライト TOP5
今年最も重要または印象的だった出来事を5つ、具体的なエピソードと共に記載してください。
- **[トピック名]**: 具体的な内容（いつ、何を、どうした）
- ...

## 月別トピック一覧
各月の主要トピックを具体的に記載してください（単語だけでなく、文章で）。
| 月 | 主要トピック | 特筆事項 |
|---|---|---|
| 1月 | ... | ... |
| 2月 | ... | ... |
（12月まで続く）

## カテゴリ別分析

### 技術・開発
- 取り組んだ技術やプロジェクトを具体的に
- 学んだこと、作ったもの

### 趣味・娯楽
- ゲーム、アニメ、映画、読書など
- 具体的なタイトルや感想

### 生活・日常
- 印象的な出来事や変化

### 考え・意見
- 発信した考えや意見のまとめ

## 年間を通じた傾向・パターン
- 投稿頻度の変化
- 関心の移り変わり
- 繰り返し登場するテーマ
${prev_year_context}

## 数字で見る1年
- 推定投稿傾向（活発だった月、静かだった月）
- よく言及されたキーワードや人物
- 特徴的な表現パターン

## 総括
${YEAR}年を一言で表すとしたら何か、そしてその理由を具体的に説明してください。

## 注意事項
- 出力はMarkdownのレポート本文のみとしてください
- 挨拶や締めの言葉は含めないでください
- 「〜と思われます」「〜かもしれません」などの曖昧な表現は避け、具体的に記述してください
- 月次サマリーに記載されている固有名詞や具体的なエピソードを積極的に引用してください
- **重要**: 出力はMarkdownのレポート本文のみとしてください。挨拶、自己紹介、補足説明、締めの言葉などの余計な発話は一切含めないでください
EOF
)

    local summary
    if summary=$(invokeClaudeCode "$context" 600 "annual" "${YEAR}-annual"); then
        echo "$summary" > "$YEAR_OUTPUT_DIR/annual-summary.md"
    else
        echo "# ${YEAR}年 Twitter年間振り返り

処理中にエラーが発生しました。" > "$YEAR_OUTPUT_DIR/annual-summary.md"
    fi
    echo "[Info] Saved: $YEAR_OUTPUT_DIR/annual-summary.md"
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    set -e  # main関数内でエラー時に終了を有効化

    echo "========================================"
    echo "Twitter Annual Review Generator"
    echo "========================================"

    # バリデーション
    validateInput
    validateDependencies
    ensureOutputDir

    # 統計の初期化
    initStats

    # tweets.js解析
    echo "[Info] Parsing tweets.js..."
    local tweets_json
    tweets_json=$(parseTwitterArchive "$TWEETS_FILE")

    local filtered_tweets
    filtered_tweets=$(echo "$tweets_json" | filterByYear "$YEAR")

    local tweet_count
    tweet_count=$(echo "$filtered_tweets" | jq 'length')
    echo "[Info] Found $tweet_count tweets for year $YEAR"

    # 引用ツイート検索用にグローバル変数として設定
    ALL_TWEETS_JSON="$tweets_json"
    export ALL_TWEETS_JSON

    if [[ "$tweet_count" -eq 0 ]]; then
        echo "[Warning] No tweets found for year $YEAR"
        exit 0
    fi

    # 前年データの読み込み
    local prev_year_summary
    prev_year_summary=$(loadPreviousYearSummary "$YEAR")

    # 辞書初期化（前年の辞書を継承）
    local glossary
    local prev_glossary
    prev_glossary=$(loadPreviousYearGlossary "$YEAR")
    local current_glossary
    current_glossary=$(loadGlossary "$YEAR_OUTPUT_DIR/glossary.json")

    # 前年辞書と当年辞書をマージ（当年の定義を優先）
    if [[ "$prev_glossary" != "{}" ]]; then
        glossary=$(echo "$prev_glossary $current_glossary" | jq -s '.[0] * .[1]')
        echo "[Info] Merged glossary from previous year"
    else
        glossary="$current_glossary"
    fi

    # 累積サマリー（前年サマリーがあれば初期コンテキストとして使用）
    local cumulative_summary=""
    if [[ -n "$prev_year_summary" ]]; then
        local prev_year=$((YEAR - 1))
        cumulative_summary="## 前年（${prev_year}年）の振り返り\n${prev_year_summary}\n\n"
        echo "[Info] Previous year summary loaded as initial context"
    fi

    # 月ループ（1〜12月）
    for month in {1..12}; do
        showProgress "$month"

        # 当該月のツイート抽出
        local month_tweets
        month_tweets=$(echo "$filtered_tweets" | filterByMonth "$month")

        local month_tweet_count
        month_tweet_count=$(echo "$month_tweets" | jq 'length')

        if [[ "$month_tweet_count" -eq 0 ]]; then
            echo "[Info] No tweets for month $month, skipping..."
            continue
        fi

        echo "[Info] Processing $month_tweet_count tweets for month $month"

        # 週単位処理
        local weeks_in_month
        weeks_in_month=$(getWeeksInMonth "$filtered_tweets" "$month")

        if [[ -z "$weeks_in_month" ]]; then
            # 週番号が取得できない場合は月全体を1つとして処理
            local week_num=1
            showProgress "$month" "$week_num"

            local formatted_tweets
            formatted_tweets=$(echo "$month_tweets" | formatTweetsForContext)

            local week_summary
            week_summary=$(processWeek "$formatted_tweets" "$cumulative_summary" "$glossary" "$month" "$week_num")

            saveWeeklySummary "$week_summary" "$YEAR" "$((month * 4 + week_num))"

            # 新規用語をglossaryに追加
            local new_terms
            new_terms=$(extractNewTermsFromSummary "$week_summary")
            glossary=$(mergeNewTerms "$glossary" "$new_terms")
        else
            # 各週を個別に処理
            local week_counter=1
            for week_num in $weeks_in_month; do
                showProgress "$month" "$week_counter"

                local week_tweets
                week_tweets=$(getWeekTweets "$month_tweets" "$week_num")

                local week_tweet_count
                week_tweet_count=$(echo "$week_tweets" | jq 'length')

                if [[ "$week_tweet_count" -eq 0 || "$week_tweets" == "[]" ]]; then
                    echo "[Info] No tweets for week $week_num, skipping..."
                    ((week_counter++))
                    continue
                fi

                echo "[Info] Processing $week_tweet_count tweets for week $week_num"

                local formatted_tweets
                formatted_tweets=$(echo "$week_tweets" | formatTweetsForContext)

                local week_summary
                week_summary=$(processWeek "$formatted_tweets" "$cumulative_summary" "$glossary" "$month" "$week_counter")

                saveWeeklySummary "$week_summary" "$YEAR" "$week_num"

                # 新規用語をglossaryに追加
                local new_terms
                new_terms=$(extractNewTermsFromSummary "$week_summary")
                glossary=$(mergeNewTerms "$glossary" "$new_terms")

                ((week_counter++))
            done
        fi

        # 月次レポート生成
        local monthly_report
        monthly_report=$(aggregateMonth "$month" "$cumulative_summary")

        local monthly_filename
        monthly_filename=$(getMonthlyFilename "$YEAR" "$month")
        echo "$monthly_report" > "$YEAR_OUTPUT_DIR/$monthly_filename"
        echo "[Info] Saved: $YEAR_OUTPUT_DIR/$monthly_filename"

        # 累積サマリー更新
        cumulative_summary="${cumulative_summary}\n## ${month}月\n${monthly_report}\n"
    done

    # 年間サマリー生成
    echo "[Info] Generating annual summary..."
    generateAnnualSummary "$cumulative_summary"

    # 辞書保存
    saveGlossary "$YEAR_OUTPUT_DIR/glossary.json" "$glossary"

    # 統計情報の収集と表示
    local monthly_reports_count
    monthly_reports_count=$(ls -1 "$YEAR_OUTPUT_DIR"/*-review.md 2>/dev/null | wc -l | tr -d ' ')
    local weekly_summaries_count
    weekly_summaries_count=$(ls -1 "$YEAR_OUTPUT_DIR/weekly-summaries"/*.md 2>/dev/null | wc -l | tr -d ' ')
    local glossary_terms_count
    glossary_terms_count=$(jq 'length' "$YEAR_OUTPUT_DIR/glossary.json" 2>/dev/null || echo "0")

    echo "========================================"
    echo "[Complete] All reports generated in $YEAR_OUTPUT_DIR"
    echo "========================================"
    echo ""
    echo "=== 処理統計 ==="
    echo "対象年: ${YEAR}年"
    echo "処理ツイート数: $tweet_count"
    echo "月次レポート数: $monthly_reports_count"
    echo "週次サマリー数: $weekly_summaries_count"
    echo "用語辞書登録数: $glossary_terms_count"

    # トークン・コスト・時間の統計を出力・保存
    saveStatsSummary

    echo "========================================"
}

# スクリプト直接実行時のみmain実行（テスト時はソースとしてインポート可能）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
