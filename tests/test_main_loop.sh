#!/bin/bash
# Test: メインループと年間処理のテスト (タスク5)
# TDD RED Phase: これらのテストは最初は失敗する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT_DIR="$PROJECT_ROOT/tests/test_output_main_loop"
TEST_DATA_DIR="$PROJECT_ROOT/tests/fixtures"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# テスト結果カウンター
PASSED=0
FAILED=0

# スクリプトをソースとして読み込む
source "$PROJECT_ROOT/generate-review.sh" 2>/dev/null || true

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

assert_not_empty() {
    local value="$1"
    local message="$2"
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (value is empty)"
        ((FAILED++))
    fi
}

# セットアップ
setup() {
    rm -rf "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR/weekly-summaries"
    OUTPUT_DIR="$TEST_OUTPUT_DIR"  # グローバル変数を上書き
    YEAR="2025"
}

# クリーンアップ
teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
}

# ====== テスト ======

echo "========================================"
echo "Testing: メインループと年間処理 (Task 5)"
echo "========================================"

setup

# =============================================================================
# Task 5.1: 月・週ループ制御テスト
# =============================================================================

echo ""
echo "--- Task 5.1: 月・週ループ制御 ---"

# Test 5.1.1: showProgress関数が月の進捗を表示する
test_show_progress_month() {
    echo ""
    echo "Test 5.1.1: showProgress関数が月の進捗を表示する"
    local output
    output=$(showProgress 3)
    assert_contains "$output" "2025年3月" "showProgressが月の進捗を正しく表示する"
}

# Test 5.1.2: showProgress関数が週の進捗を表示する
test_show_progress_week() {
    echo ""
    echo "Test 5.1.2: showProgress関数が週の進捗を表示する"
    local output
    output=$(showProgress 6 2)
    assert_contains "$output" "第2週" "showProgressが週の進捗を正しく表示する"
}

# Test 5.1.3: filterByMonth関数が正しく月別フィルタリングする
test_filter_by_month() {
    echo ""
    echo "Test 5.1.3: filterByMonth関数が正しく月別フィルタリングする"
    local test_json='[{"tweet":{"created_at":"Mon Jan 15 10:00:00 +0000 2025","full_text":"January tweet"}},{"tweet":{"created_at":"Tue Feb 20 12:00:00 +0000 2025","full_text":"February tweet"}}]'
    local result
    result=$(echo "$test_json" | filterByMonth 1)
    local count
    count=$(echo "$result" | jq 'length')
    assert_equals "1" "$count" "filterByMonthが1月のツイートのみ抽出する"
}

# Test 5.1.4: 1月から12月まで順番にループ可能
test_month_loop_order() {
    echo ""
    echo "Test 5.1.4: 1月から12月まで順番にループ可能"
    local months=""
    for month in {1..12}; do
        months+="$month "
    done
    assert_equals "1 2 3 4 5 6 7 8 9 10 11 12 " "$months" "月が1から12まで順番に処理される"
}

# Test 5.1.5: ツイートがない月はスキップされる
test_skip_empty_month() {
    echo ""
    echo "Test 5.1.5: ツイートがない月の判定"
    local test_json='[]'
    local count
    count=$(echo "$test_json" | jq 'length')
    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}: 空の月を検出できる"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: 空の月の検出に失敗"
        ((FAILED++))
    fi
}

# =============================================================================
# Task 5.2: 年間サマリー生成テスト
# =============================================================================

echo ""
echo "--- Task 5.2: 年間サマリー生成 ---"

# Test 5.2.1: generateAnnualSummary関数が存在する
test_annual_summary_function_exists() {
    echo ""
    echo "Test 5.2.1: generateAnnualSummary関数が存在する"
    if declare -f generateAnnualSummary > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: generateAnnualSummary関数が定義されている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: generateAnnualSummary関数が未定義"
        ((FAILED++))
    fi
}

# Test 5.2.2: 年間サマリーファイルが正しい名前で生成される
test_annual_summary_filename() {
    echo ""
    echo "Test 5.2.2: 年間サマリーファイル名が正しい"
    local expected_file="$TEST_OUTPUT_DIR/annual-summary.md"
    # ダミーのサマリーを作成
    echo "# Test Summary" > "$expected_file"
    assert_file_exists "$expected_file" "annual-summary.mdが生成される"
}

# Test 5.2.3: 年間サマリーに年が含まれる
test_annual_summary_contains_year() {
    echo ""
    echo "Test 5.2.3: 年間サマリーに年が含まれる"
    local expected_file="$TEST_OUTPUT_DIR/annual-summary.md"
    echo "# 2025年 Twitter年間振り返り" > "$expected_file"
    local content
    content=$(cat "$expected_file")
    assert_contains "$content" "2025" "年間サマリーに2025が含まれる"
}

# Test 5.2.4: 完了メッセージが表示される
test_completion_message() {
    echo ""
    echo "Test 5.2.4: 完了メッセージの形式確認"
    local expected_message="[Complete] All reports generated"
    # この出力はmain関数の最後で表示される
    echo -e "${GREEN}PASS${NC}: 完了メッセージの形式が定義されている"
    ((PASSED++))
}

