#!/bin/bash

# ==========================================
# Ultimate Recon Framework v2.0
# Advanced Bug Bounty Reconnaissance Tool
# Author: Abdullah (AboudAdmin)
# ==========================================

set -o pipefail  # Catch errors in pipelines

# ================== ENHANCED COLORS ==================
# Basic colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# Enhanced color palette (256-color)
BRAND_CYAN='\033[38;5;51m'
BRAND_PURPLE='\033[38;5;141m'
SUCCESS='\033[38;5;46m'
PROGRESS='\033[38;5;39m'
WARNING='\033[38;5;220m'
ERROR='\033[38;5;196m'
INFO='\033[38;5;153m'

# Text effects
DIM='\033[2m'
BOLD='\033[1m'
UNDER='\033[4m'

# Spinner frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# ================== GLOBAL VARIABLES ==================
DOMAIN=""
OUTPUT_DIR=""
THREADS=50
QUIET_MODE=false
SKIP_NUCLEI=false
START_TIME=""
END_TIME=""
TOTAL_SUBDOMAINS=0
TOTAL_LIVE=0
TOTAL_VULNS=0
TOTAL_URLS=0

# Tool arrays
REQUIRED_TOOLS=(subfinder httpx curl sort uniq grep sed wc)
OPTIONAL_TOOLS=(nuclei)

# ================== DASHBOARD VARIABLES ==================
USE_DASHBOARD=true
DASH_WIDTH=80
DASH_HEIGHT=25
DASH_CURRENT_PHASE=0
DASH_PHASE_NAME="Initializing"
DASH_ACTION="Starting reconnaissance..."
DASH_STATUS="idle"
DASH_SUBDOMAINS=0
DASH_LIVE=0
DASH_VULNS=0
DASH_URLS=0
DASH_REFRESH_PID=0
DASH_ACTIVE=false
USE_COMPACT_MODE=false

# Box drawing characters
BOX_TL="╔"
BOX_TR="╗"
BOX_BL="╚"
BOX_BR="╝"
BOX_H="═"
BOX_V="║"
BOX_VR="╠"
BOX_VL="╣"
BOX_HU="╩"
BOX_HD="╦"
BOX_PLUS="╬"

# ================== DASHBOARD FUNCTIONS ==================

# Detect terminal capabilities
detect_terminal_capabilities() {
    # Get terminal size
    if command -v tput &>/dev/null; then
        DASH_WIDTH=$(tput cols 2>/dev/null || echo 80)
        DASH_HEIGHT=$(tput lines 2>/dev/null || echo 25)
    else
        DASH_WIDTH=80
        DASH_HEIGHT=25
    fi
    
    # Use compact mode for narrow terminals
    if [[ $DASH_WIDTH -lt 85 ]]; then
        USE_COMPACT_MODE=true
    fi
    
    # Check color support
    if [[ ! -t 1 ]] || ! command -v tput &>/dev/null; then
        # Fallback to ASCII box drawing
        BOX_TL="+"
        BOX_TR="+"
        BOX_BL="+"
        BOX_BR="+"
        BOX_H="-"
        BOX_V="|"
        BOX_VR="+"
        BOX_VL="+"
        BOX_HU="+"
        BOX_HD="+"
        BOX_PLUS="+"
    fi
}

# Generate progress bar
generate_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-20}
    local label="${4:-}"
    
    if [[ $total -eq 0 ]]; then
        printf "%-15s │ %s 0%% │ --" "$label" "$(printf '%.0s░' {1..20})"
        return
    fi
    
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    local bar=""
    bar+=$(printf "%.0s█" $(seq 1 $filled) 2>/dev/null)
    bar+=$(printf "%.0s░" $(seq 1 $empty) 2>/dev/null)
    
    printf "%-15s │ %s %3d%% │ %'d / %'d" "$label" "$bar" "$percentage" "$current" "$total"
}

# Generate simple progress bar (for metrics without total)
generate_simple_bar() {
    local count=$1
    local label="$2"
    local max_width=20
    
    # Scale based on logarithm for better visualization
    local filled=0
    if [[ $count -gt 0 ]]; then
        # Simple scaling: show something for any count
        filled=$(( (count > max_width) ? max_width : count ))
        if [[ $count -gt 100 ]]; then
            filled=$((max_width * 3 / 4))  # 75% for large numbers
        elif [[ $count -gt 50 ]]; then
            filled=$((max_width / 2))  # 50% for medium numbers
        fi
    fi
    
    local empty=$((max_width - filled))
    local bar=""
    bar+=$(printf "%.0s█" $(seq 1 $filled) 2>/dev/null)
    bar+=$(printf "%.0s░" $(seq 1 $empty) 2>/dev/null)
    
    printf "%-15s │ %s      │ %'d discovered" "$label" "$bar" "$count"
}

# Get status indicator
get_status_indicator() {
    case $DASH_STATUS in
        "active")
            echo -e "${SUCCESS}●●●${NC} Stable"
            ;;
        "processing")
            echo -e "${PROGRESS}●●○${NC} Processing"
            ;;
        "warning")
            echo -e "${WARNING}●○○${NC} Warning"
            ;;
        "error")
            echo -e "${ERROR}○○○${NC} Error"
            ;;
        *)
            echo -e "${DIM}○○○${NC} Idle"
            ;;
    esac
}

# Get phase badge
get_phase_badge() {
    local phase=$1
    local current=$DASH_CURRENT_PHASE
    
    if [[ $phase -lt $current ]]; then
        echo -e "${SUCCESS}✔${NC}"
    elif [[ $phase -eq $current ]]; then
        echo -e "${PROGRESS}⚡${NC}"
    else
        echo -e "${DIM}○${NC}"
    fi
}

