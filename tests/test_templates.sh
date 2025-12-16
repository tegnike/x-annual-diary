#!/bin/bash
# test_templates.sh
# テンプレートとプロンプト機能のユニットテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../generate-review.sh" 2>/dev/null || true

# テスト用定数
TEST_OUTPUT_DIR="$SCRIPT_DIR/test_output_templates"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# テスト開始前の準備
setup() {
    mkdir -p "$TEST_OUTPUT_DIR"
}

# テスト終了後のクリーンアップ
teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
}

# テスト結果カウンター
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# アサーション関数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    ((TESTS_RUN++))
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ FAIL: $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    ((TESTS_RUN++))
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ FAIL: $message"
        echo "  Expected to contain: $needle"
        echo "  Actual: ${haystack:0:200}..."
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"
    ((TESTS_RUN++))
    if [[ -f "$file" ]]; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ FAIL: $message"
        echo "  File does not exist: $file"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="$2"
    ((TESTS_RUN++))
    if [[ -n "$value" ]]; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ FAIL: $message"
        echo "  Value is empty"
        ((TESTS_FAILED++))
        return 1
    fi
}

# =============================================================================
# タスク6.1: 月次レポートテンプレートのテスト
# =============================================================================

echo ""
echo "=== タスク6.1: 月次レポートテンプレートのテスト ==="
echo ""

test_monthly_template_exists() {
    echo "--- Test: 月次テンプレートファイルが存在する ---"
    assert_file_exists "$TEMPLATES_DIR/monthly-template.md" "月次テンプレートファイルが存在する"
}

test_monthly_template_has_required_sections() {
    echo "--- Test: 月次テンプレートに必要なセクションが含まれる ---"
    if [[ -f "$TEMPLATES_DIR/monthly-template.md" ]]; then
        local template
        template=$(cat "$TEMPLATES_DIR/monthly-template.md")
        assert_contains "$template" "ハイライト" "ハイライトセクションが含まれる"
        assert_contains "$template" "主要トピック" "主要トピックセクションが含まれる"
        assert_contains "$template" "活動サマリー" "活動サマリーセクションが含まれる"
        assert_contains "$template" "注目ツイート" "注目ツイートセクションが含まれる"
    else
        echo "SKIP: テンプレートファイルが存在しません"
    fi
}

test_load_monthly_template() {
    echo "--- Test: loadMonthlyTemplate関数が正しくテンプレートを読み込む ---"
    if type loadMonthlyTemplate &>/dev/null; then
        local template
        template=$(loadMonthlyTemplate)
        assert_not_empty "$template" "テンプレートが空でない"
    else
        echo "SKIP: loadMonthlyTemplate関数が未定義"
    fi
}

# =============================================================================
# タスク6.2: 週次処理用プロンプトのテスト
# =============================================================================

echo ""
echo "=== タスク6.2: 週次処理用プロンプトのテスト ==="
echo ""

test_weekly_prompt_template_exists() {
    echo "--- Test: 週次プロンプトテンプレートファイルが存在する ---"
    assert_file_exists "$TEMPLATES_DIR/weekly-prompt.md" "週次プロンプトテンプレートが存在する"
}

test_weekly_prompt_has_required_elements() {
    echo "--- Test: 週次プロンプトに必要な要素が含まれる ---"
    if [[ -f "$TEMPLATES_DIR/weekly-prompt.md" ]]; then
        local template
        template=$(cat "$TEMPLATES_DIR/weekly-prompt.md")
        assert_contains "$template" "ツイート" "ツイートの言及がある"
        assert_contains "$template" "要約" "要約の言及がある"
        assert_contains "$template" "用語" "用語の言及がある"
        assert_contains "$template" "Markdown" "Markdown出力形式の指定がある"
    else
        echo "SKIP: 週次プロンプトテンプレートが存在しません"
    fi
}

test_weekly_prompt_includes_glossary_update() {
    echo "--- Test: 週次プロンプトに用語辞書更新指示が含まれる ---"
    if [[ -f "$TEMPLATES_DIR/weekly-prompt.md" ]]; then
        local template
        template=$(cat "$TEMPLATES_DIR/weekly-prompt.md")
        assert_contains "$template" "辞書" "辞書更新の言及がある"
    else
        echo "SKIP: 週次プロンプトテンプレートが存在しません"
    fi
}

test_load_weekly_prompt_template() {
    echo "--- Test: loadWeeklyPromptTemplate関数が正しくテンプレートを読み込む ---"
    if type loadWeeklyPromptTemplate &>/dev/null; then
        local template
        template=$(loadWeeklyPromptTemplate)
        assert_not_empty "$template" "週次プロンプトテンプレートが空でない"
    else
        echo "SKIP: loadWeeklyPromptTemplate関数が未定義"
    fi
}

