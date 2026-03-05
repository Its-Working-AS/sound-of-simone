#!/bin/bash

# Deployment Verification Script
# This script checks if all required components are properly deployed

set -uo pipefail

echo "🔍 Verifying deployment of Sound of Simone..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAIN_DOMAIN="${MAIN_DOMAIN:-soundofsimone.no}"
PROXY_DOMAIN="${PROXY_DOMAIN:-decap.soundofsimone.no}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
MAX_TIME="${MAX_TIME:-15}"
RETRY_COUNT="${RETRY_COUNT:-2}"
RETRY_DELAY="${RETRY_DELAY:-1}"

TOTAL_CHECKS=0
FAILED_CHECKS=0

start_ts="$(date +%s)"

curl_common_args=(
    -sS
    --connect-timeout "$CONNECT_TIMEOUT"
    --max-time "$MAX_TIME"
    --retry "$RETRY_COUNT"
    --retry-delay "$RETRY_DELAY"
)

record_result() {
    local result=$1
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ "$result" -ne 0 ]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Function to check HTTP status
check_url() {
    local url=$1
    local name=$2

    echo -n "Checking $name ($url)... "

    if curl "${curl_common_args[@]}" -f -I "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        record_result 0
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        record_result 1
        return 1
    fi
}

# Function to check if content is accessible
check_content() {
    local url=$1
    local expected=$2
    local name=$3

    echo -n "Checking $name content... "

    if curl "${curl_common_args[@]}" "$url" | grep -q "$expected"; then
        echo -e "${GREEN}✓ OK${NC}"
        record_result 0
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        record_result 1
        return 1
    fi
}

check_dns() {
    local domain=$1

    echo -n "Resolving $domain... "
    if dig +short "$domain" | grep -q .; then
        echo -e "${GREEN}✓ OK${NC}"
        record_result 0
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        record_result 1
        return 1
    fi
}

echo "⏱️ Timeout config: connect=${CONNECT_TIMEOUT}s, max=${MAX_TIME}s, retries=${RETRY_COUNT}"
echo ""

echo "📍 Testing Main Site"
echo "===================="
check_url "https://$MAIN_DOMAIN" "Main site"
check_url "https://$MAIN_DOMAIN/about" "About page"
check_url "https://$MAIN_DOMAIN/blog/welcome" "Blog post"
check_url "https://$MAIN_DOMAIN/admin/" "CMS admin interface"
echo ""

echo "🔐 Testing OAuth Proxy"
echo "======================"
check_url "https://$PROXY_DOMAIN/health" "OAuth proxy health"
check_content "https://$PROXY_DOMAIN/health" "\"ok\":true" "OAuth proxy health response"
echo ""

echo "🔧 Testing DNS Resolution"
echo "=========================="
check_dns "$MAIN_DOMAIN"
check_dns "$PROXY_DOMAIN"
echo ""

end_ts="$(date +%s)"
duration="$((end_ts - start_ts))"

PASSED_CHECKS="$((TOTAL_CHECKS - FAILED_CHECKS))"

echo "📋 Deployment Summary"
echo "====================="
echo "Checks passed: $PASSED_CHECKS/$TOTAL_CHECKS"
echo "Duration: ${duration}s"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo -e "${RED}Result: FAILED (${FAILED_CHECKS} checks failed)${NC}"
else
    echo -e "${GREEN}Result: PASSED${NC}"
fi

echo ""
echo -e "${YELLOW}Note:${NC} This script verifies availability and key responses only."
echo "For full CMS functionality, ensure:"
echo "  1. GitHub OAuth app is configured"
echo "  2. Worker secrets (GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET) are set"
echo "  3. Custom domains are properly configured in Cloudflare"
echo ""
echo "For detailed deployment instructions, see DEPLOYMENT-QUICKSTART.md"

if [ "$FAILED_CHECKS" -gt 0 ]; then
    exit 1
fi
