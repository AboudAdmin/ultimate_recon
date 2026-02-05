#!/bin/bash

# ==========================================
# Ultimate Recon Framework - Phase 1
# Advanced Bug Bounty Reconnaissance Tool
# ==========================================

set -o pipefail  # Catch errors in pipelines

# ================== COLORS ==================
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# ================== GLOBAL VARIABLES ==================
DOMAIN=""
OUTPUT_DIR=""
THREADS=50
QUIET_MODE=false
SKIP_NUCLEI=false
START_TIME=""
END_TIME=""

# Tool arrays
REQUIRED_TOOLS=(subfinder httpx curl sort uniq grep sed wc)
OPTIONAL_TOOLS=(nuclei)

# ================== BANNER ==================
print_banner() {
    if [[ "$QUIET_MODE" == "false" ]]; then
        clear
        echo -e "${PURPLE}"
        cat <<EOF
 ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
██╔════╝ ██╔════╝██╔════╝██╔═══██╗████╗  ██║
██║  ███╗█████╗  ██║     ██║   ██║██╔██╗ ██║
██║   ██║██╔══╝  ██║     ██║   ██║██║╚██╗██║
╚██████╔╝███████╗╚██████╗╚██████╔╝██║ ╚████║
 ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
        echo -e "${YELLOW}Ultimate Recon Framework v2.0${NC}"
        echo -e "${GRAY}Phase 1: Production Ready${NC}\n"
    fi
}

# ================== LOGGING FUNCTIONS ==================
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [INFO] $1"
    
    # Write to log file
    echo "$message" >> "logs/scan.log"
    
    # Display to console if not in quiet mode
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${CYAN}[*]${NC} $1"
    fi
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [SUCCESS] $1"
    
    echo "$message" >> "logs/scan.log"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${GREEN}[+]${NC} $1"
    fi
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [WARNING] $1"
    
    echo "$message" >> "logs/scan.log"
    
    if [[ "$QUIET_MODE" == "false" ]]; then
        echo -e "${YELLOW}[!]${NC} $1"
    fi
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [ERROR] $1"
    
    # Write to both log files
    echo "$message" >> "logs/scan.log"
    echo "$message" >> "logs/errors.log"
    
    echo -e "${RED}[!] ERROR:${NC} $1" >&2
}

# ================== HELP FUNCTION ==================
show_help() {
    cat <<EOF
${GREEN}Ultimate Recon Framework - Phase 1${NC}

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
    
    # Remove protocol (http:// or https://)
    domain=$(echo "$domain" | sed 's~http[s]*://~~')
    
    # Remove trailing slashes and paths
    domain=$(echo "$domain" | sed 's~/.*~~')
    
    # Validate domain format
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $domain"
        echo -e "${RED}Please provide a valid domain (e.g., example.com)${NC}"
        exit 1
    fi
    
    echo "$domain"
}

validate_threads() {
    local threads=$1
    
    # Check if numeric
    if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
        log_error "Thread count must be a number"
        exit 1
    fi
    
    # Check reasonable range
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
    
    # Validate required arguments
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Error: Domain is required${NC}"
        echo "Use: ./ultimate-recon.sh -d example.com"
        exit 1
    fi
    
    # Sanitize and validate domain
    DOMAIN=$(sanitize_domain "$DOMAIN")
    
    # Validate threads
    THREADS=$(validate_threads "$THREADS")
    
    # Set default output directory if not provided
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="recon_$DOMAIN"
    fi
}

# ================== TOOL CHECKING ==================
check_required_tools() {
    local missing_tools=()
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}[!] Missing required tools:${NC}\n"
        
        for tool in "${missing_tools[@]}"; do
            echo -e "${YELLOW}  - $tool${NC}"
            
            # Provide installation suggestions
            case $tool in
                subfinder)
                    echo -e "${GRAY}    Install: go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest${NC}"
                    ;;
                httpx)
                    echo -e "${GRAY}    Install: go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest${NC}"
                    ;;
                *)
                    echo -e "${GRAY}    Install via your package manager${NC}"
                    ;;
            esac
            echo ""
        done
        
        exit 1
    fi
    
    log_success "All required tools are installed"
}