test_build_weekly_context_uses_template() {
    echo "--- Test: buildWeeklyContext関数がテンプレートを使用する ---"
    export YEAR=2025
    local result
    result=$(buildWeeklyContext "テストツイート" "累積サマリー" "{}" "1" "1")
    assert_not_empty "$result" "コンテキストが生成される"
    assert_contains "$result" "2025" "年が含まれる"
    assert_contains "$result" "1月" "月が含まれる"
}

# =============================================================================
# タスク6.3: 月次統合用プロンプトのテスト
# =============================================================================

echo ""
echo "=== タスク6.3: 月次統合用プロンプトのテスト ==="
echo ""

test_monthly_prompt_template_exists() {
    echo "--- Test: 月次プロンプトテンプレートファイルが存在する ---"
    assert_file_exists "$TEMPLATES_DIR/monthly-prompt.md" "月次プロンプトテンプレートが存在する"
}

test_monthly_prompt_has_required_elements() {
    echo "--- Test: 月次プロンプトに必要な要素が含まれる ---"
    if [[ -f "$TEMPLATES_DIR/monthly-prompt.md" ]]; then
        local template
        template=$(cat "$TEMPLATES_DIR/monthly-prompt.md")
        assert_contains "$template" "統合" "統合の言及がある"
        assert_contains "$template" "週次" "週次サマリーの言及がある"
        assert_contains "$template" "過去" "過去月との関連の言及がある"
    else
        echo "SKIP: 月次プロンプトテンプレートが存在しません"
    fi
}

test_monthly_prompt_includes_template_format() {
    echo "--- Test: 月次プロンプトにテンプレート形式出力の指定がある ---"
    if [[ -f "$TEMPLATES_DIR/monthly-prompt.md" ]]; then
        local template
        template=$(cat "$TEMPLATES_DIR/monthly-prompt.md")
        assert_contains "$template" "形式" "出力形式の指定がある"
    else
        echo "SKIP: 月次プロンプトテンプレートが存在しません"
    fi
}

test_load_monthly_prompt_template() {
    echo "--- Test: loadMonthlyPromptTemplate関数が正しくテンプレートを読み込む ---"
    if type loadMonthlyPromptTemplate &>/dev/null; then
        local template
        template=$(loadMonthlyPromptTemplate)
        assert_not_empty "$template" "月次プロンプトテンプレートが空でない"
    else
        echo "SKIP: loadMonthlyPromptTemplate関数が未定義"
    fi
}

test_build_monthly_context_uses_template() {
    echo "--- Test: buildMonthlyContext関数がテンプレートを使用する ---"
    export YEAR=2025
    local result
    result=$(buildMonthlyContext "1" "週次サマリー内容" "過去月サマリー")
    assert_not_empty "$result" "月次コンテキストが生成される"
    assert_contains "$result" "2025" "年が含まれる"
    assert_contains "$result" "1月" "月が含まれる"
}

# =============================================================================
# テンプレート変数置換のテスト
# =============================================================================

echo ""
echo "=== テンプレート変数置換のテスト ==="
echo ""

test_template_variable_substitution() {
    echo "--- Test: テンプレート変数が正しく置換される ---"
    if type applyTemplate &>/dev/null; then
        local template='{{YEAR}}年{{MONTH}}月のレポート'
        local result
        result=$(applyTemplate "$template" "YEAR=2025" "MONTH=3")
        assert_equals "2025年3月のレポート" "$result" "変数が置換される"
    else
        echo "SKIP: applyTemplate関数が未定義"
    fi
}

# =============================================================================
# テスト実行
# =============================================================================

echo ""
echo "=== テスト実行 ==="
echo ""

setup

# タスク6.1テスト
test_monthly_template_exists
test_monthly_template_has_required_sections
test_load_monthly_template

# タスク6.2テスト
test_weekly_prompt_template_exists
test_weekly_prompt_has_required_elements
test_weekly_prompt_includes_glossary_update
test_load_weekly_prompt_template
test_build_weekly_context_uses_template

# タスク6.3テスト
test_monthly_prompt_template_exists
test_monthly_prompt_has_required_elements
test_monthly_prompt_includes_template_format
test_load_monthly_prompt_template
test_build_monthly_context_uses_template

# 追加テスト
test_template_variable_substitution

teardown

# 結果サマリー
echo ""
echo "========================================"
echo "テスト結果サマリー"
echo "========================================"
echo "実行: $TESTS_RUN"
echo "成功: $TESTS_PASSED"
echo "失敗: $TESTS_FAILED"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