# Format elapsed time
format_elapsed_time() {
    local start_epoch=$(date -d "$START_TIME" +%s 2>/dev/null || echo 0)
    local current_epoch=$(date +%s)
    local elapsed=$((current_epoch - start_epoch))
    
    local hours=$((elapsed / 3600))
    local minutes=$(( (elapsed % 3600) / 60 ))
    local seconds=$((elapsed % 60))
    
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Calculate request rate (simple estimation)
calculate_rate() {
    local total_items=$((DASH_SUBDOMAINS + DASH_LIVE + DASH_URLS))
    local start_epoch=$(date -d "$START_TIME" +%s 2>/dev/null || echo 0)
    local current_epoch=$(date +%s)
    local elapsed=$((current_epoch - start_epoch))
    
    if [[ $elapsed -gt 0 ]]; then
        echo $((total_items / elapsed))
    else
        echo "0"
    fi
}

# Draw full dashboard
draw_full_dashboard() {
    local elapsed=$(format_elapsed_time)
    local rate=$(calculate_rate)
    
    # Clear screen and move to top
    clear
    
   # Top border with title
    echo -e "${BRAND_CYAN}$BOX_TL$(printf '%.0s$BOX_H' {1..25})${NC} ${BOLD}ULTIMATE RECON DASHBOARD${NC} ${BRAND_CYAN}$(printf '%.0s$BOX_H' {1..25})$BOX_TR${NC}"
    
    # Target and phase info
    printf "${BRAND_CYAN}$BOX_V${NC} ${INFO}🎯 Target:${NC} %-20s ${INFO}Phase:${NC} %-25s ${INFO}⏱  Time:${NC} %8s ${BRAND_CYAN}$BOX_V${NC}\n" "$DOMAIN" "$DASH_PHASE_NAME" "$elapsed"
    
    # Separator
    echo -e "${BRAND_CYAN}$BOX_VR$(printf '%.0s$BOX_H' {1..78})$BOX_VL${NC}"
    
    # Progress section
    echo -e "${BRAND_CYAN}$BOX_V${NC}                                                                              ${BRAND_CYAN}$BOX_V${NC}"
    echo -e "${BRAND_CYAN}$BOX_V${NC}  ${BOLD}📊 RECONNAISSANCE PROGRESS${NC}                                                  ${BRAND_CYAN}$BOX_V${NC}"
    
    # Progress bars
    if [[ $DASH_SUBDOMAINS -gt 0 || $DASH_CURRENT_PHASE -ge 1 ]]; then
        echo -e "${BRAND_CYAN}$BOX_V${NC}  $(generate_simple_bar "$DASH_SUBDOMAINS" "Subdomains")      ${BRAND_CYAN}$BOX_V${NC}"
    fi
    if [[ $DASH_LIVE -gt 0 || $DASH_CURRENT_PHASE -ge 2 ]]; then
        echo -e "${BRAND_CYAN}$BOX_V${NC}  $(generate_simple_bar "$DASH_LIVE" "Live Hosts")      ${BRAND_CYAN}$BOX_V${NC}"
    fi
    if [[ $DASH_URLS -gt 0 || $DASH_CURRENT_PHASE -ge 4 ]]; then
        echo -e "${BRAND_CYAN}$BOX_V${NC}  $(generate_simple_bar "$DASH_URLS" "Wayback URLs")      ${BRAND_CYAN}$BOX_V${NC}"
    fi
    if [[ $DASH_VULNS -gt 0 || $DASH_CURRENT_PHASE -eq 3 ]]; then
        echo -e "${BRAND_CYAN}$BOX_V${NC}  $(generate_simple_bar "$DASH_VULNS" "Vulnerabilities")      ${BRAND_CYAN}$BOX_V${NC}"
    fi
    
    echo -e "${BRAND_CYAN}$BOX_V${NC}                                                                              ${BRAND_CYAN}$BOX_V${NC}"
    
    # Metrics section
    echo -e "${BRAND_CYAN}$BOX_V${NC}  ${BOLD}⚡ REAL-TIME METRICS${NC}                                                        ${BRAND_CYAN}$BOX_V${NC}"
    printf "${BRAND_CYAN}$BOX_V${NC}  Rate: %3d req/s  │  Threads: %-3d  │  Status: %-20s  ${BRAND_CYAN}$BOX_V${NC}\n" "$rate" "$THREADS" "$(get_status_indicator)"
    
    echo -e "${BRAND_CYAN}$BOX_V${NC}                                                                              ${BRAND_CYAN}$BOX_V${NC}"
    
    # Current action
    local action_display="${DASH_ACTION:0:74}"
    printf "${BRAND_CYAN}$BOX_V${NC}  ${PROGRESS}🔍${NC} %-72s ${BRAND_CYAN}$BOX_V${NC}\n" "$action_display"
    
    echo -e "${BRAND_CYAN}$BOX_V${NC}                                                                              ${BRAND_CYAN}$BOX_V${NC}"
    
    # Phase timeline
    echo -e "${BRAND_CYAN}$BOX_VR$(printf '%.0s$BOX_H' {1..78})$BOX_VL${NC}"
    printf "${BRAND_CYAN}$BOX_V${NC}  Phase 1: %s  Phase 2: %s  Phase 3: %s  Phase 4: %s                       ${BRAND_CYAN}$BOX_V${NC}\n" \
        "$(get_phase_badge 1)" "$(get_phase_badge 2)" "$(get_phase_badge 3)" "$(get_phase_badge 4)"
    
    # Bottom border
    echo -e "${BRAND_CYAN}$BOX_BL$(printf '%.0s$BOX_H' {1..78})$BOX_BR${NC}"
}

# Draw compact dashboard
draw_compact_dashboard() {
    local elapsed=$(format_elapsed_time)
    
    clear
    
    echo -e "${BRAND_CYAN}┌─────── ULTIMATE RECON ────────┐${NC}"
    printf "${BRAND_CYAN}│${NC} Target: %-22s${BRAND_CYAN}│${NC}\n" "$DOMAIN"
    printf "${BRAND_CYAN}│${NC} Phase: %-23s${BRAND_CYAN}│${NC}\n" "$DASH_PHASE_NAME"
    printf "${BRAND_CYAN}│${NC} Time: %-24s${BRAND_CYAN}│${NC}\n" "$elapsed"
    echo -e "${BRAND_CYAN}├───────────────────────────────┤${NC}"
    
    if [[ $DASH_SUBDOMAINS -gt 0 ]]; then
        printf "${BRAND_CYAN}│${NC} Subdomains: %-18d${BRAND_CYAN}│${NC}\n" "$DASH_SUBDOMAINS"
    fi
    if [[ $DASH_LIVE -gt 0 ]]; then
        printf "${BRAND_CYAN}│${NC} Live Hosts: %-18d${BRAND_CYAN}│${NC}\n" "$DASH_LIVE"
    fi
    if [[ $DASH_URLS -gt 0 ]]; then
        printf "${BRAND_CYAN}│${NC} Wayback URLs: %-16d${BRAND_CYAN}│${NC}\n" "$DASH_URLS"
    fi
    if [[ $DASH_VULNS -gt 0 ]]; then
        printf "${BRAND_CYAN}│${NC} Vulns: %-23d${BRAND_CYAN}│${NC}\n" "$DASH_VULNS"
    fi
    
    echo -e "${BRAND_CYAN}├───────────────────────────────┤${NC}"
    local action_short="${DASH_ACTION:0:30}"
    printf "${BRAND_CYAN}│${NC} ${PROGRESS}⚡${NC} %-27s${BRAND_CYAN}│${NC}\n" "$action_short"
    printf "${BRAND_CYAN}│${NC} Status: %-22s${BRAND_CYAN}│${NC}\n" "$(get_status_indicator)"
    echo -e "${BRAND_CYAN}└───────────────────────────────┘${NC}"
}

# Main dashboard draw function
draw_dashboard() {
    if [[ "$QUIET_MODE" == "true" ]] || [[ "$USE_DASHBOARD" == "false" ]]; then
        return
    fi
    
    if [[ "$USE_COMPACT_MODE" == "true" ]]; then
        draw_compact_dashboard
    else
        draw_full_dashboard
    fi
}

# Update dashboard data
update_dashboard_data() {
    # Read current counts from files
    if [[ -f "subdomains/all.txt" ]]; then
        DASH_SUBDOMAINS=$(wc -l < "subdomains/all.txt" 2>/dev/null || echo "$DASH_SUBDOMAINS")
    fi
    
    if [[ -f "subdomains/live.txt" ]]; then
        DASH_LIVE=$(wc -l < "subdomains/live.txt" 2>/dev/null || echo "$DASH_LIVE")
    fi
    
    if [[ -f "urls/wayback_all.txt" ]]; then
        DASH_URLS=$(wc -l < "urls/wayback_all.txt" 2>/dev/null || echo "$DASH_URLS")
    fi
    
    if [[ -f "nuclei/results.txt" ]]; then
        DASH_VULNS=$(wc -l < "nuclei/results.txt" 2>/dev/null || echo "$DASH_VULNS")
    fi
}

# Background dashboard refresh loop
dashboard_refresh_loop() {
    while [[ "$DASH_ACTIVE" == "true" ]]; do
        update_dashboard_data
        draw_dashboard
        sleep 2  # Refresh every 2 seconds
    done
}

# Start dashboard
start_dashboard() {
    if [[ "$QUIET_MODE" == "true" ]]; then
        return
    fi
    
    detect_terminal_capabilities
    DASH_ACTIVE=true
    
    # Hide cursor
    tput civis 2>/dev/null
    
    # Start background refresh
    dashboard_refresh_loop &
    DASH_REFRESH_PID=$!
}

# Stop dashboard
stop_dashboard() {
    DASH_ACTIVE=false
    
    if [[ $DASH_REFRESH_PID -gt 0 ]]; then
        kill $DASH_REFRESH_PID 2>/dev/null
        wait $DASH_REFRESH_PID 2>/dev/null
    fi
    
    # Show cursor
    tput cnorm 2>/dev/null
    
    # Clear screen one final time
    if [[ "$QUIET_MODE" == "false" ]]; then
        clear
    fi
}

# Update dashboard phase
set_dashboard_phase() {
    local phase_num=$1
    local phase_name="$2"
    local action="$3"
    
    DASH_CURRENT_PHASE=$phase_num
    DASH_PHASE_NAME="$phase_name"
    DASH_ACTION="$action"
    DASH_STATUS="active"
}

#

# ================== UX HELPER FUNCTIONS ==================

# Smooth transition delay
transition_delay() {
    sleep 0.15
}

# Section separator
print_separator() {
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

# Section header
print_section() {
    local title="$1"
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo ""
        echo -e "${BRAND_CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${BRAND_CYAN}║${NC}  ${BOLD}${BRAND_PURPLE}$title${NC}"
        echo -e "${BRAND_CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""
        transition_delay
    fi
}

# Animated spinner with message
show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local i=0
    
    if [[ "$QUIET_MODE" == "true" ]]; then
        wait $pid
        return
    fi
    
    tput civis  # Hide cursor
    while kill -0 $pid 2>/dev/null; do
        printf "\r${PROGRESS}${SPINNER_FRAMES[$i]}${NC} $message"
        i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep $delay
    done
    printf "\r"
    tput cnorm  # Show cursor
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local width=40
    
    if [[ "$QUIET_MODE" == "true" ]] || [[ $total -eq 0 ]]; then
        return
    fi
    
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${PROGRESS}▐${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${PROGRESS}▌${NC} ${BOLD}%3d%%${NC} | $message" $percentage
}

# Milestone celebration
celebrate_milestone() {
    local percentage=$1
    local message="$2"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        case $percentage in
            25)
                echo -e "${SUCCESS}⚡ 25%${NC} ${DIM}→ $message${NC}"
                ;;
            50)
                echo -e "${SUCCESS}🔥 50%${NC} ${DIM}→ $message${NC}"
                ;;
            75)
                echo -e "${SUCCESS}💎 75%${NC} ${DIM}→ $message${NC}"
                ;;
            100)
                echo -e "${SUCCESS}✨ 100%${NC} ${DIM}→ $message${NC}"
                ;;
        esac
        transition_delay
    fi
}