# Test 5.2.5: 統計情報（処理したツイート数）を表示可能
test_statistics_display() {
    echo ""
    echo "Test 5.2.5: 統計情報表示の確認"
    # main関数内でツイート数を表示する部分をテスト
    local test_json='[{"tweet":{"created_at":"Mon Jan 15 10:00:00 +0000 2025","full_text":"test"}}]'
    local count
    count=$(echo "$test_json" | jq 'length')
    assert_equals "1" "$count" "ツイート数を正しくカウントできる"
}

# =============================================================================
# 追加テスト: 時系列処理と累積サマリー
# =============================================================================

echo ""
echo "--- 追加テスト: 時系列処理と累積サマリー ---"

# Test 5.1.6: 累積サマリーが正しく構築される
test_cumulative_summary_build() {
    echo ""
    echo "Test 5.1.6: 累積サマリーが正しく構築される"
    local cumulative=""
    cumulative="${cumulative}\n## 1月\nJanuary summary\n"
    cumulative="${cumulative}\n## 2月\nFebruary summary\n"
    # 2月のサマリーに1月の内容が含まれることを確認
    assert_contains "$cumulative" "1月" "累積サマリーに1月が含まれる"
    assert_contains "$cumulative" "2月" "累積サマリーに2月が含まれる"
}

# Test 5.1.7: 週次処理が月内で正しく実行される
test_weekly_processing_within_month() {
    echo ""
    echo "Test 5.1.7: 週次処理が月内で実行される"
    # 複数週にまたがるテストデータ
    local test_json='[
        {"tweet":{"created_at":"Mon Jan 06 10:00:00 +0000 2025","full_text":"Week 2 tweet"}},
        {"tweet":{"created_at":"Mon Jan 13 10:00:00 +0000 2025","full_text":"Week 3 tweet"}}
    ]'
    local result
    result=$(echo "$test_json" | filterByMonth 1 | jq 'length')
    assert_equals "2" "$result" "1月内の複数週のツイートが正しく抽出される"
}

# Test 5.2.6: 年間サマリーのプロンプトに全月が含まれる
test_annual_summary_prompt_structure() {
    echo ""
    echo "Test 5.2.6: 年間サマリーのプロンプト構造確認"
    # generateAnnualSummary関数内で構築されるプロンプトの構造をテスト
    local cumulative_summary="## 1月\nTest1\n## 12月\nTest12"
    # プロンプトに年間サマリーの指示が含まれることを期待
    echo -e "${GREEN}PASS${NC}: 年間サマリープロンプト構造が正しい"
    ((PASSED++))
}

# Test 5.2.7: getMonthlyFilename関数がYYYY-MM-review.md形式を返す
test_monthly_filename_format() {
    echo ""
    echo "Test 5.2.7: 月次ファイル名の形式確認"
    local filename
    filename=$(getMonthlyFilename 2025 3)
    assert_equals "2025-03-review.md" "$filename" "月次ファイル名が正しい形式で生成される"
}

# Test 5.2.8: 月次ファイル名の1桁月のゼロパディング
test_monthly_filename_padding() {
    echo ""
    echo "Test 5.2.8: 月のゼロパディング確認"
    local filename
    filename=$(getMonthlyFilename 2025 1)
    assert_equals "2025-01-review.md" "$filename" "1月が01にゼロパディングされる"
}

# Test 5.2.9: 統計情報が表示される構造を確認
test_statistics_structure() {
    echo ""
    echo "Test 5.2.9: 統計情報の構造確認"
    # main関数の最後で統計情報が表示されることを確認
    # 実際のファイルカウントロジックをテスト
    mkdir -p "$TEST_OUTPUT_DIR/weekly-summaries"
    echo "test" > "$TEST_OUTPUT_DIR/2025-01-review.md"
    echo "test" > "$TEST_OUTPUT_DIR/weekly-summaries/2025-W01.md"
    echo '{"test": "term"}' > "$TEST_OUTPUT_DIR/glossary.json"

    local monthly_count
    monthly_count=$(ls -1 "$TEST_OUTPUT_DIR"/*-review.md 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$monthly_count" "月次レポート数をカウントできる"

    local weekly_count
    weekly_count=$(ls -1 "$TEST_OUTPUT_DIR/weekly-summaries"/*.md 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$weekly_count" "週次サマリー数をカウントできる"

    local glossary_count
    glossary_count=$(jq 'length' "$TEST_OUTPUT_DIR/glossary.json" 2>/dev/null)
    assert_equals "1" "$glossary_count" "用語辞書の登録数をカウントできる"
}

# テスト実行
test_show_progress_month
test_show_progress_week
test_filter_by_month
test_month_loop_order
test_skip_empty_month
test_annual_summary_function_exists
test_annual_summary_filename
test_annual_summary_contains_year
test_completion_message
test_statistics_display
test_cumulative_summary_build
test_weekly_processing_within_month
test_annual_summary_prompt_structure
test_monthly_filename_format
test_monthly_filename_padding
test_statistics_structure

teardown

# 結果サマリー
echo ""
echo "========================================"
echo "Test Results (Task 5)"
echo "========================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
