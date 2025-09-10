#!/bin/bash

# Test script to verify Claude Code headless mode works

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Testing Claude Code Headless Mode${NC}"
echo "=================================="

# Test 1: Basic headless execution
echo
echo "Test 1: Basic text output"
if claude -p "What is 2+2?" 2>/dev/null; then
    echo -e "${GREEN}✓ Basic headless mode works${NC}"
else
    echo -e "${RED}✗ Basic headless mode failed${NC}"
    exit 1
fi

# Test 2: JSON output
echo
echo "Test 2: JSON output format"
result=$(claude -p "What is the capital of France?" --output-format json 2>/dev/null || echo "{}")

if echo "$result" | grep -q '"result"'; then
    echo -e "${GREEN}✓ JSON output works${NC}"
    
    # Try to extract cost if jq is available
    if command -v jq &>/dev/null; then
        cost=$(echo "$result" | jq -r '.total_cost_usd // "unknown"')
        echo "  Cost: \$$cost"
    fi
else
    echo -e "${RED}✗ JSON output failed${NC}"
fi

# Test 3: Tool access
echo
echo "Test 3: WebSearch tool access"
if claude -p "Search for 'Rails 8 release date' and tell me what you find" \
    --allowedTools "WebSearch" \
    --output-format json 2>/dev/null | grep -q '"result"'; then
    echo -e "${GREEN}✓ WebSearch tool works${NC}"
else
    echo -e "${YELLOW}⚠ WebSearch tool may not be available${NC}"
fi

# Test 4: File operations
echo
echo "Test 4: Read tool access"
if claude -p "Read the README.md file and tell me how many lines it has" \
    --cwd "/Users/jeremy/Desktop/rails-8-claude-guide" \
    --allowedTools "Read" \
    --output-format json 2>/dev/null | grep -q '"result"'; then
    echo -e "${GREEN}✓ Read tool works${NC}"
else
    echo -e "${RED}✗ Read tool failed${NC}"
fi

# Test 5: GitHub integration
echo
echo "Test 5: GitHub CLI access"
if gh auth status &>/dev/null; then
    echo -e "${GREEN}✓ GitHub CLI is authenticated${NC}"
    
    # Test issue access
    if gh issue view 2 --repo jeremedia/rails-8-claude-guide &>/dev/null; then
        echo -e "${GREEN}✓ Can access GitHub issue #2${NC}"
    else
        echo -e "${YELLOW}⚠ Cannot access issue #2 (may not exist yet)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ GitHub CLI not authenticated${NC}"
fi

# Summary
echo
echo -e "${GREEN}Testing complete!${NC}"
echo
echo "If all tests passed, the automation should work correctly."
echo "Run the setup script to configure automated Rails research:"
echo "  ./scripts/setup_mac.sh"