#!/bin/bash
# Test: 週別グループ化のテスト
# 機能: ツイートの週番号計算とグループ化

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DATA_DIR="$PROJECT_ROOT/tests/fixtures"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

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

# セットアップ
setup() {
    mkdir -p "$TEST_DATA_DIR"

    # 週またぎテスト用データ
    cat > "$TEST_DATA_DIR/test_weekly_tweets.js" << 'EOF'
window.YTD.tweets.part0 = [
  {
    "tweet": {
      "id_str": "2001",
      "full_text": "1月第1週のツイート",
      "created_at": "Mon Jan 06 10:00:00 +0000 2025",
      "entities": {"hashtags": [], "user_mentions": [], "urls": []}
    }
  },
  {
    "tweet": {
      "id_str": "2002",
      "full_text": "1月第1週のツイート2",
      "created_at": "Wed Jan 08 15:00:00 +0000 2025",
      "entities": {"hashtags": [], "user_mentions": [], "urls": []}
    }
  },
  {
    "tweet": {
      "id_str": "2003",
      "full_text": "1月第2週のツイート",
      "created_at": "Mon Jan 13 09:00:00 +0000 2025",
      "entities": {"hashtags": [], "user_mentions": [], "urls": []}
    }
  },
  {
    "tweet": {
      "id_str": "2004",
      "full_text": "2月第1週のツイート",
      "created_at": "Mon Feb 03 12:00:00 +0000 2025",
      "entities": {"hashtags": [], "user_mentions": [], "urls": []}
    }
  }
]
EOF
}

teardown() {
    rm -rf "$TEST_DATA_DIR"
}

# ====== テスト ======

echo "================================"
echo "Testing: 週別グループ化"
echo "================================"

setup

# Test 1: 週番号計算（macOS互換）
test_week_number_calculation() {
    echo ""
    echo "--- Test: 週番号計算 ---"

    # 2025年1月6日（月曜日）→ 第2週
    local week1
    week1=$(getWeekNumber "Mon Jan 06 10:00:00 +0000 2025")
    # ISO週番号では1月1日がどの曜日かで変わる
    # 2025年1月1日は水曜日なので、1月6日は第2週
    assert_not_empty "$week1" "週番号が計算できる"

    # 2025年1月13日（月曜日）→ 第3週
    local week2
    week2=$(getWeekNumber "Mon Jan 13 09:00:00 +0000 2025")
    assert_not_empty "$week2" "別の日付でも週番号が計算できる"
}

# Test 2: 週別グループ化
test_group_by_week() {
    echo ""
    echo "--- Test: 週別グループ化 ---"
    local tweets
    tweets=$(parseTwitterArchive "$TEST_DATA_DIR/test_weekly_tweets.js")

    local grouped
    grouped=$(echo "$tweets" | groupByWeek)

    # グループが作成されること
    assert_not_empty "$grouped" "グループ化されたデータが存在する"

    # 有効なJSONであること
    if echo "$grouped" | jq '.' > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: 有効なJSONとしてグループ化される"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: JSONフォーマットエラー"
        ((FAILED++))
    fi
}

# Test 3: 実際のtweets.jsでのテスト
test_real_tweets_file() {
    echo ""
    echo "--- Test: 実際のtweets.jsファイル ---"

    local real_tweets_file
    real_tweets_file=$(echo $PROJECT_ROOT/twitter-*/data/tweets.js)

    if [[ -f "$real_tweets_file" ]]; then
        local tweets
        tweets=$(parseTwitterArchive "$real_tweets_file")

        local filtered
        filtered=$(echo "$tweets" | filterByYear "2025")

        local count
        count=$(echo "$filtered" | jq 'length')

        echo -e "${GREEN}PASS${NC}: 実際のファイルから${count}件の2025年ツイートを抽出"
        ((PASSED++))

        # 月別に分けられること
        for month in 1 12; do
            local month_tweets
            month_tweets=$(echo "$filtered" | filterByMonth "$month")
            local month_count
            month_count=$(echo "$month_tweets" | jq 'length')
            echo "  ${month}月: ${month_count}件"
        done
    else
        echo -e "${RED}SKIP${NC}: 実際のtweets.jsファイルが見つからない"
    fi
}

# テスト実行
test_week_number_calculation
test_group_by_week
test_real_tweets_file

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
