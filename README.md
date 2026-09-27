<p align="center">
  <img src="docs/assets/icon_128.png" alt="Macbeth Logo" width="128" height="128">
</p>

<h1 align="center">Macbeth for macOS</h1>

<p align="center">
  <strong>A Bootable USB & Installation Media Creator for Mac</strong><br>
  Engineered in Swift 6 for Apple Silicon & Intel macOS (macOS 14 Sonoma, macOS 15 Sequoia, and beyond).
</p>

<p align="center">
  <a href="https://github.com/kingsuresh-dotcom/macbeth/releases/latest"><img src="https://img.shields.io/badge/Release-v1.0.0-blue.svg" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/Swift-6.4_Strict_Concurrency-orange.svg" alt="Swift 6">
  <img src="https://img.shields.io/badge/Platform-macOS_14.0+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Architecture-ARM64%20%7C%20x86__64-purple.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/Tests-16%2F16_Passing-brightgreen.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Craft-100%25_Vibe--Coded-ff69b4.svg" alt="100% Vibe-Coded">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</p>

---

> [!NOTE]
> ### 🤖 100% Vibe-Coded
> **Macbeth is 100% vibe-coded.** Every single component—from the high-speed raw POSIX block streamer and low-level IOKit hardware disk guardrails, to the Windows 11 unattended setup XML (`autounattend.xml`) injection engine and native SwiftUI interfaces—was conceived, architected, debugged, and implemented entirely through **natural language AI prompting and autonomous agent pairing**.
>
> Not a single line of Swift was hand-written. This project serves as an active testbed and living portfolio piece for honing and mastering advanced AI prompting, autonomous SDLC directives, and prompt-driven systems engineering.

---

## Overview

**Macbeth** brings the power, speed, and deep customization of Windows tools like **Rufus** natively to macOS. 

Flashing Windows 11, Linux distributions, or raw OS images on a Mac has historically required archaic command-line `dd` hacks, third-party FAT32/WIM splitting scripts, or slow virtualization workarounds. Macbeth solves this completely by providing a dedicated, high-performance, and safety-hardened native pipeline with automated unattended setup generation (`autounattend.xml`), hardware drive protection, and dynamic upstream ISO cataloging.

---

## Screenshot Gallery

| Main Flashing Interface | Windows 11 Customization |
| :---: | :---: |
| <img src="docs/screenshots/macbeth_main.png" width="460" alt="Main Interface"> | <img src="docs/screenshots/macbeth_windows_experience.png" width="460" alt="Windows Experience"> |
| **Official OS Download Center** | **Real-Time Audit Log** |
| <img src="docs/screenshots/macbeth_download_center.png" width="460" alt="Download Center"> | <img src="docs/screenshots/macbeth_event_log.png" width="460" alt="Event Log"> |

---

## Key Features

### 🪟 Windows 11 Automated Experience & Bypass Engine
* **Bypass Hardware Checks**: Automates XML injection (`autounattend.xml` and `setup.bat`) to bypass Windows 11 TPM 2.0, Secure Boot, minimum 4GB RAM, and CPU/storage restriction checks during clean installs or in-place upgrades.
* **Bypass Online Account (MSA)**: Forces Windows Setup to allow creating a pure local offline user account.
* **Prevent Device Encryption**: Automatically disables BitLocker device encryption on fresh installs.
* **RTC-to-UTC Dual Boot Sync**: Injects registry flags (`RealTimeIsUniversal = 1`) so dual-booting Mac/Linux alongside Windows maintains identical hardware clock synchronization.
* **Large WIM Handling**: Seamlessly formats GPT / ExFAT or splits monolithic `install.wim` files exceeding the 4 GB single-file limit of FAT32.

### 🐧 Live Upstream Linux Catalog & Resolution
* **Zero Staleness**: Does not rely on outdated static links. Queries upstream distribution APIs and release manifests dynamically at runtime:
  * **Debian**: Dynamically parses official `SHA256SUMS` to discover latest point releases (e.g. Debian 13.7.0 Trixie) with cryptographic checksum validation.
  * **Ubuntu**: Queries Canonical's official `meta-release-lts` manifest.
  * **Fedora**: Interrogates official Fedora Project releases JSON API.
  * **Arch Linux**: Tracks monthly rolling snapshots.
* **Resilient Offline Fallback**: Safely falls back to pre-verified baselines if network connectivity is absent.