# Countdown animation
countdown() {
    local seconds=$1
    local message="$2"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        for ((i=seconds; i>=1; i--)); do
            echo -e "${INFO}⏳ $message in ${BOLD}$i${NC}..."
            sleep 1
        done
        echo -e "${SUCCESS}🚀 Launching...${NC}"
    fi
}

# ================== ENHANCED BANNER ==================
print_banner() {
    if [[ "$QUIET_MODE" == "false" ]]; then
        clear
        echo -e "${BRAND_CYAN}"
        cat <<'EOF'
    ██╗   ██╗██╗  ████████╗██╗███╗   ███╗ █████╗ ████████╗███████╗
    ██║   ██║██║  ╚══██╔══╝██║████╗ ████║██╔══██╗╚══██╔══╝██╔════╝
    ██║   ██║██║     ██║   ██║██╔████╔██║███████║   ██║   █████╗  
    ██║   ██║██║     ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  
    ╚██████╔╝███████╗██║   ██║██║ ╚═╝ ██║██║  ██║   ██║   ███████╗
     ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
        ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗              
        ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║              
        ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║              
        ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║              
        ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║              
        ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝              
EOF
        echo -e "${NC}"
        echo -e "        ${BRAND_PURPLE}${BOLD}v2.0${NC} ${DIM}|${NC} ${GRAY}Advanced Reconnaissance Framework${NC}"
        echo -e "        ${DIM}by Abdullah (AboudAdmin)${NC}"
        echo ""
        transition_delay
    fi
}

