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

```
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