### 🛡️ Enterprise-Grade Drive Safety & Counterfeit Flash Detection
* **Physical Bus Protection**: Deep hardware inspection automatically hides and rejects non-removable internal drives (Apple Fabric, internal NVMe, PCIe APFS containers) and Time Machine backup volumes.
* **10-Second Counterfeit Flash Probe**: Quick boundary write/read verification detects spoofed USB drives (e.g. fake 2TB drives that overwrite memory loops).
* **Automated Label Sanitization**: Enforces strict FAT32 (11 uppercase chars) and ExFAT (15 chars) volume label standards.

### ⚡ Raw POSIX Block Streaming
* Direct raw character device access (`/dev/rdiskX`) with optimized buffer alignment ensures near-theoretical maximum write speeds across USB 3.2 Gen 2 and Thunderbolt flash storage.
* Non-blocking real-time throughput metrics (MB/s), ETA calculations, and background power assertions (`IOPMAssertionCreateWithName`) prevent system sleep during active burn cycles.

---

## Getting Started

### Installation

#### Prebuilt App Bundle
Download the latest `Macbeth.app` from the [Releases](https://github.com/kingsuresh-dotcom/macbeth/releases) tab and drag it to `/Applications`.

#### Command-Line Tool
To install the standalone headless CLI tool:
```bash
cp /Applications/Macbeth.app/Contents/MacOS/macbeth ~/.local/bin/macbeth
```

---

## CLI Reference

Macbeth includes a complete command-line interface (`macbeth`) for terminal automation and headless scripting:

```bash
# List all safe external USB/storage targets
macbeth list

# Inspect an ISO or bootable image payload
macbeth inspect ~/Downloads/Win11_24H2_English_x64.iso

# Test a USB drive for counterfeit/fake storage boundary loops
macbeth test-fake-flash /dev/disk4

# Flash Windows 11 with automated bypasses to a USB target
sudo macbeth write --device /dev/disk4 --image ~/Downloads/Win11_24H2_English_x64.iso --label "WIN11_USB"

# Raw DD image flashing for hybrid Linux ISOs
sudo macbeth write --device /dev/disk4 --image ~/Downloads/archlinux-x86_64.iso --dd
```

---

## Architecture & Codebase

The Macbeth codebase is modularized under Swift Package Manager:

* **`MacbethCore`**: Pure Swift business logic, device discovery, unattended setup generator (`autounattend.xml`), inspection engine, POSIX streaming, and diagnostic scanners.
* **`MacbethApp`**: Modern SwiftUI macOS desktop application with reactive state management and dynamic catalog resolution.
* **`MacbethCLI`**: High-performance headless CLI wrapper.
* **`MacbethTests`**: Automated test suite with 100% strict concurrency verification.

For in-depth design documentation and architectural diagrams, see [ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 💾 Download & Installation

### Option 1: macOS Disk Image (.dmg) — Recommended for All Users

Pre-compiled, notarization-ready disk image installers are available directly from the **[GitHub Releases](https://github.com/kingsuresh-dotcom/macbeth/releases/latest)** page:

| Package | Architecture | Description | Download |
| :--- | :--- | :--- | :--- |
| **Macbeth Universal 2** | `arm64` + `x86_64` | **Recommended**: Runs natively on all Apple Silicon and Intel Macs | [**Macbeth-1.0.0-Universal.dmg**](https://github.com/kingsuresh-dotcom/macbeth/releases/download/v1.0.0/Macbeth-1.0.0-Universal.dmg) |
| **Macbeth Apple Silicon** | `arm64` | Optimized specifically for Apple Silicon (M1, M2, M3, M4) Macs | [**Macbeth-1.0.0-AppleSilicon.dmg**](https://github.com/kingsuresh-dotcom/macbeth/releases/download/v1.0.0/Macbeth-1.0.0-AppleSilicon.dmg) |
| **Macbeth Intel** | `x86_64` | Optimized for legacy Intel-based Macs | [**Macbeth-1.0.0-Intel.dmg**](https://github.com/kingsuresh-dotcom/macbeth/releases/download/v1.0.0/Macbeth-1.0.0-Intel.dmg) |

#### Quick Install Steps:
1. **Download** the `.dmg` installer for your Mac architecture (if unsure, choose the **Universal** package).
2. **Double-click** the downloaded `.dmg` file to mount the disk image.
3. **Drag** `Macbeth.app` into your **Applications** folder.
4. **Launch** Macbeth from `/Applications` or via Spotlight (`⌘ Space` &rarr; type `Macbeth`).
5. Upon first launch, review and accept the in-app **Legal Terms of Use** to unlock the flashing engine.

---

### Option 2: Standalone CLI Tool

For automated scripts, terminal pipelines, or headless server management:

```bash
# Download and unpack the Universal CLI binary
curl -LO https://github.com/kingsuresh-dotcom/macbeth/releases/download/v1.0.0/macbeth-1.0.0-darwin-universal.tar.gz
tar -xzf macbeth-1.0.0-darwin-universal.tar.gz

# Install binary to system PATH
sudo mv macbeth /usr/local/bin/

# Verify installation
macbeth --help
```

---

### Option 3: Building from Source (Developers)

If you wish to inspect the Swift 6 source code, modify pipelines, or contribute to Macbeth:

#### Prerequisites
* macOS 14.0 (Sonoma) or newer
* Xcode 16+ or Apple Command Line Tools (Swift 6.0+)

#### Build & Run
```bash
# Clone the repository
git clone https://github.com/kingsuresh-dotcom/macbeth.git
cd macbeth

# Run the 16 automated tests
swift run macbeth-tests

# Compile and package release application bundles
./scripts/build_release_dmg.sh
```

---

## ⚖️ Legal Disclaimer & Liability Waiver

> [!CAUTION]
> **CRITICAL LEGAL NOTICE — READ BEFORE DOWNLOADING OR USING**:
> Macbeth is an independent open-source project created and published **solely and strictly for educational, academic evaluation, and interoperability research purposes**. Low-level block flashing and raw disk operations are **INHERENTLY DESTRUCTIVE**. By downloading, cloning, compiling, installing, or executing Macbeth, you expressly agree to all terms, disclaimers, and liability waivers detailed below. For the dedicated legal document, see [DISCLAIMER.md](DISCLAIMER.md).

### 1. Purely Educational, Experimental, & Research Purposes
The Software is developed, published, and maintained solely and strictly for **academic, educational, evaluative, interoperability, and software architecture research purposes** (investigating native Swift 6 concurrency, Darwin character device block streaming via `/dev/rdisk*`, unattended setup automation schemas, and upstream manifest querying). The Software is **not** designed, marketed, intended, or licensed for enterprise production deployments, commercial redistribution, mission-critical operations, or safety-critical computing environments.

### 2. Inherent Risks of Low-Level Disk Operations & Total User Responsibility
**RAW DISK AND FLASH MEDIA OPERATIONS ARE INHERENTLY DESTRUCTIVE.**
The Software interacts directly with low-level storage controller subsystems, DiskArbitration, raw disk device nodes, and partition tables. Flashing an image, formatting a volume, partitioning a drive, or modifying boot sector structures will permanently, irretrievably, and destructively overwrite all pre-existing data on the target storage medium.
* You bear **100% sole and exclusive responsibility** for identifying, selecting, verifying, and double-checking target disk identifiers (e.g., `/dev/disk*` / `/dev/rdisk*`).
* You must verify that you have backed up all critical data on any connected internal or external storage devices prior to initiating any write operations.
* Under no circumstances shall the author(s), contributor(s), or copyright holder(s) be held liable for any loss of data, accidental formatting of unintended devices, corrupted filesystems, or hardware failures.

### 3. Absolute "AS-IS" Warranty Disclaimer
**TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW IN ANY JURISDICTION WORLDWIDE:**
THE SOFTWARE IS PROVIDED ON AN **"AS IS"**, **"WITH ALL FAULTS"**, AND **"AS AVAILABLE"** BASIS, WITHOUT ANY WARRANTIES, COVENANTS, GUARANTEES, OR REPRESENTATIONS OF ANY KIND, WHETHER EXPRESS, IMPLIED, STATUTORY, OR ARISING BY COURSE OF DEALING, USAGE, OR TRADE PRACTICE.

THE AUTHOR(S), COPYRIGHT HOLDER(S), CONTRIBUTOR(S), AND AFFILIATES SPECIFICALLY DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION:
* ANY IMPLIED WARRANTIES OF **MERCHANTABILITY**, **FITNESS FOR A PARTICULAR PURPOSE**, **QUALITY**, **RELIABILITY**, **SECURITY**, OR **TITLE**;
* ANY WARRANTY THAT THE SOFTWARE WILL BE UNINTERRUPTED, TIMELY, SECURE, ACCURATE, ERROR-FREE, FREE OF BUGS, COMPATIBLE WITH ANY PARTICULAR OPERATING SYSTEM, HARDWARE, OR FIRMWARE REVISION, OR THAT DEFECTS WILL BE CORRECTED;
* ANY WARRANTY OF **NON-INFRINGEMENT** OF INTELLECTUAL PROPERTY OR PROPRIETARY RIGHTS OF ANY THIRD PARTY.

### 4. Comprehensive Worldwide Limitation of Liability
**UNDER NO CIRCUMSTANCES AND UNDER NO LEGAL, EQUITABLE, OR JURISPRUDENTIAL THEORY—WHETHER IN CONTRACT, TORT (INCLUDING NEGLIGENCE, STRICT LIABILITY, OR GROSS FAULT TO THE MAXIMUM EXTENT PERMITTED BY LAW), PRODUCT LIABILITY, INDEMNITY, OR OTHERWISE—SHALL THE AUTHOR(S), COPYRIGHT OWNER(S), MAINTAINER(S), OR ANY INDIVIDUAL OR ENTITY ASSOCIATED WITH THIS REPOSITORY BE LIABLE TO YOU OR ANY THIRD PARTY FOR:**
1. ANY DIRECT, INDIRECT, INCIDENTAL, CONSEQUENTIAL, SPECIAL, PUNITIVE, EXEMPLARY, OR RETRIBUTIVE DAMAGES;
2. ANY LOSS OF DATA, REVENUE, PROFITS, USE, GOODWILL, BUSINESS OPPORTUNITIES, OR ANTICIPATED SAVINGS;
3. ANY HARDWARE DAMAGE, NAND FLASH WEAR, CONTROLLER FAILURE, LOGIC BOARD ISSUE, SYSTEM INSTABILITY, FIRMWARE BRICKING, OR BOOTLOADER INCOMPATIBILITY;
4. ANY INTERRUPTION OF BUSINESS, COMPUTER FAILURE, CORRUPTION OF STORAGE DEVICES, OR SYSTEM DOWNTIME;
5. ANY CLAIMS, PROCEEDINGS, COSTS, EXPENSES, OR ATTORNEY'S FEES ARISING OUT OF OR IN CONNECTION WITH THE DOWNLOAD, INSTALLATION, USE, PERFORMANCE, OR INABILITY TO USE THE SOFTWARE.

YOUR SOLE AND EXCLUSIVE REMEDY FOR DISSATISFACTION WITH THE SOFTWARE IS TO CEASE USING AND PERMANENTLY DELETE THE SOFTWARE.

### 5. Third-Party Trademarks & Strict Non-Affiliation
All product names, logos, brands, operating system titles, and registered or unregistered trademarks referenced within the Software or its documentation are the property of their respective trademark holders:
* **Microsoft, Windows, Windows 11, and Windows PE** are registered trademarks of Microsoft Corporation.
* **macOS, Apple, Apple Silicon, Mac, and DiskArbitration** are registered trademarks of Apple Inc.
* **Ubuntu** is a registered trademark of Canonical Ltd.
* **Fedora** is a registered trademark of Red Hat, Inc. / Fedora Project.
* **Debian** is a registered trademark of Software in the Public Interest, Inc.
* **Arch Linux** is a registered trademark of Aaron Griffin.
* **Rufus** is the trademark/creation of Pete Batard / Akeo Consulting.

**Macbeth is an independent open-source project.** The Software is **NOT** sponsored, endorsed, certified, vetted, affiliated with, or provided by Microsoft Corporation, Apple Inc., Canonical Ltd., Red Hat, Inc., the Debian Project, or any other trademark owner. All references to third-party operating systems or tools are made strictly for informational, descriptive, and nominative fair-use purposes.

### 6. End-User Compliance & Licensing Responsibility
The Software does **NOT** provide, distribute, mirror, or bundle proprietary operating system licenses, product keys, or digital activation tokens. Users are solely and exclusively responsible for possessing valid, genuine licenses for any operating systems installed using the Software and complying with all applicable End User License Agreements (EULAs), local laws, and regulations.

### 7. Global Severability & International Jurisdiction
If any provision of this Legal Disclaimer is determined by a court of competent jurisdiction to be invalid, unlawful, or unenforceable under the laws of any particular jurisdiction, such determination shall not affect the validity or enforceability of any other provision, which shall remain in full force and effect. This disclaimer shall be construed and interpreted broadly to provide the maximum legal protection, waiver of liability, and indemnification permitted under applicable international law. Complete terms: [DISCLAIMER.md](DISCLAIMER.md).

---

## License

Macbeth is released under the [MIT License](LICENSE).
Copyright &copy; 2026 [kingsuresh-dotcom](https://github.com/kingsuresh-dotcom).