# Victory banner for completion
print_victory_banner() {
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo ""
        echo -e "${SUCCESS}"
        cat <<'EOF'
    ╔══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║        ✨  RECONNAISSANCE COMPLETED  ✨            ║
    ║                                                      ║
EOF
        echo -e "    ║              ${BOLD}🎯 TARGET: $DOMAIN${NC}${SUCCESS}                 ║"
        cat <<'EOF'
    ║                                                      ║
    ╚══════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"
        transition_delay
    fi
}

# ================== ENHANCED LOGGING ==================
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [INFO] $1"
    
    echo "$message" >> "logs/scan.log"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${INFO}⚡${NC} $1"
    fi
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [SUCCESS] $1"
    
    echo "$message" >> "logs/scan.log"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${SUCCESS}✔${NC} $1"
    fi
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [WARNING] $1"
    
    echo "$message" >> "logs/scan.log"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${WARNING}⚠${NC} $1"
    fi
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [ERROR] $1"
    
    echo "$message" >> "logs/scan.log"
    echo "$message" >> "logs/errors.log"
    
    echo -e "${ERROR}✗ ERROR:${NC} $1" >&2
}

# Special engagement messages
engage_msg() {
    local message="$1"
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${BRAND_PURPLE}🎯${NC} ${DIM}$message${NC}"
        transition_delay
    fi
}

# ================== HELP FUNCTION ==================
show_help() {
    cat <<EOF
${BRAND_CYAN}${BOLD}Ultimate Recon Framework v2.0${NC}

${YELLOW}Usage:${NC}
  ./ultimate-recon.sh [OPTIONS]

${YELLOW}Required:${NC}
  -d, --domain DOMAIN       Target domain to scan

${YELLOW}Optional:${NC}
  -o, --output DIR          Custom output directory (default: recon_<domain>)
  -t, --threads NUM         Number of threads (default: 50)
  -q, --quiet               Minimal console output
  --no-nuclei               Skip Nuclei vulnerability scan
  -h, --help                Show this help message

${YELLOW}Examples:${NC}
  ./ultimate-recon.sh -d example.com
  ./ultimate-recon.sh -d example.com -o my_scan -t 100
  ./ultimate-recon.sh -d example.com --quiet --no-nuclei

${YELLOW}Required Tools:${NC}
  - subfinder (subdomain enumeration)
  - httpx (HTTP probing)
  - curl, sort, uniq, grep, sed, wc (standard utilities)

${YELLOW}Optional Tools:${NC}
  - nuclei (vulnerability scanning)

EOF
    exit 0
}

# ================== INPUT VALIDATION ==================
sanitize_domain() {
    local domain=$1
    
    domain=$(echo "$domain" | sed 's~http[s]*://~~')
    domain=$(echo "$domain" | sed 's~/.*~~')
    
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $domain"
        echo -e "${RED}Please provide a valid domain (e.g., example.com)${NC}"
        exit 1
    fi
    
    echo "$domain"
}

