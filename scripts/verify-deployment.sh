#!/bin/bash

# Deployment Verification Script
# This script checks if all required components are properly deployed

set -e

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

# Function to check HTTP status
check_url() {
    local url=$1
    local name=$2
    
    echo -n "Checking $name ($url)... "
    
    if curl -s -f -I "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Function to check if content is accessible
check_content() {
    local url=$1
    local expected=$2
    local name=$3
    
    echo -n "Checking $name content... "
    
    if curl -s "$url" | grep -q "$expected"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

echo "📍 Testing Main Site"
echo "===================="
check_url "https://$MAIN_DOMAIN" "Main site"
check_url "https://$MAIN_DOMAIN/about" "About page"
check_url "https://$MAIN_DOMAIN/blog/welcome" "Blog post"
check_url "https://$MAIN_DOMAIN/admin/" "CMS admin interface"
echo ""

echo "🔐 Testing OAuth Proxy"
echo "======================"
check_url "https://$PROXY_DOMAIN" "OAuth proxy"
check_content "https://$PROXY_DOMAIN" "OAuth Proxy for Decap CMS" "OAuth proxy response"
echo ""

echo "🔧 Testing DNS Resolution"
echo "=========================="
echo -n "Resolving $MAIN_DOMAIN... "
if dig +short "$MAIN_DOMAIN" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi

echo -n "Resolving $PROXY_DOMAIN... "
if dig +short "$PROXY_DOMAIN" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo ""

echo "📋 Deployment Summary"
echo "====================="
echo -e "${YELLOW}Note:${NC} This script only verifies that URLs are accessible."
echo "For full CMS functionality, ensure:"
echo "  1. GitHub OAuth app is configured"
echo "  2. Worker secrets (OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET) are set"
echo "  3. Custom domains are properly configured in Cloudflare"
echo ""
echo "For detailed deployment instructions, see DEPLOYMENT-QUICKSTART.md"
