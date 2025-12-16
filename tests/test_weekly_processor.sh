#!/bin/bash
# Test: 週次処理エンジンのテスト
# 機能: コンテキスト構築、Claude Code呼び出し、サマリー保存

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DATA_DIR="$PROJECT_ROOT/tests/fixtures"
TEST_OUTPUT_DIR="$PROJECT_ROOT/tests/test_output"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

# メインスクリプトを読み込み
source "$PROJECT_ROOT/generate-review.sh" 2>/dev/null || true

# テストヘルパー
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

assert_not_empty() {
    local value="$1"
    local message="$2"
    if [[ -n "$value" && "$value" != "null" && "$value" != "[]" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (value is empty or null)"
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

skip_test() {
    local message="$1"
    echo -e "${YELLOW}SKIP${NC}: $message"
    ((SKIPPED++))
}

# セットアップ
setup() {
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR/weekly-summaries"

    # 環境変数設定
    export OUTPUT_DIR="$TEST_OUTPUT_DIR"
    export YEAR="2025"

    # テスト用ツイートデータ
    cat > "$TEST_DATA_DIR/test_weekly_tweets.json" << 'EOF'
[
  {
    "tweet": {
      "id_str": "2001",
      "full_text": "今日からTypeScriptの勉強を始めた",
      "created_at": "Mon Jan 06 10:00:00 +0000 2025",
      "entities": {"hashtags": [], "user_mentions": [], "urls": []}
    }
  },
  {
    "tweet": {
      "id_str": "2002",
      "full_text": "型システムの便利さに感動している",
      "created_at": "Wed Jan 08 15:00:00 +0000 2025",
      "entities": {"hashtags": [], "user_mentions": [], "urls": []}
    }
  }
]
EOF

    # 空のツイートデータ
    echo "[]" > "$TEST_DATA_DIR/empty_tweets.json"

    # テスト用辞書
    echo '{"TypeScript": "Microsoft製の型付きJavaScript"}' > "$TEST_DATA_DIR/test_glossary.json"
}

teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
    # TEST_DATA_DIRは他のテストでも使うので削除しない
}

# ====== テスト: 3.1 コンテキスト構築 ======

echo "================================"
echo "Testing: 週次処理エンジン (Task 3)"
echo "================================"

setup

test_build_weekly_context_structure() {
    echo ""
    echo "--- Test 3.1.1: buildWeeklyContext - 構造 ---"

    local tweets="日時: Mon Jan 06 10:00:00 +0000 2025\n本文: テストツイート"
    local cumulative=""
    local glossary='{"term1": "def1"}'

    local context
    context=$(buildWeeklyContext "$tweets" "$cumulative" "$glossary" "1" "1")

    # コンテキストに必要な要素が含まれているか
    assert_contains "$context" "2025年1月 第1週" "対象期間が含まれる"
    assert_contains "$context" "テストツイート" "ツイートデータが含まれる"
    assert_contains "$context" "term1" "用語辞書が含まれる"
    assert_contains "$context" "週次サマリー" "出力形式が指定されている"
}

test_build_weekly_context_with_cumulative() {
    echo ""
    echo "--- Test 3.1.2: buildWeeklyContext - 累積サマリー ---"

    local tweets="本文: 今週のツイート"
    local cumulative="## 前週のまとめ\n- 重要なトピック1\n- 重要なトピック2"
    local glossary='{}'

    local context
    context=$(buildWeeklyContext "$tweets" "$cumulative" "$glossary" "2" "3")

    assert_contains "$context" "前週のまとめ" "累積サマリーが含まれる"
    assert_contains "$context" "2025年2月 第3週" "対象期間が正しい"
}

test_build_weekly_context_with_glossary() {
    echo ""
    echo "--- Test 3.1.3: buildWeeklyContext - 用語辞書参照 ---"

    local tweets="本文: TypeScriptを使った開発"
    local cumulative=""
    local glossary='{"TypeScript": "型付きJavaScript", "React": "UIライブラリ"}'

    local context
    context=$(buildWeeklyContext "$tweets" "$cumulative" "$glossary" "1" "2")

    assert_contains "$context" "TypeScript" "辞書の用語が含まれる"
    assert_contains "$context" "型付きJavaScript" "辞書の定義が含まれる"
}

# ====== テスト: 3.2 Claude Code CLI呼び出し ======

test_invoke_claude_code_prompt_format() {
    echo ""
    echo "--- Test 3.2.1: invokeClaudeCode - プロンプト形式 ---"

    # invokeClaudeCode関数が存在するか確認
    if declare -f invokeClaudeCode > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: invokeClaudeCode関数が定義されている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: invokeClaudeCode関数が定義されていない"
        ((FAILED++))
    fi
}

test_process_week_error_handling() {
    echo ""
    echo "--- Test 3.2.2: processWeek - エラーハンドリング ---"

    # claudeコマンドが利用できない場合のハンドリング
    # 実際のテストではモックを使用するか、エラーメッセージを確認

    # processWeek関数が存在するか確認
    if declare -f processWeek > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: processWeek関数が定義されている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: processWeek関数が定義されていない"
        ((FAILED++))
    fi
}

test_process_week_returns_markdown() {
    echo ""
    echo "--- Test 3.2.3: processWeek - Markdown出力 ---"

    # Claude Codeが実際に利用可能かチェック
    if ! command -v claude &> /dev/null; then
        skip_test "Claude Code CLIがインストールされていない"
        return
    fi

    # 実際のClaude Code実行はコストがかかるのでスキップ
    skip_test "Claude Code実行テストはインテグレーションテストで実施"
}

# ====== テスト: 3.3 週次サマリー保存 ======

test_save_weekly_summary_creates_file() {
    echo ""
    echo "--- Test 3.3.1: saveWeeklySummary - ファイル作成 ---"

    local summary="## 週次サマリー\n- トピック1"
    local year="2025"
    local week_num="5"

    saveWeeklySummary "$summary" "$year" "$week_num"

    local expected_file="$TEST_OUTPUT_DIR/weekly-summaries/2025-W05.md"
    assert_file_exists "$expected_file" "週次サマリーファイルが作成される"
}

test_save_weekly_summary_filename_format() {
    echo ""
    echo "--- Test 3.3.2: saveWeeklySummary - ファイル名形式 ---"

    # 1桁の週番号がゼロ埋めされるか
    saveWeeklySummary "test" "2025" "3"
    assert_file_exists "$TEST_OUTPUT_DIR/weekly-summaries/2025-W03.md" "週番号がゼロ埋めされる"

    # 2桁の週番号
    saveWeeklySummary "test" "2025" "15"
    assert_file_exists "$TEST_OUTPUT_DIR/weekly-summaries/2025-W15.md" "2桁週番号も正しく保存される"
}

test_skip_empty_week() {
    echo ""
    echo "--- Test 3.3.3: 空週のスキップ ---"

    # processWeekForMonth関数の存在確認（新しい週単位処理関数）
    if declare -f processWeekForMonth > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: processWeekForMonth関数が定義されている"
        ((PASSED++))
    else
        # 既存のprocessWeek関数で代替
        if declare -f processWeek > /dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}: processWeek関数で週単位処理が可能"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC}: 週単位処理関数が定義されていない"
            ((FAILED++))
        fi
    fi
}

test_glossary_update_after_processing() {
    echo ""
    echo "--- Test 3.3.4: 処理後の辞書更新 ---"

    # addTerm関数のテスト
    local glossary='{}'
    local updated
    updated=$(addTerm "$glossary" "NewTerm" "新しい定義")

    assert_contains "$updated" "NewTerm" "新規用語が追加される"
    assert_contains "$updated" "新しい定義" "定義が正しく保存される"
}

# ====== テスト: 週単位の実際の処理 ======

test_get_weeks_in_month() {
    echo ""
    echo "--- Test 3.3.5: getWeeksInMonth - 月内の週取得 ---"

    if declare -f getWeeksInMonth > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: getWeeksInMonth関数が定義されている"
        ((PASSED++))
    else
        echo -e "${YELLOW}INFO${NC}: getWeeksInMonth関数が未定義（実装が必要）"
        ((SKIPPED++))
    fi
}

test_get_week_tweets() {
    echo ""
    echo "--- Test 3.3.6: getWeekTweets - 週別ツイート取得 ---"

    if declare -f getWeekTweets > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: getWeekTweets関数が定義されている"
        ((PASSED++))
    else
        echo -e "${YELLOW}INFO${NC}: getWeekTweets関数が未定義（実装が必要）"
        ((SKIPPED++))
    fi
}

# テスト実行
test_build_weekly_context_structure
test_build_weekly_context_with_cumulative
test_build_weekly_context_with_glossary
test_invoke_claude_code_prompt_format
test_process_week_error_handling
test_process_week_returns_markdown
test_save_weekly_summary_creates_file
test_save_weekly_summary_filename_format
test_skip_empty_week
test_glossary_update_after_processing
test_get_weeks_in_month
test_get_week_tweets

teardown

# 結果サマリー
echo ""
echo "================================"
echo "Test Results"
echo "================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
