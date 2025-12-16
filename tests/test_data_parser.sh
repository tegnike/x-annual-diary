#!/bin/bash
# Test: データパーサーのテスト
# 機能: tweets.jsの解析、年フィルタリング、フィールド抽出

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DATA_DIR="$PROJECT_ROOT/tests/fixtures"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

# メインスクリプトを読み込み（関数をインポート）
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

assert_json_length() {
    local json="$1"
    local expected="$2"
    local message="$3"
    local actual
    actual=$(echo "$json" | jq 'length')
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected length: $expected"
        echo "  Actual length: $actual"
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

# セットアップ: テスト用のフィクスチャを作成
setup() {
    mkdir -p "$TEST_DATA_DIR"

    # テスト用tweets.jsを作成
    cat > "$TEST_DATA_DIR/test_tweets.js" << 'EOF'
window.YTD.tweets.part0 = [
  {
    "tweet": {
      "id_str": "1001",
      "full_text": "テスト投稿1 #test",
      "created_at": "Mon Jan 15 10:00:00 +0000 2025",
      "entities": {
        "hashtags": [{"text": "test"}],
        "user_mentions": [],
        "urls": []
      }
    }
  },
  {
    "tweet": {
      "id_str": "1002",
      "full_text": "テスト投稿2",
      "created_at": "Wed Feb 20 15:30:00 +0000 2025",
      "entities": {
        "hashtags": [],
        "user_mentions": [],
        "urls": [{"expanded_url": "https://x.com/user/status/123"}]
      }
    }
  },
  {
    "tweet": {
      "id_str": "1003",
      "full_text": "2024年の投稿",
      "created_at": "Tue Dec 10 08:00:00 +0000 2024",
      "entities": {
        "hashtags": [],
        "user_mentions": [],
        "urls": []
      }
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
echo "Testing: データパーサー"
echo "================================"

setup

# Test 1: tweets.jsをパースしてJSON配列を取得
test_parse_twitter_archive() {
    echo ""
    echo "--- Test: tweets.jsパース ---"
    local result
    result=$(parseTwitterArchive "$TEST_DATA_DIR/test_tweets.js")

    # 有効なJSONかチェック
    if echo "$result" | jq '.' > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: 有効なJSONとしてパースできる"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: JSONパースに失敗"
        ((FAILED++))
    fi

    # 配列長チェック
    assert_json_length "$result" "3" "3件のツイートが含まれる"
}

# Test 2: 指定年のツイートのみ抽出
test_filter_by_year() {
    echo ""
    echo "--- Test: 年フィルタリング ---"
    local tweets
    tweets=$(parseTwitterArchive "$TEST_DATA_DIR/test_tweets.js")

    local filtered
    filtered=$(echo "$tweets" | filterByYear "2025")

    # 2025年のツイートのみ抽出されるか
    assert_json_length "$filtered" "2" "2025年のツイートは2件"

    # 2024年のツイートが除外されているか
    local has_2024
    has_2024=$(echo "$filtered" | jq '[.[] | select(.tweet.created_at | contains("2024"))] | length')
    assert_equals "0" "$has_2024" "2024年のツイートは含まれない"
}

# Test 3: 月別フィルタリング
test_filter_by_month() {
    echo ""
    echo "--- Test: 月別フィルタリング ---"
    local tweets
    tweets=$(parseTwitterArchive "$TEST_DATA_DIR/test_tweets.js")
    local filtered_2025
    filtered_2025=$(echo "$tweets" | filterByYear "2025")

    # 1月のツイート
    local jan_tweets
    jan_tweets=$(echo "$filtered_2025" | filterByMonth "1")
    assert_json_length "$jan_tweets" "1" "1月のツイートは1件"

    # 2月のツイート
    local feb_tweets
    feb_tweets=$(echo "$filtered_2025" | filterByMonth "2")
    assert_json_length "$feb_tweets" "1" "2月のツイートは1件"
}

# Test 4: 主要フィールドの保持確認
test_extract_fields() {
    echo ""
    echo "--- Test: フィールド抽出 ---"
    local tweets
    tweets=$(parseTwitterArchive "$TEST_DATA_DIR/test_tweets.js")

    local first_tweet
    first_tweet=$(echo "$tweets" | jq '.[0].tweet')

    # full_textの存在確認
    local full_text
    full_text=$(echo "$first_tweet" | jq -r '.full_text')
    assert_not_empty "$full_text" "full_textが存在する"

    # created_atの存在確認
    local created_at
    created_at=$(echo "$first_tweet" | jq -r '.created_at')
    assert_not_empty "$created_at" "created_atが存在する"

    # entitiesの存在確認
    local entities
    entities=$(echo "$first_tweet" | jq '.entities')
    assert_not_empty "$entities" "entitiesが存在する"
}

# Test 5: 引用ツイートURL抽出
test_extract_quoted_urls() {
    echo ""
    echo "--- Test: 引用ツイートURL抽出 ---"
    local tweets
    tweets=$(parseTwitterArchive "$TEST_DATA_DIR/test_tweets.js")

    # 引用ツイートを含むツイート（2番目）
    local tweet_with_quote
    tweet_with_quote=$(echo "$tweets" | jq '.[1]')

    local urls
    urls=$(echo "$tweet_with_quote" | extractQuotedUrls)

    # x.comのURLが抽出されるか
    local url_count
    url_count=$(echo "$urls" | jq 'length')
    assert_equals "1" "$url_count" "引用ツイートURLが1件抽出される"

    # 引用ツイートがないツイート（1番目）
    local tweet_without_quote
    tweet_without_quote=$(echo "$tweets" | jq '.[0]')

    local no_urls
    no_urls=$(echo "$tweet_without_quote" | extractQuotedUrls)
    local no_url_count
    no_url_count=$(echo "$no_urls" | jq 'length')
    assert_equals "0" "$no_url_count" "引用ツイートがない場合は0件"
}

# Test 6: ツイートのフォーマット出力
test_format_tweets() {
    echo ""
    echo "--- Test: ツイートフォーマット ---"
    local tweets
    tweets=$(parseTwitterArchive "$TEST_DATA_DIR/test_tweets.js")
    local filtered
    filtered=$(echo "$tweets" | filterByYear "2025")

    local formatted
    formatted=$(echo "$filtered" | formatTweetsForContext)

    # 出力が空でないこと
    assert_not_empty "$formatted" "フォーマットされた出力が存在する"

    # 本文が含まれること
    if [[ "$formatted" == *"テスト投稿"* ]]; then
        echo -e "${GREEN}PASS${NC}: ツイート本文が含まれる"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}: ツイート本文が含まれない"
        ((FAILED++))
    fi
}

# テスト実行
test_parse_twitter_archive
test_filter_by_year
test_filter_by_month
test_extract_fields
test_extract_quoted_urls
test_format_tweets

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
