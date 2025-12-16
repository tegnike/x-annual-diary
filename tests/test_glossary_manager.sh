#!/bin/bash
# Test: 用語辞書管理機能（GlossaryManager）テスト
# TDD RED Phase: これらのテストは最初は失敗する（一部は既存実装で通過）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT_DIR="$PROJECT_ROOT/tests/test_output"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# テスト結果カウンター
PASSED=0
FAILED=0

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

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (expected exit code $expected, got $actual)"
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

assert_file_not_exists() {
    local file="$1"
    local message="$2"
    if [[ ! -f "$file" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (file exists but should not: $file)"
        ((FAILED++))
    fi
}

# セットアップ
setup() {
    rm -rf "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR"
    # メインスクリプトを読み込む（関数だけをインポート）
    source "$PROJECT_ROOT/generate-review.sh" 2>/dev/null || true
}

# クリーンアップ
teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
}

echo "================================"
echo "Testing: 用語辞書管理機能"
echo "================================"

setup

# ====== Task 2.1: 辞書の読み込み・保存機能 ======

# Test 1: 辞書ファイルが存在しない場合、空オブジェクトを返す
test_load_glossary_empty() {
    echo ""
    echo "--- Test 2.1.1: 存在しない辞書ファイルを読み込み時、空オブジェクトを返す ---"
    local result
    result=$(loadGlossary "$TEST_OUTPUT_DIR/nonexistent.json")
    assert_equals "{}" "$result" "存在しない辞書ファイルは空オブジェクトを返す"
}

# Test 2: 既存の辞書ファイルを正しく読み込める
test_load_glossary_existing() {
    echo ""
    echo "--- Test 2.1.2: 既存の辞書ファイルを正しく読み込める ---"
    echo '{"Claude Code": "AIコーディングアシスタント"}' > "$TEST_OUTPUT_DIR/test_glossary.json"
    local result
    result=$(loadGlossary "$TEST_OUTPUT_DIR/test_glossary.json")
    assert_contains "$result" "Claude Code" "既存辞書のキーが含まれる"
    assert_contains "$result" "AIコーディングアシスタント" "既存辞書の値が含まれる"
}

# Test 3: 新規用語を追加できる
test_add_term() {
    echo ""
    echo "--- Test 2.1.3: 新規用語を追加できる ---"
    local glossary="{}"
    local result
    result=$(addTerm "$glossary" "jq" "JSONプロセッサ")
    assert_contains "$result" "jq" "追加した用語キーが含まれる"
    assert_contains "$result" "JSONプロセッサ" "追加した用語定義が含まれる"
}

# Test 4: 既存用語に追加で別の用語も追加できる
test_add_multiple_terms() {
    echo ""
    echo "--- Test 2.1.4: 複数の用語を追加できる ---"
    local glossary='{"term1": "def1"}'
    local result
    result=$(addTerm "$glossary" "term2" "def2")
    assert_contains "$result" "term1" "既存用語が保持される"
    assert_contains "$result" "term2" "新規用語が追加される"
}

# Test 5: 用語の存在確認（存在する場合）
test_has_term_exists() {
    echo ""
    echo "--- Test 2.1.5: 既存用語の存在確認（true） ---"
    local glossary='{"Claude": "AI"}'
    hasTerm "$glossary" "Claude"
    local result=$?
    assert_exit_code "0" "$result" "存在する用語はtrue（exit 0）を返す"
}

# Test 6: 用語の存在確認（存在しない場合）
test_has_term_not_exists() {
    echo ""
    echo "--- Test 2.1.6: 存在しない用語の確認（false） ---"
    local glossary='{"Claude": "AI"}'
    hasTerm "$glossary" "NotExist"
    local result=$?
    assert_exit_code "1" "$result" "存在しない用語はfalse（exit 1）を返す"
}

# Test 7: 辞書をファイルに保存できる
test_save_glossary() {
    echo ""
    echo "--- Test 2.1.7: 辞書をファイルに保存できる ---"
    local glossary='{"test": "value"}'
    saveGlossary "$TEST_OUTPUT_DIR/saved_glossary.json" "$glossary"
    assert_file_exists "$TEST_OUTPUT_DIR/saved_glossary.json" "辞書ファイルが作成される"
    local content
    content=$(cat "$TEST_OUTPUT_DIR/saved_glossary.json")
    assert_contains "$content" "test" "保存された辞書にキーが含まれる"
}

# Test 8: 辞書保存時にJSONフォーマットが維持される
test_save_glossary_formatted() {
    echo ""
    echo "--- Test 2.1.8: 辞書保存時にJSONフォーマットが維持される ---"
    local glossary='{"key1":"val1","key2":"val2"}'
    saveGlossary "$TEST_OUTPUT_DIR/formatted.json" "$glossary"
    local content
    content=$(cat "$TEST_OUTPUT_DIR/formatted.json")
    # jqでフォーマットされているか確認（改行があること）
    if [[ "$content" == *$'\n'* ]]; then
        echo -e "${GREEN}PASS${NC}: JSONがフォーマットされている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: JSONがフォーマットされていない"
        ((FAILED++))
    fi
}

# Test 9: 重複用語の追加時に上書きされる
test_add_term_overwrite() {
    echo ""
    echo "--- Test 2.1.9: 重複用語の追加時に上書きされる ---"
    local glossary='{"term": "old_def"}'
    local result
    result=$(addTerm "$glossary" "term" "new_def")
    assert_contains "$result" "new_def" "新しい定義で上書きされる"
}

# ====== Task 2.2: 用語調査失敗時のログ機能 ======

# Test 10: ログファイルに失敗した用語を記録できる
test_log_failed_term() {
    echo ""
    echo "--- Test 2.2.1: 調査失敗した用語をログに記録できる ---"
    if type logFailedTerm &>/dev/null; then
        logFailedTerm "$TEST_OUTPUT_DIR/error.log" "unknown_term" "調査タイムアウト"
        assert_file_exists "$TEST_OUTPUT_DIR/error.log" "エラーログファイルが作成される"
        local content
        content=$(cat "$TEST_OUTPUT_DIR/error.log")
        assert_contains "$content" "unknown_term" "失敗した用語がログに含まれる"
        assert_contains "$content" "調査タイムアウト" "失敗理由がログに含まれる"
    else
        echo -e "${RED}FAIL${NC}: logFailedTerm関数が未実装"
        ((FAILED++))
    fi
}

# Test 11: ログにタイムスタンプが含まれる
test_log_has_timestamp() {
    echo ""
    echo "--- Test 2.2.2: ログにタイムスタンプが含まれる ---"
    if type logFailedTerm &>/dev/null; then
        logFailedTerm "$TEST_OUTPUT_DIR/error2.log" "test_term" "test_reason"
        local content
        content=$(cat "$TEST_OUTPUT_DIR/error2.log")
        # 日付パターン（YYYY-MM-DD or similar）が含まれるか
        if [[ "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
            echo -e "${GREEN}PASS${NC}: タイムスタンプが含まれている"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC}: タイムスタンプが含まれていない"
            ((FAILED++))
        fi
    else
        echo -e "${RED}FAIL${NC}: logFailedTerm関数が未実装"
        ((FAILED++))
    fi
}

# Test 12: 複数のエラーをログに追記できる
test_log_append() {
    echo ""
    echo "--- Test 2.2.3: 複数のエラーをログに追記できる ---"
    if type logFailedTerm &>/dev/null; then
        logFailedTerm "$TEST_OUTPUT_DIR/error3.log" "term1" "reason1"
        logFailedTerm "$TEST_OUTPUT_DIR/error3.log" "term2" "reason2"
        local content
        content=$(cat "$TEST_OUTPUT_DIR/error3.log")
        assert_contains "$content" "term1" "最初のエラーが含まれる"
        assert_contains "$content" "term2" "2番目のエラーが追記される"
    else
        echo -e "${RED}FAIL${NC}: logFailedTerm関数が未実装"
        ((FAILED++))
    fi
}

# Test 13: ログ記録後も処理が継続可能（関数がエラーを投げない）
test_log_no_throw() {
    echo ""
    echo "--- Test 2.2.4: ログ記録後も処理が継続可能 ---"
    if type logFailedTerm &>/dev/null; then
        logFailedTerm "$TEST_OUTPUT_DIR/error4.log" "term" "reason"
        local result=$?
        assert_exit_code "0" "$result" "logFailedTermは正常終了する（exit 0）"
    else
        echo -e "${RED}FAIL${NC}: logFailedTerm関数が未実装"
        ((FAILED++))
    fi
}

# テスト実行
test_load_glossary_empty
test_load_glossary_existing
test_add_term
test_add_multiple_terms
test_has_term_exists
test_has_term_not_exists
test_save_glossary
test_save_glossary_formatted
test_add_term_overwrite
test_log_failed_term
test_log_has_timestamp
test_log_append
test_log_no_throw

teardown

# 結果サマリー
echo ""
echo "================================"
echo "Test Results"
echo "================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
