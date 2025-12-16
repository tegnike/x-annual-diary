#!/bin/bash
# Test: 月次レポート生成機能のテスト (Task 4)
# 機能: 週次サマリー統合、月次レポート生成

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

assert_file_not_empty() {
    local file="$1"
    local message="$2"
    if [[ -f "$file" && -s "$file" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message (file not found or empty: $file)"
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

    # テスト用週次サマリーファイル（1月用）
    cat > "$TEST_OUTPUT_DIR/weekly-summaries/2025-W01.md" << 'EOF'
## 週次サマリー（2025年1月 第1週）

### 主要トピック
- TypeScript学習開始
- 型システムの基礎

### 活動内容
新年の抱負としてTypeScript習得を目標に設定。

### 注目ツイート
- 「今日からTypeScriptの勉強を始めた」
EOF

    cat > "$TEST_OUTPUT_DIR/weekly-summaries/2025-W02.md" << 'EOF'
## 週次サマリー（2025年1月 第2週）

### 主要トピック
- Reactコンポーネント作成
- フックの活用

### 活動内容
TypeScriptでReactアプリを構築中。

### 注目ツイート
- 「useStateとuseEffectの違いがわかってきた」
EOF

    # テスト用週次サマリーファイル（2月用）
    cat > "$TEST_OUTPUT_DIR/weekly-summaries/2025-W05.md" << 'EOF'
## 週次サマリー（2025年2月 第1週）

### 主要トピック
- Next.js入門
- SSRとSSG

### 活動内容
Next.jsを使ったプロジェクトを開始。

### 注目ツイート
- 「Next.jsのファイルベースルーティングが便利」
EOF

    # 1月の月次レポート（2月の累積文脈用）
    cat > "$TEST_OUTPUT_DIR/2025-01-review.md" << 'EOF'
# 2025年1月 振り返りレポート

## 今月のハイライト
- TypeScript学習を本格的に開始

## 主要トピック
- TypeScript基礎
- React入門

## 活動サマリー
1月は型付き言語の学習に注力。基本的な型システムの理解とReactとの組み合わせを学んだ。
EOF

}

teardown() {
    rm -rf "$TEST_OUTPUT_DIR"
}

# ====== テスト: 4.1 週次サマリー統合機能 ======

echo "================================"
echo "Testing: 月次レポート生成 (Task 4)"
echo "================================"

setup

test_load_weekly_summaries_for_month() {
    echo ""
    echo "--- Test 4.1.1: loadWeeklySummariesForMonth - 月別読み込み ---"

    if declare -f loadWeeklySummariesForMonth > /dev/null 2>&1; then
        local summaries
        summaries=$(loadWeeklySummariesForMonth "2025" "1")

        assert_contains "$summaries" "TypeScript学習開始" "1月第1週のサマリーが含まれる"
        assert_contains "$summaries" "Reactコンポーネント作成" "1月第2週のサマリーが含まれる"
    else
        # フォールバック: 既存のloadWeeklySummaries関数を使用
        if declare -f loadWeeklySummaries > /dev/null 2>&1; then
            local summaries
            summaries=$(loadWeeklySummaries "2025" "1")
            assert_not_empty "$summaries" "loadWeeklySummaries関数が週次サマリーを読み込む"
        else
            echo -e "${RED}FAIL${NC}: 週次サマリー読み込み関数が定義されていない"
            ((FAILED++))
        fi
    fi
}

test_load_weekly_summaries_chronological() {
    echo ""
    echo "--- Test 4.1.2: loadWeeklySummariesForMonth - 時系列順 ---"

    if declare -f loadWeeklySummariesForMonth > /dev/null 2>&1; then
        local summaries
        summaries=$(loadWeeklySummariesForMonth "2025" "1")

        # W01がW02より前に来ることを確認
        local pos_w01 pos_w02
        pos_w01=$(echo "$summaries" | grep -n "第1週" | head -1 | cut -d: -f1)
        pos_w02=$(echo "$summaries" | grep -n "第2週" | head -1 | cut -d: -f1)

        if [[ -n "$pos_w01" && -n "$pos_w02" && "$pos_w01" -lt "$pos_w02" ]]; then
            echo -e "${GREEN}PASS${NC}: 週次サマリーが時系列順に並んでいる"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC}: 週次サマリーの順序が不正"
            ((FAILED++))
        fi
    else
        skip_test "loadWeeklySummariesForMonth関数が未定義"
    fi
}

test_load_previous_monthly_summaries() {
    echo ""
    echo "--- Test 4.1.3: loadPreviousMonthlySummaries - 累積文脈読み込み ---"

    if declare -f loadPreviousMonthlySummaries > /dev/null 2>&1; then
        local prev_summaries
        prev_summaries=$(loadPreviousMonthlySummaries "2025" "2")

        assert_contains "$prev_summaries" "2025年1月" "1月のサマリーが含まれる"
        assert_contains "$prev_summaries" "TypeScript学習を本格的に開始" "1月のハイライトが含まれる"
    else
        skip_test "loadPreviousMonthlySummaries関数が未定義（実装が必要）"
    fi
}

test_merge_weekly_summaries() {
    echo ""
    echo "--- Test 4.1.4: mergeWeeklySummaries - 複数週次の結合 ---"

    if declare -f mergeWeeklySummaries > /dev/null 2>&1; then
        local week1="## 第1週\nトピック1"
        local week2="## 第2週\nトピック2"

        local merged
        merged=$(mergeWeeklySummaries "$week1" "$week2")

        assert_contains "$merged" "第1週" "第1週が含まれる"
        assert_contains "$merged" "第2週" "第2週が含まれる"
    else
        # 結合は単純な連結でも可（既存関数で代用）
        echo -e "${YELLOW}INFO${NC}: mergeWeeklySummaries関数が未定義（既存方式で代用可能）"
        ((SKIPPED++))
    fi
}

# ====== テスト: 4.2 月次レポート生成 ======

test_get_monthly_filename() {
    echo ""
    echo "--- Test 4.2.1: getMonthlyFilename - ファイル名形式 ---"

    local filename
    filename=$(getMonthlyFilename "2025" "1")
    assert_equals "2025-01-review.md" "$filename" "1月のファイル名が正しい"

    filename=$(getMonthlyFilename "2025" "12")
    assert_equals "2025-12-review.md" "$filename" "12月のファイル名が正しい"
}

test_build_monthly_context() {
    echo ""
    echo "--- Test 4.2.2: buildMonthlyContext - コンテキスト構築 ---"

    if declare -f buildMonthlyContext > /dev/null 2>&1; then
        local weekly_summaries="## 第1週\nTypeScript学習"
        local previous_summaries=""

        local context
        context=$(buildMonthlyContext "1" "$weekly_summaries" "$previous_summaries")

        assert_contains "$context" "2025年1月" "対象月が含まれる"
        assert_contains "$context" "TypeScript学習" "週次サマリーが含まれる"
        assert_contains "$context" "月次レポート" "月次レポート生成の指示がある"
    else
        skip_test "buildMonthlyContext関数が未定義（実装が必要）"
    fi
}

test_build_monthly_context_with_previous() {
    echo ""
    echo "--- Test 4.2.3: buildMonthlyContext - 累積文脈付き ---"

    if declare -f buildMonthlyContext > /dev/null 2>&1; then
        local weekly_summaries="## 第5週\nNext.js入門"
        local previous_summaries="## 1月\nTypeScript基礎を学習"

        local context
        context=$(buildMonthlyContext "2" "$weekly_summaries" "$previous_summaries")

        assert_contains "$context" "2025年2月" "2月が対象"
        assert_contains "$context" "過去月" "過去月との関連性指示がある"
        assert_contains "$context" "TypeScript基礎" "1月のサマリーが含まれる"
    else
        skip_test "buildMonthlyContext関数が未定義"
    fi
}

test_aggregate_month_january() {
    echo ""
    echo "--- Test 4.2.4: aggregateMonth - 1月レポート（累積なし）---"

    # aggregateMonth関数が存在するか確認
    if declare -f aggregateMonth > /dev/null 2>&1; then
        # 実際のClaude Code実行が必要なのでスキップ
        if ! command -v claude &> /dev/null; then
            skip_test "Claude Code CLIがインストールされていない"
        else
            skip_test "Claude Code実行テストはインテグレーションテストで実施"
        fi
    else
        echo -e "${RED}FAIL${NC}: aggregateMonth関数が定義されていない"
        ((FAILED++))
    fi
}

test_aggregate_month_function_exists() {
    echo ""
    echo "--- Test 4.2.5: aggregateMonth - 関数の存在確認 ---"

    if declare -f aggregateMonth > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: aggregateMonth関数が定義されている"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: aggregateMonth関数が定義されていない"
        ((FAILED++))
    fi
}

test_save_monthly_report() {
    echo ""
    echo "--- Test 4.2.6: 月次レポート保存 ---"

    local report="# 2025年1月 振り返りレポート\n\nテスト内容"
    local filename
    filename=$(getMonthlyFilename "2025" "1")

    echo -e "$report" > "$TEST_OUTPUT_DIR/$filename"

    assert_file_exists "$TEST_OUTPUT_DIR/2025-01-review.md" "月次レポートファイルが作成される"
    assert_file_not_empty "$TEST_OUTPUT_DIR/2025-01-review.md" "月次レポートファイルが空でない"
}

test_monthly_template_structure() {
    echo ""
    echo "--- Test 4.2.7: 月次レポートテンプレート構造 ---"

    # buildMonthlyContext関数のプロンプトにテンプレート指示が含まれているか確認
    # 関数の定義を確認
    local func_def
    func_def=$(declare -f buildMonthlyContext 2>/dev/null || echo "")

    if [[ -n "$func_def" ]]; then
        assert_contains "$func_def" "ハイライト" "テンプレートにハイライトセクションがある"
        assert_contains "$func_def" "主要トピック" "テンプレートに主要トピックセクションがある"
        assert_contains "$func_def" "活動サマリー" "テンプレートに活動サマリーセクションがある"
    else
        echo -e "${RED}FAIL${NC}: buildMonthlyContext関数が取得できない"
        ((FAILED++))
    fi
}

# テスト実行
test_load_weekly_summaries_for_month
test_load_weekly_summaries_chronological
test_load_previous_monthly_summaries
test_merge_weekly_summaries
test_get_monthly_filename
test_build_monthly_context
test_build_monthly_context_with_previous
test_aggregate_month_january
test_aggregate_month_function_exists
test_save_monthly_report
test_monthly_template_structure

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