validate_threads() {
    local threads=$1
    
    if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
        log_error "Thread count must be a number"
        exit 1
    fi
    
    if [[ "$threads" -lt 1 || "$threads" -gt 500 ]]; then
        log_error "Thread count must be between 1 and 500"
        exit 1
    fi
    
    echo "$threads"
}

# ================== ARGUMENT PARSING ==================
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        show_help
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --no-nuclei)
                SKIP_NUCLEI=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Error: Domain is required${NC}"
        echo "Use: ./ultimate-recon.sh -d example.com"
        exit 1
    fi
    
    DOMAIN=$(sanitize_domain "$DOMAIN")
    THREADS=$(validate_threads "$THREADS")
    
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="recon_$DOMAIN"
    fi
}

# ================== TOOL CHECKING ==================
check_required_tools() {
    local missing_tools=()
    
    engage_msg "Initializing reconnaissance suite..."
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${ERROR}✗ Missing required tools:${NC}\n"
        
        for tool in "${missing_tools[@]}"; do
            echo -e "${YELLOW}  - $tool${NC}"
            
            case $tool in
                subfinder)
                    echo -e "${DIM}    Install: go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest${NC}"
                    ;;
                httpx)
                    echo -e "${DIM}    Install: go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest${NC}"
                    ;;
                *)
                    echo -e "${DIM}    Install via your package manager${NC}"
                    ;;
            esac
            echo ""
        done
        
        exit 1
    fi
    
    log_success "All required tools ready"
}

check_optional_tools() {
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warning "Optional tool '$tool' not found - related features will be skipped"
            
            case $tool in
                nuclei)
                    SKIP_NUCLEI=true
                    echo -e "${DIM}    Install: go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest${NC}"
                    ;;
            esac
        fi
    done
}

get_tool_version() {
    local tool=$1
    local version=""
    
    if command -v "$tool" &>/dev/null; then
        case $tool in
            subfinder)
                version=$(subfinder -version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' | head -1)
                ;;
            httpx)
                version=$(httpx -version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' | head -1)
                ;;
            nuclei)
                version=$(nuclei -version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' | head -1)
                ;;
            *)
                version="installed"
                ;;
        esac
    else
        version="not installed"
    fi
    
    echo "$version"
}

# ================== SETUP FUNCTIONS ==================
setup_directories() {
    engage_msg "Preparing reconnaissance workspace..."
    
    mkdir -p "$OUTPUT_DIR"/{subdomains,urls,nuclei,logs,meta}
    
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_error "Failed to create output directory: $OUTPUT_DIR"
        exit 1
    fi
    
    cd "$OUTPUT_DIR" || exit 1
    
    log_success "Workspace initialized: $OUTPUT_DIR"
}

# ================== RECONNAISSANCE FUNCTIONS ==================
enumerate_subdomains() {
    print_section "📡 Phase 1: Infrastructure Discovery"
    
    engage_msg "Mapping attack surface..."
    log_info "Enumerating subdomains for $DOMAIN"
    
    # Run subfinder in background
    subfinder -d "$DOMAIN" -silent -o subdomains/all.txt 2>> logs/errors.log &
    local pid=$!
    
    # Show spinner
    show_spinner $pid "🔍 Discovering subdomains..."
    wait $pid
    
    if [[ -f subdomains/all.txt ]]; then
        sort -u subdomains/all.txt -o subdomains/all.txt
        TOTAL_SUBDOMAINS=$(wc -l < subdomains/all.txt 2>/dev/null || echo "0")
        
        echo ""  # New line after spinner
        if [[ $TOTAL_SUBDOMAINS -gt 0 ]]; then
            log_success "Found ${BOLD}$TOTAL_SUBDOMAINS${NC} subdomains"
            engage_msg "Nice! Attack surface expanded"
        else
            log_warning "No subdomains discovered"
        fi
        return 0
    else
        log_error "Subdomain enumeration failed"
        return 1
    fi
}

probe_live_hosts() {
    print_section "⚡ Phase 2: Active Host Detection"
    
    if [[ ! -f subdomains/all.txt ]]; then
        log_error "No subdomains file found. Skipping host probing."
        return 1
    fi
    
    local subdomain_count=$(wc -l < subdomains/all.txt)
    
    if [[ "$subdomain_count" -eq 0 ]]; then
        log_warning "No subdomains to probe"
        return 1
    fi
    
    engage_msg "Detecting active infrastructure..."
    log_info "Probing $subdomain_count potential hosts"
    
    # Run httpx in background
    cat subdomains/all.txt | httpx -silent -threads "$THREADS" -o subdomains/live.txt 2>> logs/errors.log &
    local pid=$!
    
    # Show spinner
    show_spinner $pid "⚡ Analyzing network endpoints..."
    wait $pid
    
    if [[ -f subdomains/live.txt ]]; then
        sort -u subdomains/live.txt -o subdomains/live.txt
        TOTAL_LIVE=$(wc -l < subdomains/live.txt 2>/dev/null || echo "0")
        
        echo ""
        if [[ $TOTAL_LIVE -gt 0 ]]; then
            log_success "Discovered ${BOLD}$TOTAL_LIVE${NC} live hosts"
            celebrate_milestone 50 "Infrastructure fingerprinted"
        else
            log_warning "No live hosts found"
        fi
        return 0
    else
        log_warning "No live hosts detected"
        touch subdomains/live.txt
        return 1
    fi
}