check_optional_tools() {
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warning "Optional tool '$tool' not found - related features will be skipped"
            
            case $tool in
                nuclei)
                    SKIP_NUCLEI=true
                    echo -e "${GRAY}    Install: go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest${NC}"
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
    log_info "Setting up directory structure"
    
    mkdir -p "$OUTPUT_DIR"/{subdomains,urls,nuclei,logs,meta}
    
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_error "Failed to create output directory: $OUTPUT_DIR"
        exit 1
    fi
    
    cd "$OUTPUT_DIR" || exit 1
    
    log_success "Directory structure created: $OUTPUT_DIR"
}

# ================== RECONNAISSANCE FUNCTIONS ==================
enumerate_subdomains() {
    log_info "Enumerating subdomains for $DOMAIN"
    
    if ! subfinder -d "$DOMAIN" -silent -o subdomains/all.txt 2>> logs/errors.log; then
        log_error "Subfinder failed. Check logs/errors.log for details"
        return 1
    fi
    
    # Ensure file exists and sort/deduplicate
    if [[ -f subdomains/all.txt ]]; then
        sort -u subdomains/all.txt -o subdomains/all.txt
        local count=$(wc -l < subdomains/all.txt 2>/dev/null || echo "0")
        log_success "Found $count subdomains"
        return 0
    else
        log_error "No subdomains file created"
        return 1
    fi
}

probe_live_hosts() {
    log_info "Probing for live hosts"
    
    if [[ ! -f subdomains/all.txt ]]; then
        log_error "No subdomains file found. Skipping host probing."
        return 1
    fi
    
    local subdomain_count=$(wc -l < subdomains/all.txt)
    
    if [[ "$subdomain_count" -eq 0 ]]; then
        log_warning "No subdomains to probe"
        return 1
    fi
    
    if ! cat subdomains/all.txt | httpx -silent -threads "$THREADS" -o subdomains/live.txt 2>> logs/errors.log; then
        log_error "HTTPx probing failed. Check logs/errors.log for details"
        return 1
    fi
    
    if [[ -f subdomains/live.txt ]]; then
        sort -u subdomains/live.txt -o subdomains/live.txt
        local count=$(wc -l < subdomains/live.txt 2>/dev/null || echo "0")
        log_success "Found $count live hosts"
        return 0
    else
        log_warning "No live hosts found"
        touch subdomains/live.txt
        return 1
    fi
}

run_nuclei_scan() {
    if [[ "$SKIP_NUCLEI" == "true" ]]; then
        log_warning "Nuclei scan skipped (--no-nuclei flag or tool not installed)"
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
        log_warning "No live hosts to scan with Nuclei"
        touch nuclei/results.txt
        return 1
    fi
    
    log_info "Running Nuclei vulnerability scan on $live_count hosts"
    log_info "This may take a while... (showing stats every 10 seconds)"
    
    # Enhanced Nuclei execution with better parameters
    if nuclei -l subdomains/live.txt \
        -severity critical,high,medium \
        -rate-limit 150 \
        -timeout 10 \
        -bulk-size 25 \
        -stats -si 10 \
        -retries 1 \
        -silent \
        -o nuclei/results.txt \
        2>> logs/errors.log; then
        
        local vuln_count=0
        if [[ -f nuclei/results.txt ]]; then
            vuln_count=$(wc -l < nuclei/results.txt 2>/dev/null || echo "0")
        fi
        
        log_success "Nuclei scan completed - Found $vuln_count potential vulnerabilities"
        return 0
    else
        log_error "Nuclei scan encountered errors. Check logs/errors.log"
        touch nuclei/results.txt
        return 1
    fi
}

