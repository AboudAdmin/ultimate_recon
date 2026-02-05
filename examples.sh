#!/bin/bash

# ==========================================
# Quick Start Examples for Ultimate Recon
# ==========================================

echo "Ultimate Recon Framework - Quick Start Examples"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}These are example commands to get you started.${NC}"
echo -e "${CYAN}Replace 'example.com' with your target domain.${NC}"
echo ""

echo -e "${GREEN}1. Basic Scan (Recommended for first-time users)${NC}"
echo "   ./ultimate-recon.sh -d example.com"
echo ""

echo -e "${GREEN}2. View Help Message${NC}"
echo "   ./ultimate-recon.sh -h"
echo ""

echo -e "${GREEN}3. Custom Output Directory${NC}"
echo "   ./ultimate-recon.sh -d example.com -o my_scan_results"
echo ""

echo -e "${GREEN}4. High-Performance Scan (More threads)${NC}"
echo "   ./ultimate-recon.sh -d example.com -t 150"
echo ""

echo -e "${GREEN}5. Quiet Mode (Minimal output, good for scripts)${NC}"
echo "   ./ultimate-recon.sh -d example.com -q"
echo ""

echo -e "${GREEN}6. Skip Nuclei Scan (Faster, passive only)${NC}"
echo "   ./ultimate-recon.sh -d example.com --no-nuclei"
echo ""

echo -e "${GREEN}7. Complete Custom Example${NC}"
echo "   ./ultimate-recon.sh -d example.com -o bug_bounty -t 100 -q"
echo ""

echo "================================================"
echo ""
echo -e "${YELLOW}Installation Check:${NC}"
echo ""

# Check if script exists
if [[ -f "ultimate-recon.sh" ]]; then
    echo -e "${GREEN}✓${NC} ultimate-recon.sh found"
else
    echo -e "${RED}✗${NC} ultimate-recon.sh not found in current directory"
fi

# Check if executable
if [[ -x "ultimate-recon.sh" ]]; then
    echo -e "${GREEN}✓${NC} Script is executable"
else
    echo -e "${YELLOW}!${NC} Script is not executable. Run: chmod +x ultimate-recon.sh"
fi

echo ""
echo -e "${YELLOW}Required Tools:${NC}"

# Check for required tools
check_tool() {
    if command -v $1 &>/dev/null; then
        echo -e "${GREEN}✓${NC} $1 installed"
    else
        echo -e "${RED}✗${NC} $1 NOT installed"
        if [[ -n "$2" ]]; then
            echo "   Install: $2"
        fi
    fi
}

check_tool "subfinder" "go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
check_tool "httpx" "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
check_tool "curl"

echo ""
echo -e "${YELLOW}Optional Tools:${NC}"
check_tool "nuclei" "go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"

echo ""
echo "================================================"
echo -e "${CYAN}Ready to start? Try:${NC}"
echo -e "${YELLOW}./ultimate-recon.sh -h${NC}"
echo ""
