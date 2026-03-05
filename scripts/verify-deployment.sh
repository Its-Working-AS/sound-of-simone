#!/bin/bash

# Deployment Verification Script
# Checks required components for Sound of Simone deployment with root-cause diagnostics.

set -uo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

usage() {
  cat <<USAGE
Usage: ./scripts/verify-deployment.sh [--quick] [--help]

Options:
  --quick   Skip content-body checks (faster)
  --help    Show this help

Environment variables:
  MAIN_DOMAIN       Main site domain (default: soundofsimone.no)
  PROXY_DOMAIN      Decap proxy domain (default: decap.soundofsimone.no)
  CONNECT_TIMEOUT   Curl connect timeout in seconds (default: 5)
  MAX_TIME          Curl max request time in seconds (default: 15)
  RETRY_COUNT       Curl retry count (default: 2)
  RETRY_DELAY       Curl retry delay in seconds (default: 1)
USAGE
}

QUICK_MODE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick)
      QUICK_MODE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

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

classify_failure() {
  local exit_code=$1
  local http_code=$2

  if [ "$exit_code" -ne 0 ]; then
    case "$exit_code" in
      6)
        echo "DNS_RESOLUTION_FAILED"
        ;;
      7)
        echo "TCP_CONNECT_FAILED"
        ;;
      28)
        echo "TIMEOUT"
        ;;
      35)
        echo "TLS_HANDSHAKE_FAILED"
        ;;
      56)
        echo "NETWORK_RECEIVE_ERROR"
        ;;
      *)
        echo "CURL_ERROR_${exit_code}"
        ;;
    esac
    return
  fi

  case "$http_code" in
    2*) echo "OK" ;;
    301|302|307|308) echo "REDIRECT" ;;
    401|403) echo "AUTH_OR_ACCESS_DENIED" ;;
    404) echo "NOT_FOUND" ;;
    5*) echo "UPSTREAM_SERVER_ERROR" ;;
    *) echo "HTTP_${http_code}" ;;
  esac
}

check_url() {
  local url=$1
  local name=$2
  local tmpfile http_code curl_exit elapsed diagnosis

  tmpfile="$(mktemp)"
  http_code="$(curl "${curl_common_args[@]}" -o /dev/null -w "%{http_code}" -D "$tmpfile" "$url" 2>/dev/null)"
  curl_exit=$?
  elapsed="$(awk -F': ' 'tolower($1)=="server-timing"{print $2}' "$tmpfile" 2>/dev/null | head -n1)"
  rm -f "$tmpfile"

  diagnosis="$(classify_failure "$curl_exit" "$http_code")"

  printf -- "- %-28s %-45s " "$name" "($url)"

  if [ "$curl_exit" -eq 0 ] && [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
    echo -e "${GREEN}✓ OK${NC} [http=${http_code}, cause=${diagnosis}]"
    record_result 0
    return 0
  fi

  if [ -n "$elapsed" ]; then
    echo -e "${RED}✗ FAILED${NC} [http=${http_code:-000}, cause=${diagnosis}, server-timing=${elapsed}]"
  else
    echo -e "${RED}✗ FAILED${NC} [http=${http_code:-000}, cause=${diagnosis}]"
  fi

  record_result 1
  return 1
}

check_content() {
  local url=$1
  local expected=$2
  local name=$3
  local body

  printf -- "- %-28s %-45s " "$name" "($url)"

  if ! body="$(curl "${curl_common_args[@]}" "$url" 2>/dev/null)"; then
    echo -e "${RED}✗ FAILED${NC} [cause=CONTENT_FETCH_FAILED]"
    record_result 1
    return 1
  fi

  if printf '%s' "$body" | grep -q "$expected"; then
    echo -e "${GREEN}✓ OK${NC} [cause=CONTENT_MATCHED]"
    record_result 0
    return 0
  fi

  echo -e "${RED}✗ FAILED${NC} [cause=CONTENT_MISMATCH, expected=${expected}]"
  record_result 1
  return 1
}

check_dns() {
  local domain=$1
  local resolved

  printf -- "- %-28s " "DNS $domain"
  resolved="$(dig +short "$domain" | tr '\n' ' ' | sed 's/  */ /g')"
  if [ -n "$resolved" ]; then
    echo -e "${GREEN}✓ OK${NC} [records=$resolved]"
    record_result 0
    return 0
  fi

  echo -e "${RED}✗ FAILED${NC} [cause=NO_DNS_RECORDS]"
  record_result 1
  return 1
}

echo "🔍 Verifying deployment of Sound of Simone..."
echo -e "${BLUE}Mode:${NC} $([ "$QUICK_MODE" -eq 1 ] && echo "quick" || echo "full")"
echo "⏱️ Timeout config: connect=${CONNECT_TIMEOUT}s, max=${MAX_TIME}s, retries=${RETRY_COUNT}, retry-delay=${RETRY_DELAY}s"
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
if [ "$QUICK_MODE" -eq 0 ]; then
  check_content "https://$PROXY_DOMAIN/health" '"ok":true' "OAuth health body"
else
  echo "- OAuth health body             (skipped in --quick mode)"
fi
echo ""

echo "🔧 Testing DNS Resolution"
echo "========================="
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

if [ "$FAILED_CHECKS" -gt 0 ]; then
  exit 1
fi