fetch_wayback_urls() {
    log_info "Fetching URLs from Wayback Machine"
    
    if ! curl -s "https://web.archive.org/cdx/search/cdx?url=*.$DOMAIN/*&output=text&fl=original&collapse=urlkey" \
        -o urls/wayback_all.txt 2>> logs/errors.log; then
        log_error "Failed to fetch Wayback URLs"
        touch urls/wayback_all.txt urls/wayback_params.txt
        return 1
    fi
    
    # Sort and deduplicate
    if [[ -f urls/wayback_all.txt ]]; then
        sort -u urls/wayback_all.txt -o urls/wayback_all.txt
        local count=$(wc -l < urls/wayback_all.txt 2>/dev/null || echo "0")
        
        # Extract URLs with interesting parameters
        grep -Ei "\?|\.php|\.aspx|\.jsp|\.json|\.api" urls/wayback_all.txt > urls/wayback_params.txt 2>/dev/null || touch urls/wayback_params.txt
        
        local param_count=$(wc -l < urls/wayback_params.txt 2>/dev/null || echo "0")
        
        log_success "Found $count Wayback URLs ($param_count with parameters)"
        return 0
    else
        log_error "Wayback URLs file not created"
        touch urls/wayback_all.txt urls/wayback_params.txt
        return 1
    fi
}

# ================== METADATA COLLECTION ==================
collect_metadata() {
    log_info "Collecting scan metadata"
    
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Calculate duration
    local start_seconds=$(date -d "$START_TIME" +%s 2>/dev/null || date +%s)
    local end_seconds=$(date -d "$END_TIME" +%s 2>/dev/null || date +%s)
    local duration=$((end_seconds - start_seconds))
    local duration_formatted="${duration}s"
    
    if [[ $duration -ge 60 ]]; then
        duration_formatted="$((duration / 60))m $((duration % 60))s"
    fi
    
    # Get tool versions
    local subfinder_ver=$(get_tool_version "subfinder")
    local httpx_ver=$(get_tool_version "httpx")
    local nuclei_ver=$(get_tool_version "nuclei")
    
    # Write metadata
    cat > meta/info.txt <<EOF
Target Domain: $DOMAIN
Output Directory: $OUTPUT_DIR
Threads: $THREADS

Scan Timeline:
  Started: $START_TIME
  Ended: $END_TIME
  Duration: $duration_formatted

Tool Versions:
  subfinder: $subfinder_ver
  httpx: $httpx_ver
  nuclei: $nuclei_ver

Scan Configuration:
  Quiet Mode: $QUIET_MODE
  Skip Nuclei: $SKIP_NUCLEI
EOF
    
    log_success "Metadata collected"
}

