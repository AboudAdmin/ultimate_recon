[README.md](https://github.com/user-attachments/files/25097339/README.md)
# 🔍 Ultimate Recon Framework

Ultimate Recon Framework is an automated reconnaissance tool designed for Bug Bounty Hunters and Security Researchers.
It performs full recon on a target domain and generates a clean, organized HTML report automatically.

---

## ✨ Features

- Subdomain Enumeration (subfinder)
- Live Host Detection (httpx)
- Vulnerability Scanning (nuclei)
- Wayback URL Harvesting
- Parameterized URL Extraction
- Automatic HTML Report Generation
- Clean Dark UI Dashboard
- Organized output structure
- Fully compatible with Kali Linux

---

## 📁 Output Structure

recon_example.com/
├── subdomains/
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

---

## 🛠 Requirements

- Kali Linux (Recommended)
- bash
- git
- curl
- subfinder
- httpx
- nuclei

---

## 🚀 Installation

### Clone the repository

git clone https://github.com/AboudAdmin/ultimate_recon.git
cd ultimate_recon

### Give execute permission

chmod +x ultimate-recon.sh

---

## 📦 Install Dependencies (Kali Linux)

sudo apt update
sudo apt install -y git curl subfinder httpx nuclei

Update nuclei templates:

nuclei -update-templates

---

## ▶️ Usage

./ultimate-recon.sh

Enter target domain when prompted:

example.com

---

## 📊 View HTML Report

xdg-open recon_example.com/report.html

---

## ⚠️ Disclaimer

This tool is intended for educational purposes and authorized security testing only.
Do NOT use it against systems without explicit permission.

---

## 👨‍💻 Author

Abdullah (AboudAdmin)
https://github.com/AboudAdmin

Happy Hunting 🎯
