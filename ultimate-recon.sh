#!/bin/bash

# ================== COLORS ==================
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ================== BANNER ==================
clear
echo -e "${PURPLE}"
cat << "EOF"
 ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
██╔════╝ ██╔════╝██╔════╝██╔═══██╗████╗  ██║
██║  ███╗█████╗  ██║     ██║   ██║██╔██╗ ██║
██║   ██║██╔══╝  ██║     ██║   ██║██║╚██╗██║
╚██████╔╝███████╗╚██████╗╚██████╔╝██║ ╚████║
 ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
echo -e "${YELLOW}Ultimate Recon Framework${NC}\n"

# ================== CHECK TOOLS ==================
REQUIRED_TOOLS=(subfinder httpx nuclei curl sort uniq grep sed wc)

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &>/dev/null; then
        echo -e "${RED}[!] Missing tool: $tool${NC}"
        exit 1
    fi
done

# ================== INPUT ==================
read -p "Enter Target Domain: " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}[!] Domain cannot be empty${NC}"
    exit 1
fi

DOMAIN=$(echo "$DOMAIN" | sed 's~http[s]*://~~' | sed 's~/.*~~')

# ================== OUTPUT ==================
START_TIME=$(date)
OUTPUT_DIR="recon_$DOMAIN"

mkdir -p "$OUTPUT_DIR"/{subdomains,urls,nuclei,meta}
cd "$OUTPUT_DIR" || exit

echo -e "${CYAN}[*] Target: ${YELLOW}$DOMAIN${NC}"
echo -e "${CYAN}[*] Start Time: ${YELLOW}$START_TIME${NC}\n"

# ================== SUBDOMAIN ENUM ==================
echo -e "${GREEN}[+] Enumerating Subdomains${NC}"
subfinder -d "$DOMAIN" -silent | sort -u > subdomains/all.txt
echo -e "${CYAN}Found: $(wc -l < subdomains/all.txt) subdomains${NC}\n"

# ================== LIVE HOSTS ==================
echo -e "${GREEN}[+] Checking Live Hosts${NC}"
cat subdomains/all.txt | httpx -silent -threads 50 | sort -u > subdomains/live.txt
echo -e "${CYAN}Alive: $(wc -l < subdomains/live.txt) hosts${NC}\n"

# ================== NUCLEI ==================
echo -e "${GREEN}[+] Running Nuclei Scan${NC}"
nuclei -l subdomains/live.txt \
    -severity critical,high,medium \
    -silent \
    -o nuclei/results.txt

# ================== WAYBACK ==================
echo -e "${GREEN}[+] Fetching Wayback URLs${NC}"

curl -s "https://web.archive.org/cdx/search/cdx?url=*.$DOMAIN/*&output=text&fl=original&collapse=urlkey" \
| sort -u > urls/wayback_all.txt

grep -Ei "\?|\.php|\.aspx|\.jsp|\.json|\.api" urls/wayback_all.txt \
> urls/wayback_params.txt

# ================== META ==================
END_TIME=$(date)

{
echo "Target: $DOMAIN"
echo "Started: $START_TIME"
echo "Ended: $END_TIME"
} > meta/info.txt

# ================== HTML REPORT ==================
REPORT="report.html"

echo -e "${GREEN}[+] Generating HTML Report${NC}"

cat << EOF > $REPORT
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Recon Report - $DOMAIN</title>

<style>
body{
background:#0f172a;
color:#e5e7eb;
font-family:Arial;
padding:20px;
}
h1,h2{color:#38bdf8;}

.section{
background:#020617;
padding:15px;
margin-bottom:20px;
border-radius:10px;
}

table{
width:100%;
border-collapse:collapse;
}

th,td{
padding:8px;
border-bottom:1px solid #334155;
font-size:14px;
}

th{color:#22c55e;}

.badge{
background:#22c55e;
color:black;
padding:3px 8px;
border-radius:6px;
font-size:12px;
}

.small{
font-size:13px;
color:#94a3b8;
}
</style>
</head>

<body>

<h1>Recon Report</h1>

<p class="small">
<b>Target:</b> $DOMAIN <br>
<b>Started:</b> $START_TIME <br>
<b>Finished:</b> $END_TIME
</p>

<div class="section">
<h2>Summary</h2>
<ul>
<li>Subdomains: <span class="badge">$(wc -l < subdomains/all.txt)</span></li>
<li>Live Hosts: <span class="badge">$(wc -l < subdomains/live.txt)</span></li>
<li>Wayback URLs: <span class="badge">$(wc -l < urls/wayback_all.txt)</span></li>
<li>Param URLs: <span class="badge">$(wc -l < urls/wayback_params.txt)</span></li>
</ul>
</div>

<div class="section">
<h2>Live Hosts</h2>
<table>
<tr><th>URL</th></tr>
EOF

while read -r line; do
echo "<tr><td>$line</td></tr>" >> $REPORT
done < subdomains/live.txt

cat << EOF >> $REPORT
</table>
</div>

<div class="section">
<h2>Nuclei Findings</h2>
<table>
<tr><th>Result</th></tr>
EOF

if [ -s nuclei/results.txt ]; then
while read -r line; do
echo "<tr><td>$line</td></tr>" >> $REPORT
done < nuclei/results.txt
else
echo "<tr><td>No vulnerabilities found</td></tr>" >> $REPORT
fi

cat << EOF >> $REPORT
</table>
</div>

<div class="section">
<h2>Wayback URLs (Params)</h2>
<table>
<tr><th>URL</th></tr>
EOF

head -200 urls/wayback_params.txt | while read -r line; do
echo "<tr><td>$line</td></tr>" >> $REPORT
done

cat << EOF >> $REPORT
</table>
<p class="small">Showing first 200 URLs</p>
</div>

</body>
</html>
EOF

echo -e "${CYAN}Report Created → ${YELLOW}$OUTPUT_DIR/$REPORT${NC}"

# ================== DONE ==================
echo -e "${YELLOW}Recon Completed 🎯${NC}"