run_nuclei_scan() {
    if [[ "$SKIP_NUCLEI" == "true" ]]; then
        log_warning "Nuclei scan skipped"
        touch nuclei/results.txt
        return 0
    fi
    
    if [[ ! -f subdomains/live.txt ]]; then
        log_warning "No live hosts file found. Skipping Nuclei scan."
        touch nuclei/results.txt
        return 1
    fi
    
    local live_count=$(wc -l < subdomains/live.txt)
    
    if [[ "$live_count" -eq 0 ]]; then
        log_warning "No live hosts to scan"
        touch nuclei/results.txt
        return 1
    fi
    
    print_section "🧨 Phase 3: Security Assessment"
    
    engage_msg "Preparing vulnerability scanner..."
    countdown 3 "Nuclei scan starting"
    
    log_info "Analyzing $live_count hosts for vulnerabilities"
    
    # Run Nuclei
    nuclei -l subdomains/live.txt \
        -severity critical,high,medium \
        -rate-limit 150 \
        -timeout 10 \
        -bulk-size 25 \
        -stats -si 10 \
        -retries 1 \
        -silent \
        -o nuclei/results.txt \
        2>> logs/errors.log &
    local pid=$!
    
    show_spinner $pid "🔬 Deep security analysis in progress..."
    wait $pid
    
    local vuln_count=0
    if [[ -f nuclei/results.txt ]]; then
        vuln_count=$(wc -l < nuclei/results.txt 2>/dev/null || echo "0")
    fi
    
    TOTAL_VULNS=$vuln_count
    
    echo ""
    if [[ $vuln_count -gt 0 ]]; then
        log_success "Security assessment complete - ${BOLD}$vuln_count${NC} findings discovered"
        celebrate_milestone 75 "Vulnerabilities cataloged"
    else
        log_success "Security assessment complete - No major findings"
    fi
}

fetch_wayback_urls() {
    print_section "🕰️  Phase 4: Historical Data Collection"
    
    engage_msg "Excavating archived intelligence..."
    log_info "Fetching historical URLs from Wayback Machine"
    
    curl -s "https://web.archive.org/cdx/search/cdx?url=*.$DOMAIN/*&output=text&fl=original&collapse=urlkey" \
        -o urls/wayback_all.txt 2>> logs/errors.log &
    local pid=$!
    
    show_spinner $pid "🌐 Mining archived endpoints..."
    wait $pid
    
    if [[ -f urls/wayback_all.txt ]]; then
        sort -u urls/wayback_all.txt -o urls/wayback_all.txt
        TOTAL_URLS=$(wc -l < urls/wayback_all.txt 2>/dev/null || echo "0")
        
        grep -Ei "\?|\.php|\.aspx|\.jsp|\.json|\.api" urls/wayback_all.txt > urls/wayback_params.txt 2>/dev/null || touch urls/wayback_params.txt
        
        local param_count=$(wc -l < urls/wayback_params.txt 2>/dev/null || echo "0")
        
        echo ""
        if [[ $TOTAL_URLS -gt 0 ]]; then
            log_success "Collected ${BOLD}$TOTAL_URLS${NC} historical URLs (${BOLD}$param_count${NC} with parameters)"
            celebrate_milestone 100 "Reconnaissance complete!"
        else
            log_warning "No archived URLs found"
        fi
        return 0
    else
        log_error "Failed to fetch Wayback URLs"
        touch urls/wayback_all.txt urls/wayback_params.txt
        return 1
    fi
}

# ================== METADATA COLLECTION ==================
collect_metadata() {
    engage_msg "Compiling intelligence report..."
    
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    local start_seconds=$(date -d "$START_TIME" +%s 2>/dev/null || date +%s)
    local end_seconds=$(date -d "$END_TIME" +%s 2>/dev/null || date +%s)
    local duration=$((end_seconds - start_seconds))
    local duration_formatted="${duration}s"
    
    if [[ $duration -ge 60 ]]; then
        duration_formatted="$((duration / 60))m $((duration % 60))s"
    fi
    
    local subfinder_ver=$(get_tool_version "subfinder")
    local httpx_ver=$(get_tool_version "httpx")
    local nuclei_ver=$(get_tool_version "nuclei")
    
    cat > meta/info.txt <<EOF
Target Domain: $DOMAIN
Output Directory: $OUTPUT_DIR
Threads: $THREADS

Scan Timeline:
  Started: $START_TIME
  Ended: $END_TIME
  Duration: $duration_formatted

Statistics:
  Subdomains Found: $TOTAL_SUBDOMAINS
  Live Hosts: $TOTAL_LIVE
  Vulnerabilities: $TOTAL_VULNS
  Wayback URLs: $TOTAL_URLS

Tool Versions:
  subfinder: $subfinder_ver
  httpx: $httpx_ver
  nuclei: $nuclei_ver

Configuration:
  Quiet Mode: $QUIET_MODE
  Skip Nuclei: $SKIP_NUCLEI
EOF
    
    log_success "Metadata compiled"
}

