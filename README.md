[README.md](https://github.com/user-attachments/files/25102135/README.md)
<<<<<<< HEAD
# Ultimate Recon Framework - Phase 1

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0+-orange.svg)](https://www.gnu.org/software/bash/)

A professional-grade reconnaissance automation tool for security researchers and bug bounty hunters. Phase 1 focuses on core stability, production readiness, and user-friendly features.

## ✨ Features

### Phase 1: Production-Ready Core
- 🏗️ **Modular Architecture** - Clean, maintainable function-based design
- 🎯 **Smart Tool Management** - Required vs. optional tool detection with graceful degradation
- 📝 **Comprehensive Logging** - Timestamped logs for debugging and audit trails
- ⚡ **Enhanced Performance** - Optimized Nuclei execution with rate limiting and stats
- 📊 **Beautiful HTML Reports** - Modern, responsive reports with collapsible sections
- 🎛️ **Flexible CLI** - Full command-line argument support for automation
- 🛡️ **Robust Error Handling** - Graceful failures with meaningful error messages
- 📱 **Mobile-Friendly** - Reports render perfectly on all devices

## 📦 Installation

### Prerequisites

**Required Tools:**
```bash
# Install Go (for Go-based tools)
# Visit: https://golang.org/dl/

# Install subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Install httpx
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
```

**Optional Tools:**
```bash
# Install nuclei (for vulnerability scanning)
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
```

### Setup

1. Clone or download the repository:
```bash
git clone <repository-url>
cd ultimate_recon
```

2. Make the script executable:
```bash
chmod +x ultimate-recon.sh
```

3. Verify installation:
```bash
./ultimate-recon.sh -h
```

## 🚀 Usage

### Basic Scan
```bash
./ultimate-recon.sh -d example.com
```

### Custom Output Directory
```bash
./ultimate-recon.sh -d example.com -o my_scan_results
```

### High-Performance Scan
```bash
./ultimate-recon.sh -d example.com -t 100
```

### Quiet Mode (Minimal Output)
```bash
./ultimate-recon.sh -d example.com -q
```

### Skip Nuclei Scan
```bash
./ultimate-recon.sh -d example.com --no-nuclei
```

### Complete Example
```bash
./ultimate-recon.sh -d example.com -o bug_bounty_scan -t 150 -q
```

## 📋 Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --domain DOMAIN` | Target domain (required) | - |
| `-o, --output DIR` | Custom output directory | `recon_<domain>` |
| `-t, --threads NUM` | Number of threads | `50` |
| `-q, --quiet` | Minimal console output | `false` |
| `--no-nuclei` | Skip Nuclei vulnerability scan | `false` |
| `-h, --help` | Show help message | - |

## 📁 Output Structure
=======
[README (1).md](https://github.com/user-attachments/files/25097397/README.1.md)
# 🔍 Ultimate Recon Framework

> **Ultimate Recon Framework** is a powerful and automated reconnaissance tool built for  
> **Bug Bounty Hunters & Security Researchers**.  
> It performs full recon on a target domain and generates a **clean, professional HTML report** automatically.

---

## 📌 What This Tool Does

✔ Enumerates subdomains  
✔ Detects live hosts  
✔ Scans for vulnerabilities  
✔ Collects archived URLs  
✔ Builds a beautiful HTML dashboard  

All in **one command**.

---

## ✨ Features

- 🌐 Subdomain Enumeration (**subfinder**)
- ⚡ Live Host Detection (**httpx**)
- 🧨 Vulnerability Scanning (**nuclei**)
- 🕰 Wayback URL Harvesting
- 🔍 Parameter-based URL filtering
- 📊 Automatic HTML Report
- 🎨 Dark & Clean UI
- 🗂 Organized output per target
- 🐧 Optimized for Kali Linux

---

## 📂 Output Structure

After scanning a target, results are saved like this:
>>>>>>> 05030069d46880fa6041802fbd4d6059e017213c

```
recon_example.com/
├── subdomains/
<<<<<<< HEAD
│   ├── all.txt              # All discovered subdomains
│   └── live.txt             # Active HTTP/HTTPS hosts
├── urls/
│   ├── wayback_all.txt      # All Wayback Machine URLs
│   └── wayback_params.txt   # URLs with parameters
├── nuclei/
│   └── results.txt          # Vulnerability findings
├── logs/
│   ├── scan.log             # Main execution log
│   └── errors.log           # Error tracking
├── meta/
│   └── info.txt             # Scan metadata
└── report.html              # Interactive HTML report
```

## 📊 HTML Report Features

- **📈 Statistics Dashboard** - Quick overview of scan results
- **🎨 Modern Dark Theme** - Professional and easy on the eyes
- **📱 Responsive Design** - Works on desktop, tablet, and mobile
- **🔽 Collapsible Sections** - Clean navigation through large datasets
- **⏱️ Detailed Metadata** - Scan timeline, duration, and tool versions
- **🎯 Severity Color Coding** - Quick identification of critical findings

## 🔧 Workflow

1. **Subdomain Enumeration** - Uses subfinder to discover subdomains
2. **Live Host Probing** - Uses httpx to identify active hosts
3. **Vulnerability Scanning** - Uses nuclei for security assessment (optional)
4. **Historical URL Discovery** - Fetches URLs from Wayback Machine
5. **Report Generation** - Creates comprehensive HTML report

## 📝 Logging

All scans generate detailed logs:

- **`logs/scan.log`** - Timestamped log of all operations
- **`logs/errors.log`** - Dedicated error tracking for debugging

Example log entry:
```
[2026-02-05 16:52:20] [INFO] Starting reconnaissance on example.com
[2026-02-05 16:52:35] [SUCCESS] Found 42 subdomains
[2026-02-05 16:53:10] [INFO] Found 28 live hosts
```

## 🎯 Best Practices

1. **Start with default settings** for your first scan
2. **Use quiet mode (`-q`)** when integrating with other tools
3. **Adjust threads (`-t`)** based on your network connection
4. **Skip Nuclei (`--no-nuclei`)** for quick passive reconnaissance
5. **Review `errors.log`** if scans fail or produce unexpected results

## ⚠️ Important Notes

- **Permissions Required**: Ensure you have authorization to scan the target domain
- **Rate Limiting**: Nuclei includes built-in rate limiting (150 req/s) to prevent issues
- **Network Requirements**: Requires stable internet connection for external API calls
- **Tool Versions**: Keep tools updated for best results

## 🔮 Future Phases

### Phase 2: Advanced Recon (Planned)
- Historical URL collection using gau and waybackurls
- JavaScript file extraction and secret discovery
- Technology detection and WAF identification
- DNS record enumeration
- Port scanning with naabu

### Phase 3: Framework-Level (Planned)
- Resume capability for interrupted scans
- JSON and Markdown export formats
- Screenshot capture
- Subdomain takeover detection
- Progress bars and ETA calculations

## 🐛 Troubleshooting

### "Missing required tool" error
Install the missing tool using the suggested command in the error message.

### Nuclei scan fails
Check `logs/errors.log` for details. Common issues:
- Network connectivity
- Rate limiting by target
- Outdated nuclei templates (run `nuclei -update-templates`)

### No subdomains found
- Verify domain spelling
- Check if domain has public DNS records
- Review `logs/errors.log` for API errors

### HTML report doesn't open
Ensure the scan completed successfully. Check for file permissions issues.

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

This is a phased development project. Phase 1 is focused on stability and core features.
Feedback and suggestions for future phases are welcome!

## ⚡ Quick Start Checklist

- [ ] Install required tools (subfinder, httpx)
- [ ] Install optional tools (nuclei)
- [ ] Make script executable (`chmod +x`)
- [ ] Run help command to verify (`./ultimate-recon.sh -h`)
- [ ] Test with a domain you own
- [ ] Review the HTML report
- [ ] Check the logs directory

## 📞 Support

For issues, questions, or feature requests:
1. Check the troubleshooting section
2. Review `logs/errors.log` for error details
3. Open an issue with details about your environment

---

**Made with ❤️ for the bug bounty and security research community**
=======
│   ├── all.txt
│   └── live.txt
├── urls/
│   ├── wayback_all.txt
│   └── wayback_params.txt
├── nuclei/
│   └── results.txt
├── meta/
│   └── info.txt
└── report.html
```

---

## 🛠 Requirements

- Kali Linux (Recommended)
- Bash
- Git
- Curl

### Security Tools
- subfinder
- httpx
- nuclei

---

## 🚀 Installation Guide

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/AboudAdmin/ultimate_recon.git
cd ultimate_recon
```

---

### 2️⃣ Give Execute Permission

```bash
chmod +x ultimate-recon.sh
```

---

### 3️⃣ Install Dependencies (Kali Linux)

```bash
sudo apt update
sudo apt install -y git curl subfinder httpx nuclei
```

Update nuclei templates (first time only):

```bash
nuclei -update-templates
```

---

## ▶️ How to Run the Tool

Start the tool:

```bash
./ultimate-recon.sh
```

Enter the target domain when asked:

```
example.com
```

---

## 📊 View the HTML Report

Once the scan finishes:

```bash
xdg-open recon_example.com/report.html
```

Or open it in Firefox:

```bash
firefox recon_example.com/report.html
```

---

## ⚠️ Disclaimer

This tool is created **for educational purposes and authorized testing only**.  
Running it against systems without permission is **illegal**.

The author is **not responsible** for any misuse.

---

## 👨‍💻 Author

**Abdullah (AboudAdmin)**  
Bug Bounty Hunter | Security Researcher  

GitHub: https://github.com/AboudAdmin

---

## ⭐ Support the Project

If you like this tool:

- ⭐ Star the repository
- 🍴 Fork it
- 📢 Share it with others

Happy Hunting 🎯
>>>>>>> 05030069d46880fa6041802fbd4d6059e017213c
