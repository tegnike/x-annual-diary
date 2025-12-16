#!/bin/bash
# Test: メインスクリプトの骨格テスト
# TDD RED Phase: これらのテストは最初は失敗する

# set -eを使用しない（テスト失敗時も継続するため）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT_DIR="$PROJECT_ROOT/tests/test_output"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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

# セットアップ
setup() {
    rm -rf "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR"
}

# クリーンアップ
teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
}

# ====== テスト ======

echo "================================"
echo "Testing: メインスクリプトの骨格"
echo "================================"

setup

# Test 1: スクリプトファイルが存在する
test_script_exists() {
    echo ""
    echo "--- Test: スクリプトファイルの存在確認 ---"
    assert_file_exists "$PROJECT_ROOT/generate-review.sh" "generate-review.shが存在する"
}

# Test 2: スクリプトが実行可能である
test_script_executable() {
    echo ""
    echo "--- Test: スクリプトの実行権限確認 ---"
    if [[ -x "$PROJECT_ROOT/generate-review.sh" ]]; then
        echo -e "${GREEN}PASS${NC}: スクリプトが実行可能である"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: スクリプトに実行権限がない"
        ((FAILED++))
    fi
}

# Test 3: 入力ファイルが存在しない場合にエラー終了する
test_missing_input_file() {
    echo ""
    echo "--- Test: 入力ファイル不存在時のエラー ---"
    if [[ -f "$PROJECT_ROOT/generate-review.sh" ]]; then
        output=$("$PROJECT_ROOT/generate-review.sh" "/nonexistent/tweets.js" 2>&1 || true)
        exit_code=$?
        # エラーメッセージを含むか確認
        assert_contains "$output" "Error" "存在しないファイルでエラーメッセージが表示される"
    else
        echo -e "${RED}SKIP${NC}: スクリプトが存在しないためスキップ"
        ((FAILED++))
    fi
}

# Test 4: 出力ディレクトリが自動作成される
test_output_dir_creation() {
    echo ""
    echo "--- Test: 出力ディレクトリの自動作成 ---"
    # この部分はスクリプト内で ensureOutputDir が呼ばれた後にテスト
    # 実際のテストは統合テストで行う
    echo -e "${GREEN}SKIP${NC}: 統合テストで確認"
}

# Test 5: 依存ツール確認（jqの存在）
test_jq_dependency() {
    echo ""
    echo "--- Test: jqの依存確認 ---"
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}PASS${NC}: jqがインストールされている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: jqがインストールされていない"
        ((FAILED++))
    fi
}

# Test 6: 依存ツール確認（claudeの存在）
test_claude_dependency() {
    echo ""
    echo "--- Test: claudeの依存確認 ---"
    if command -v claude &> /dev/null; then
        echo -e "${GREEN}PASS${NC}: claudeがインストールされている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: claudeがインストールされていない"
        ((FAILED++))
    fi
}

# テスト実行
test_script_exists
test_script_executable
test_missing_input_file
test_jq_dependency
test_claude_dependency

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