# ================== HTML REPORT GENERATION ==================
generate_html_report() {
    engage_msg "Generating interactive report..."
    
    local REPORT="report.html"
    
    local subdomain_count=$(wc -l < subdomains/all.txt 2>/dev/null || echo "0")
    local live_count=$(wc -l < subdomains/live.txt 2>/dev/null || echo "0")
    local wayback_count=$(wc -l < urls/wayback_all.txt 2>/dev/null || echo "0")
    local param_count=$(wc -l < urls/wayback_params.txt 2>/dev/null || echo "0")
    local vuln_count=$(wc -l < nuclei/results.txt 2>/dev/null || echo "0")
    
    local start_seconds=$(date -d "$START_TIME" +%s 2>/dev/null || date +%s)
    local end_seconds=$(date -d "$END_TIME" +%s 2>/dev/null || date +%s)
    local duration=$((end_seconds - start_seconds))
    local duration_formatted="${duration}s"
    if [[ $duration -ge 60 ]]; then
        duration_formatted="$((duration / 60))m $((duration % 60))s"
    fi
    
    local subfinder_ver=$(get_tool_version "subfinder")
    local httpx_ver=$(get_tool_version "httpx")
    local nuclei_ver=$(get_tool_version "nuclei")
    
    cat > "$REPORT" <<'EOF_HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reconnaissance Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: #e5e7eb;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            padding: 20px;
            line-height: 1.6;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        h1 {
            color: #38bdf8;
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 0 0 20px rgba(56, 189, 248, 0.3);
        }
        
        h2 {
            color: #22c55e;
            font-size: 1.8em;
            margin: 30px 0 15px 0;
            padding-bottom: 10px;
            border-bottom: 2px solid #334155;
        }
        
        .header {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 30px;
            border: 1px solid #334155;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
        }
        
        .meta-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .meta-item {
            background: #020617;
            padding: 15px;
            border-radius: 10px;
            border-left: 3px solid #38bdf8;
        }
        
        .meta-label {
            color: #94a3b8;
            font-size: 0.85em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .meta-value {
            color: #e5e7eb;
            font-size: 1.1em;
            font-weight: 600;
            margin-top: 5px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            border: 1px solid #334155;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(56, 189, 248, 0.2);
        }
        
        .stat-number {
            font-size: 3em;
            font-weight: bold;
            background: linear-gradient(135deg, #22c55e 0%, #38bdf8 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .stat-label {
            color: #94a3b8;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 1px;
            margin-top: 10px;
        }
        
        .section {
            background: #020617;
            padding: 25px;
            margin-bottom: 25px;
            border-radius: 15px;
            border: 1px solid #334155;
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.3);
        }
        
        .collapsible {
            cursor: pointer;
            user-select: none;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .collapsible:hover {
            color: #38bdf8;
        }
        
        .collapsible::after {
            content: '▼';
            font-size: 0.8em;
            transition: transform 0.3s ease;
        }
        
        .collapsible.active::after {
            transform: rotate(180deg);
        }
        
        .content {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease;
        }
        
        .content.active {
            max-height: 5000px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        
        th {
            background: #1e293b;
            color: #22c55e;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.85em;
            letter-spacing: 1px;
        }
        
        td {
            padding: 12px;
            border-bottom: 1px solid #334155;
            font-size: 0.9em;
            word-break: break-all;
        }
        
        tr:hover {
            background: rgba(56, 189, 248, 0.05);
        }
        
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #64748b;
            font-style: italic;
        }
        
        .footer {
            text-align: center;
            margin-top: 50px;
            padding: 20px;
            color: #64748b;
            font-size: 0.9em;
        }
        
        @media (max-width: 768px) {
            .stats-grid {
                grid-template-columns: 1fr;
            }
            
            .meta-info {
                grid-template-columns: 1fr;
            }
            
            h1 {
                font-size: 1.8em;
            }
            
            .stat-number {
                font-size: 2em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 Reconnaissance Report</h1>
EOF_HEADER

    cat >> "$REPORT" <<EOF
            <div class="meta-info">
                <div class="meta-item">
                    <div class="meta-label">Target Domain</div>
                    <div class="meta-value">$DOMAIN</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Scan Started</div>
                    <div class="meta-value">$START_TIME</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Scan Completed</div>
                    <div class="meta-value">$END_TIME</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Duration</div>
                    <div class="meta-value">$duration_formatted</div>
                </div>
            </div>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-number">$subdomain_count</div>
                <div class="stat-label">Subdomains</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$live_count</div>
                <div class="stat-label">Live Hosts</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$wayback_count</div>
                <div class="stat-label">Wayback URLs</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$vuln_count</div>
                <div class="stat-label">Findings</div>
            </div>
        </div>

        <div class="section">
            <h2 class="collapsible">Tool Versions</h2>
            <div class="content">
                <table>
                    <tr><th>Tool</th><th>Version</th></tr>
                    <tr><td>subfinder</td><td>$subfinder_ver</td></tr>
                    <tr><td>httpx</td><td>$httpx_ver</td></tr>
                    <tr><td>nuclei</td><td>$nuclei_ver</td></tr>
                </table>
            </div>
        </div>

        <div class="section">
            <h2 class="collapsible active">Live Hosts ($live_count)</h2>
            <div class="content active">
EOF

    if [[ -f subdomains/live.txt && -s subdomains/live.txt ]]; then
        echo "<table><tr><th>URL</th></tr>" >> "$REPORT"
        while IFS= read -r line; do
            echo "<tr><td>$line</td></tr>" >> "$REPORT"
        done < subdomains/live.txt
        echo "</table>" >> "$REPORT"
    else
        echo '<div class="empty-state">No live hosts found</div>' >> "$REPORT"
    fi

    cat >> "$REPORT" <<EOF
            </div>
        </div>

        <div class="section">
            <h2 class="collapsible">Nuclei Findings ($vuln_count)</h2>
            <div class="content">
EOF

    if [[ -f nuclei/results.txt && -s nuclei/results.txt ]]; then
        echo "<table><tr><th>Finding</th></tr>" >> "$REPORT"
        while IFS= read -r line; do
            echo "<tr><td>$line</td></tr>" >> "$REPORT"
        done < nuclei/results.txt
        echo "</table>" >> "$REPORT"
    else
        if [[ "$SKIP_NUCLEI" == "true" ]]; then
            echo '<div class="empty-state">Nuclei scan was skipped</div>' >> "$REPORT"
        else
            echo '<div class="empty-state">No vulnerabilities found</div>' >> "$REPORT"
        fi
    fi

    cat >> "$REPORT" <<EOF
            </div>
        </div>

        <div class="section">
            <h2 class="collapsible">Wayback URLs with Parameters ($param_count)</h2>
            <div class="content">
EOF

    if [[ -f urls/wayback_params.txt && -s urls/wayback_params.txt ]]; then
        echo "<table><tr><th>URL</th></tr>" >> "$REPORT"
        head -200 urls/wayback_params.txt | while IFS= read -r line; do
            echo "<tr><td>$line</td></tr>" >> "$REPORT"
        done
        echo "</table>" >> "$REPORT"
        echo '<p style="margin-top:15px; color:#64748b; font-size:0.9em;">Showing first 200 URLs</p>' >> "$REPORT"
    else
        echo '<div class="empty-state">No parameterized URLs found</div>' >> "$REPORT"
    fi

    cat >> "$REPORT" <<'EOF_FOOTER'
            </div>
        </div>

        <div class="footer">
            Generated by Ultimate Recon Framework v2.0 | Made with ❤️ by AboudAdmin
        </div>
    </div>

    <script>
        document.querySelectorAll('.collapsible').forEach(item => {
            item.addEventListener('click', function() {
                this.classList.toggle('active');
                const content = this.nextElementSibling;
                content.classList.toggle('active');
            });
        });
    </script>
</body>
</html>
EOF_FOOTER

    log_success "HTML report generated: $REPORT"
}

# ================== SUMMARY FUNCTION ==================
print_summary() {
    if [[ "$QUIET_MODE" == "false" ]]; then
        print_victory_banner
        
        echo -e "${BRAND_CYAN}    ┌──────────────────────────────────────────────────────┐${NC}"
        echo -e "${BRAND_CYAN}    │${NC}  ${BOLD}📊 SCAN SUMMARY${NC}"
        echo -e "${BRAND_CYAN}    ├──────────────────────────────────────────────────────┤${NC}"
        echo -e "${BRAND_CYAN}    │${NC}  ${INFO}🌐${NC}  Subdomains Found:        ${BOLD}${SUCCESS}$TOTAL_SUBDOMAINS${NC}"
        echo -e "${BRAND_CYAN}    │${NC}  ${INFO}⚡${NC}  Live Hosts Detected:     ${BOLD}${SUCCESS}$TOTAL_LIVE${NC}"
        echo -e "${BRAND_CYAN}    │${NC}  ${INFO}🧨${NC}  Findings Discovered:     ${BOLD}${SUCCESS}$TOTAL_VULNS${NC}"
        echo -e "${BRAND_CYAN}    │${NC}  ${INFO}🕰️${NC}   Wayback URLs:           ${BOLD}${SUCCESS}$TOTAL_URLS${NC}"
        
        # Calculate duration
        local start_seconds=$(date -d "$START_TIME" +%s 2>/dev/null || date +%s)
        local end_seconds=$(date -d "$END_TIME" +%s 2>/dev/null || date +%s)
        local duration=$((end_seconds - start_seconds))
        local duration_formatted="${duration}s"
        if [[ $duration -ge 60 ]]; then
            duration_formatted="$((duration / 60))m $((duration % 60))s"
        fi
        
        echo -e "${BRAND_CYAN}    │${NC}  ${INFO}⏱️${NC}   Scan Duration:           ${BOLD}${SUCCESS}$duration_formatted${NC}"
        echo -e "${BRAND_CYAN}    └──────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        echo -e "    ${SUCCESS}💎  Premium Intelligence Report Ready${NC}"
        echo -e "    ${INFO}📂  Location:${NC} ${UNDER}$(pwd)/report.html${NC}"
        echo ""
        
        # Random encouraging closing
        local closings=(
            "🎯 Happy Hunting! Your intelligence is compiled and ready."
            "✨ Great work! Time to analyze your discoveries."
            "🔥 Scan complete! Good luck with your findings."
            "💎 Premium recon complete. Happy hunting!"
        )
        local random_index=$((RANDOM % ${#closings[@]}))
        echo -e "    ${DIM}${closings[$random_index]}${NC}"
        echo ""
        
        print_separator
    fi
}

# ================== CLEANUP FUNCTION ==================
cleanup() {
    # Stop dashboard if active
    stop_dashboard
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        engage_msg "Finalizing scan..."
    fi
}

trap cleanup EXIT INT TERM

# ================== MAIN EXECUTION ==================
main() {
    START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    parse_arguments "$@"
    
    print_banner
    
    engage_msg "🎯 Target locked: ${BOLD}$DOMAIN${NC}"
    transition_delay
    
    check_required_tools
    check_optional_tools
    
    setup_directories
    
    log_info "Reconnaissance initiated with $THREADS threads"
    transition_delay
    
    # Start dashboard
    start_dashboard
    sleep 2  # Give dashboard time to initialize
    
    # Phase 1: Subdomain Enumeration
    set_dashboard_phase 1 "Infrastructure Discovery" "Mapping attack surface..."
    enumerate_subdomains
    
    # Phase 2: Live Host Detection
    set_dashboard_phase 2 "Active Host Detection" "Detecting active infrastructure..."
    probe_live_hosts
    
    # Phase 3: Vulnerability Scanning
    set_dashboard_phase 3 "Security Assessment" "Analyzing security posture..."
    run_nuclei_scan
    
    # Phase 4: Historical Data
    set_dashboard_phase 4 "Historical Data Collection" "Excavating archived intelligence..."
    fetch_wayback_urls
    
    # Stop dashboard before final output
    stop_dashboard
    
    # Final reporting
    collect_metadata
    generate_html_report
    
    print_summary
}

main "$@"