# ================== HTML REPORT GENERATION ==================
generate_html_report() {
    log_info "Generating HTML report"
    
    local REPORT="report.html"
    
    # Get counts
    local subdomain_count=$(wc -l < subdomains/all.txt 2>/dev/null || echo "0")
    local live_count=$(wc -l < subdomains/live.txt 2>/dev/null || echo "0")
    local wayback_count=$(wc -l < urls/wayback_all.txt 2>/dev/null || echo "0")
    local param_count=$(wc -l < urls/wayback_params.txt 2>/dev/null || echo "0")
    local vuln_count=$(wc -l < nuclei/results.txt 2>/dev/null || echo "0")
    
    # Calculate percentages
    local live_percentage=0
    if [[ $subdomain_count -gt 0 ]]; then
        live_percentage=$((live_count * 100 / subdomain_count))
    fi
    
    # Get duration
    local start_seconds=$(date -d "$START_TIME" +%s 2>/dev/null || date +%s)
    local end_seconds=$(date -d "$END_TIME" +%s 2>/dev/null || date +%s)
    local duration=$((end_seconds - start_seconds))
    local duration_formatted="${duration}s"
    if [[ $duration -ge 60 ]]; then
        duration_formatted="$((duration / 60))m $((duration % 60))s"
    fi
    
    # Get tool versions
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
        
        h3 {
            color: #38bdf8;
            font-size: 1.3em;
            margin: 20px 0 10px 0;
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
            font-size: 0.95em;
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
        
        .badge {
            display: inline-block;
            background: #22c55e;
            color: #020617;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            margin: 2px;
        }
        
        .badge-critical {
            background: #ef4444;
            color: white;
        }
        
        .badge-high {
            background: #f97316;
            color: white;
        }
        
        .badge-medium {
            background: #eab308;
            color: #020617;
        }
        
        .badge-info {
            background: #38bdf8;
            color: #020617;
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

    # Add dynamic content
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

    # Add live hosts
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

    # Add Nuclei findings
    if [[ -f nuclei/results.txt && -s nuclei/results.txt ]]; then
        echo "<table><tr><th>Finding</th></tr>" >> "$REPORT"
        while IFS= read -r line; do
            # Try to detect severity from the line
            local badge_class="badge-info"
            if echo "$line" | grep -qi "critical"; then
                badge_class="badge-critical"
            elif echo "$line" | grep -qi "high"; then
                badge_class="badge-high"
            elif echo "$line" | grep -qi "medium"; then
                badge_class="badge-medium"
            fi
            
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

    # Add Wayback URLs
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

    # Close the document
    cat >> "$REPORT" <<'EOF_FOOTER'
            </div>
        </div>

        <div class="footer">
            Generated by Ultimate Recon Framework v2.0 - Phase 1
        </div>
    </div>

    <script>
        // Collapsible sections functionality
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
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo -e "${YELLOW}         RECONNAISSANCE COMPLETE       ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo ""
        
        local subdomain_count=$(wc -l < subdomains/all.txt 2>/dev/null || echo "0")
        local live_count=$(wc -l < subdomains/live.txt 2>/dev/null || echo "0")
        local wayback_count=$(wc -l < urls/wayback_all.txt 2>/dev/null || echo "0")
        local param_count=$(wc -l < urls/wayback_params.txt 2>/dev/null || echo "0")
        local vuln_count=$(wc -l < nuclei/results.txt 2>/dev/null || echo "0")
        
        echo -e "${CYAN}Target:${NC}           $DOMAIN"
        echo -e "${CYAN}Subdomains:${NC}       $subdomain_count found"
        echo -e "${CYAN}Live Hosts:${NC}       $live_count active"
        echo -e "${CYAN}Wayback URLs:${NC}     $wayback_count total ($param_count with parameters)"
        echo -e "${CYAN}Findings:${NC}         $vuln_count potential vulnerabilities"
        echo ""
        echo -e "${CYAN}Output Directory:${NC} ${YELLOW}$(pwd)${NC}"
        echo -e "${CYAN}HTML Report:${NC}      ${YELLOW}$(pwd)/report.html${NC}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
    fi
}

# ================== CLEANUP FUNCTION ==================
cleanup() {
    log_info "Cleaning up..."
}

# Trap cleanup on exit
trap cleanup EXIT INT TERM

# ================== MAIN EXECUTION ==================
main() {
    # Start timing
    START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Parse arguments
    parse_arguments "$@"
    
    # Print banner
    print_banner
    
    # Check tools
    check_required_tools
    check_optional_tools
    
    # Setup directories
    setup_directories
    
    # Display scan info
    log_info "Starting reconnaissance on $DOMAIN"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Using $THREADS threads"
    
    # Run reconnaissance phases
    enumerate_subdomains
    probe_live_hosts
    run_nuclei_scan
    fetch_wayback_urls
    
    # Collect metadata and generate report
    collect_metadata
    generate_html_report
    
    # Print summary
    print_summary
    
    log_success "Reconnaissance completed successfully! 🎯"
}

# Execute main function with all arguments
main "$@"
