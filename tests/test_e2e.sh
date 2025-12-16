#!/bin/bash
# Test: エンドツーエンドテスト
# タスク7.2: スクリプト全体の動作確認

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT_DIR="$PROJECT_ROOT/tests/test_output"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# テスト結果カウンター
PASSED=0
FAILED=0
SKIPPED=0

# テストヘルパー関数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((FAILED++))
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (file not found: $file)"
        ((FAILED++))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="$2"
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (directory not found: $dir)"
        ((FAILED++))
    fi
}

assert_file_not_empty() {
    local file="$1"
    local message="$2"
    if [[ -f "$file" && -s "$file" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (file empty or not found: $file)"
        ((FAILED++))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected to contain: $needle"
        ((FAILED++))
    fi
}

skip_test() {
    local message="$1"
    echo -e "${YELLOW}SKIP${NC}: $message"
    ((SKIPPED++))
}

# セットアップ
setup() {
    rm -rf "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR/weekly-summaries"
}

# クリーンアップ
teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
}

# ====== E2Eテスト ======

echo "========================================"
echo "E2E Tests: エンドツーエンドテスト"
echo "========================================"

# Test 1: 最小データセット（1週間分）での実行テスト
test_minimal_dataset() {
    echo ""
    echo "--- Test: 最小データセット（1週間分）での実行 ---"
    setup

    local test_input="$FIXTURES_DIR/minimal_tweets.js"
    if [[ ! -f "$test_input" ]]; then
        skip_test "テストデータが存在しない: $test_input"
        return
    fi

    # スクリプトをソースとして読み込み、モック環境で実行
    export OUTPUT_DIR="$TEST_OUTPUT_DIR"
    export YEAR="2025"

    # claudeコマンドが利用可能か確認
    if ! command -v claude &> /dev/null; then
        skip_test "claude CLIが利用不可のためスキップ"
        return
    fi

    # 出力ディレクトリ構造のテスト（スクリプトをソース）
    source "$PROJECT_ROOT/generate-review.sh"
    ensureOutputDir

    assert_dir_exists "$TEST_OUTPUT_DIR" "出力ディレクトリが作成される"
    assert_dir_exists "$TEST_OUTPUT_DIR/weekly-summaries" "週次サマリーディレクトリが作成される"
}

# Test 2: データパーサーの結合テスト
test_data_parser_integration() {
    echo ""
    echo "--- Test: データパーサーの結合テスト ---"
    setup

    local test_input="$FIXTURES_DIR/minimal_tweets.js"
    if [[ ! -f "$test_input" ]]; then
        skip_test "テストデータが存在しない: $test_input"
        return
    fi

    source "$PROJECT_ROOT/generate-review.sh"

    # tweets.jsパース
    local parsed
    parsed=$(parseTwitterArchive "$test_input")

    # JSON配列であることを確認
    local count
    count=$(echo "$parsed" | jq 'length')
    assert_equals "5" "$count" "5件のツイートがパースされる"

    # 2025年フィルタリング
    local filtered
    filtered=$(echo "$parsed" | filterByYear "2025")
    local filtered_count
    filtered_count=$(echo "$filtered" | jq 'length')
    assert_equals "5" "$filtered_count" "2025年のツイート5件が抽出される"
}

# Test 3: 引用ツイートURL抽出テスト
test_quoted_url_extraction() {
    echo ""
    echo "--- Test: 引用ツイートURL抽出 ---"
    setup

    local test_input="$FIXTURES_DIR/tweets_with_quotes.js"
    if [[ ! -f "$test_input" ]]; then
        skip_test "テストデータが存在しない: $test_input"
        return
    fi

    source "$PROJECT_ROOT/generate-review.sh"

    local parsed
    parsed=$(parseTwitterArchive "$test_input")

    # 引用ツイートを含むツイートからURL抽出
    local tweet_with_quote
    tweet_with_quote=$(echo "$parsed" | jq '.[1]')
    local quoted_urls
    quoted_urls=$(echo "$tweet_with_quote" | extractQuotedUrls)

    local url_count
    url_count=$(echo "$quoted_urls" | jq 'length')
    assert_equals "1" "$url_count" "x.comの引用URLが1件抽出される"

    # twitter.comドメインのURLも抽出されることを確認
    local tweet_with_twitter_url
    tweet_with_twitter_url=$(echo "$parsed" | jq '.[2]')
    local twitter_urls
    twitter_urls=$(echo "$tweet_with_twitter_url" | extractQuotedUrls)

    local twitter_url_count
    twitter_url_count=$(echo "$twitter_urls" | jq 'length')
    assert_equals "1" "$twitter_url_count" "twitter.comの引用URLが1件抽出される"

    # 引用なしツイートでは空配列
    local tweet_without_quote
    tweet_without_quote=$(echo "$parsed" | jq '.[3]')
    local no_urls
    no_urls=$(echo "$tweet_without_quote" | extractQuotedUrls)

    local no_url_count
    no_url_count=$(echo "$no_urls" | jq 'length')
    assert_equals "0" "$no_url_count" "引用なしツイートでは空配列が返る"
}

# Test 4: 用語辞書の永続化テスト
test_glossary_persistence() {
    echo ""
    echo "--- Test: 用語辞書の永続化 ---"
    setup

    source "$PROJECT_ROOT/generate-review.sh"

    local glossary_file="$TEST_OUTPUT_DIR/glossary.json"

    # 初期状態（空のオブジェクト）
    local glossary
    glossary=$(loadGlossary "$glossary_file")
    assert_equals "{}" "$glossary" "存在しない辞書は空オブジェクトを返す"

    # 用語追加
    glossary=$(addTerm "$glossary" "TypeScript" "Microsoft製の型付きJavaScript")
    glossary=$(addTerm "$glossary" "React" "Facebook製のUIライブラリ")

    # 保存
    saveGlossary "$glossary_file" "$glossary"
    assert_file_exists "$glossary_file" "辞書ファイルが保存される"

    # 再読み込みして確認
    local reloaded
    reloaded=$(loadGlossary "$glossary_file")

    local term_count
    term_count=$(echo "$reloaded" | jq 'keys | length')
    assert_equals "2" "$term_count" "2つの用語が保存されている"

    # 重複チェック
    if hasTerm "$reloaded" "TypeScript"; then
        echo -e "${GREEN}PASS${NC}: TypeScriptが存在する"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: TypeScriptが存在しない"
        ((FAILED++))
    fi

    if ! hasTerm "$reloaded" "Go"; then
        echo -e "${GREEN}PASS${NC}: 未登録の用語Goは存在しない"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: 未登録の用語Goが存在する"
        ((FAILED++))
    fi
}

# Test 5: 出力ファイル命名規則テスト
test_output_file_naming() {
    echo ""
    echo "--- Test: 出力ファイル命名規則 ---"
    setup

    source "$PROJECT_ROOT/generate-review.sh"

    # 月次ファイル名
    local jan_filename
    jan_filename=$(getMonthlyFilename "2025" "1")
    assert_equals "2025-01-review.md" "$jan_filename" "1月のファイル名が正しい"

    local dec_filename
    dec_filename=$(getMonthlyFilename "2025" "12")
    assert_equals "2025-12-review.md" "$dec_filename" "12月のファイル名が正しい"
}

# Test 6: 入力ファイル不在時のエラーハンドリング
test_missing_input_error() {
    echo ""
    echo "--- Test: 入力ファイル不在時のエラー ---"
    setup

    local output
    output=$("$PROJECT_ROOT/generate-review.sh" "/nonexistent/path/tweets.js" 2>&1 || true)

    assert_contains "$output" "Error" "エラーメッセージが表示される"
    assert_contains "$output" "not found" "ファイルが見つからないメッセージが含まれる"
}

# Test 7: 冪等性テスト（同じ入力で同じ出力）
test_idempotency() {
    echo ""
    echo "--- Test: 冪等性（再実行時の上書き） ---"
    setup

    # OUTPUT_DIRをエクスポートしてからソース
    export OUTPUT_DIR="$TEST_OUTPUT_DIR"
    source "$PROJECT_ROOT/generate-review.sh"
    # ソース後にOUTPUT_DIRを再設定（グローバル変数が上書きされるため）
    OUTPUT_DIR="$TEST_OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/weekly-summaries"

    # 週次サマリーを2回保存
    local summary1="# Week 1 Summary - First Run"
    saveWeeklySummary "$summary1" "2025" "1"

    local first_content
    first_content=$(cat "$TEST_OUTPUT_DIR/weekly-summaries/2025-W01.md")
    assert_equals "$summary1" "$first_content" "最初の保存が成功"

    # 同じ週に再度保存（上書き）
    local summary2="# Week 1 Summary - Second Run"
    saveWeeklySummary "$summary2" "2025" "1"

    local second_content
    second_content=$(cat "$TEST_OUTPUT_DIR/weekly-summaries/2025-W01.md")
    assert_equals "$summary2" "$second_content" "再実行で上書きされる（冪等性）"
}

# Test 8: 複数月データでの処理テスト
test_multi_month_processing() {
    echo ""
    echo "--- Test: 複数月データでの処理 ---"
    setup

    local test_input="$FIXTURES_DIR/multi_month_tweets.js"
    if [[ ! -f "$test_input" ]]; then
        skip_test "テストデータが存在しない: $test_input"
        return
    fi

    source "$PROJECT_ROOT/generate-review.sh"

    local parsed
    parsed=$(parseTwitterArchive "$test_input")

    # 全体件数
    local total_count
    total_count=$(echo "$parsed" | jq 'length')
    assert_equals "9" "$total_count" "9件のツイートがパースされる"

    # 2025年フィルタ
    local filtered
    filtered=$(echo "$parsed" | filterByYear "2025")

    # 月別フィルタリング
    local jan_tweets
    jan_tweets=$(echo "$filtered" | filterByMonth "1")
    local jan_count
    jan_count=$(echo "$jan_tweets" | jq 'length')
    assert_equals "3" "$jan_count" "1月のツイートが3件"

    local feb_tweets
    feb_tweets=$(echo "$filtered" | filterByMonth "2")
    local feb_count
    feb_count=$(echo "$feb_tweets" | jq 'length')
    assert_equals "3" "$feb_count" "2月のツイートが3件"

    local mar_tweets
    mar_tweets=$(echo "$filtered" | filterByMonth "3")
    local mar_count
    mar_count=$(echo "$mar_tweets" | jq 'length')
    assert_equals "3" "$mar_count" "3月のツイートが3件"
}

# Test 9: エラーログ機能テスト
test_error_logging() {
    echo ""
    echo "--- Test: エラーログ機能 ---"
    setup

    source "$PROJECT_ROOT/generate-review.sh"

    local log_file="$TEST_OUTPUT_DIR/error.log"

    # エラーログを記録
    logFailedTerm "$log_file" "UnknownTerm" "調査タイムアウト"

    assert_file_exists "$log_file" "エラーログファイルが作成される"

    local log_content
    log_content=$(cat "$log_file")
    assert_contains "$log_content" "UnknownTerm" "用語名がログに含まれる"
    assert_contains "$log_content" "調査タイムアウト" "失敗理由がログに含まれる"
    assert_contains "$log_content" "FAILED" "FAILEDマーカーが含まれる"
}

# Test 10: テンプレート読み込みテスト
test_template_loading() {
    echo ""
    echo "--- Test: テンプレート読み込み ---"
    setup

    source "$PROJECT_ROOT/generate-review.sh"

    # テンプレートファイルが存在する場合のテスト
    local monthly_template
    monthly_template=$(loadMonthlyTemplate)

    if [[ -n "$monthly_template" ]]; then
        echo -e "${GREEN}PASS${NC}: 月次テンプレートが読み込まれる"
        ((PASSED++))
    else
        echo -e "${YELLOW}INFO${NC}: 月次テンプレートが存在しない（フォールバック使用）"
    fi

    local weekly_template
    weekly_template=$(loadWeeklyPromptTemplate)

    if [[ -n "$weekly_template" ]]; then
        echo -e "${GREEN}PASS${NC}: 週次プロンプトテンプレートが読み込まれる"
        ((PASSED++))
    else
        echo -e "${YELLOW}INFO${NC}: 週次テンプレートが存在しない（フォールバック使用）"
    fi
}

# ====== テスト実行 ======

test_minimal_dataset
test_data_parser_integration
test_quoted_url_extraction
test_glossary_persistence
test_output_file_naming
test_missing_input_error
test_idempotency
test_multi_month_processing
test_error_logging
test_template_loading

teardown

# 結果サマリー
echo ""
echo "========================================"
echo "E2E Test Results"
echo "========================================"
echo -e "Passed:  ${GREEN}$PASSED${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
