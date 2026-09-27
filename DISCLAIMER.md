# Legal Disclaimer & Terms of Use

> **IMPORTANT**: PLEASE READ THIS LEGAL DISCLAIMER CAREFULLY BEFORE DOWNLOADING, COMPILING, INSTALLING, RUNNING, OR USING **MACBETH** OR ANY OF ITS SOURCE CODE, BINARIES, PACKAGES, DOCUMENTATION, OR SCRIPTS (COLLECTIVELY, THE "SOFTWARE"). BY ACCESSING OR USING THE SOFTWARE, YOU EXPRESSLY ACKNOWLEDGE, UNDERSTAND, AND AGREE TO BE BOUND BY ALL TERMS, CONDITIONS, LIMITATIONS, AND WAIVERS DETAILED HEREIN.

---

## 1. Purely Educational, Experimental, & Research Purposes

The Software is developed, published, and maintained solely and strictly for **academic, educational, evaluative, interoperability, and software architecture research purposes**. It is designed to investigate:
- Native Swift 6 concurrency and asynchronous I/O execution on macOS.
- Low-level POSIX block-device streaming through Darwin character devices (`/dev/rdisk*`).
- Automated answer file formatting (`autounattend.xml`) for administrative deployment interoperability.
- Dynamic upstream distribution manifest querying and cryptographic checksum validation.

The Software is not marketed, intended, designed, or licensed for enterprise production deployments, commercial redistribution, mission-critical operations, or safety-critical computing environments.

---

## 2. Inherent Risks of Low-Level Disk Operations

**RAW DISK AND FLASH MEDIA OPERATIONS ARE INHERENTLY DESTRUCTIVE.**

The Software interacts directly with low-level storage controller subsystems, DiskArbitration, raw disk device nodes, and partition tables. Flashing an image, formatting a volume, partitioning a drive, or modifying boot sector structures will permanently, irretrievably, and destructively overwrite all pre-existing data on the target storage medium.

By using the Software, you explicitly agree that:
1. You bear **100% sole and exclusive responsibility** for identifying, selecting, verifying, and double-checking target disk identifiers (e.g., `/dev/disk*` / `/dev/rdisk*`).
2. You have backed up all critical data on any external or internal storage devices before initiating any disk-write operations.
3. The author(s), contributor(s), and copyright holder(s) cannot and will not be held liable for any loss of data, accidental formatting of wrong devices, corrupted filesystems, or hardware failures.

---

## 3. "AS-IS" Warranty Disclaimer

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW IN ANY JURISDICTION WORLDWIDE:

THE SOFTWARE IS PROVIDED ON AN **"AS IS"**, **"WITH ALL FAULTS"**, AND **"AS AVAILABLE"** BASIS, WITHOUT ANY WARRANTIES, COVENANTS, GUARANTEES, OR REPRESENTATIONS OF ANY KIND, WHETHER EXPRESS, IMPLIED, STATUTORY, OR ARISING BY COURSE OF DEALING, USAGE, OR TRADE PRACTICE.

THE AUTHOR(S), COPYRIGHT HOLDER(S), CONTRIBUTOR(S), AND AFFILIATES SPECIFICALLY DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION:
- ANY IMPLIED WARRANTIES OF **MERCHANTABILITY**, **FITNESS FOR A PARTICULAR PURPOSE**, **QUALITY**, **RELIABILITY**, **SECURITY**, OR **TITLE**;
- ANY WARRANTY THAT THE SOFTWARE WILL BE UNINTERRUPTED, TIMELY, SECURE, ACCURATE, ERROR-FREE, FREE OF BUGS, COMPATIBLE WITH ANY PARTICULAR OPERATING SYSTEM, HARDWARE, OR FIRMWARE REVISION, OR THAT ANY DEFECTS WILL BE DETECTED OR CORRECTED;
- ANY WARRANTY OF **NON-INFRINGEMENT** OF INTELLECTUAL PROPERTY OR PROPRIETARY RIGHTS OF ANY THIRD PARTY.

NO ORAL OR WRITTEN INFORMATION, DOCUMENTATION, ADVICE, OR STATEMENTS GIVEN BY THE AUTHOR(S) OR CONTRIBUTORS SHALL CREATE ANY WARRANTY OR EXTEND THE SCOPE OF THIS DISCLAIMER.

---

## 4. Comprehensive Limitation of Liability

UNDER NO CIRCUMSTANCES AND UNDER NO LEGAL, EQUITABLE, OR JURISPRUDENTIAL THEORY—WHETHER IN CONTRACT, TORT (INCLUDING NEGLIGENCE, STRICT LIABILITY, OR GROSS FAULT TO THE MAXIMUM EXTENT PERMITTED BY LAW), PRODUCT LIABILITY, INDEMNITY, OR OTHERWISE—SHALL THE AUTHOR(S), COPYRIGHT OWNER(S), MAINTAINER(S), OR ANY INDIVIDUAL OR ENTITY ASSOCIATED WITH THIS REPOSITORY BE LIABLE TO YOU OR ANY THIRD PARTY FOR:

1. ANY DIRECT, INDIRECT, INCIDENTAL, CONSEQUENTIAL, SPECIAL, PUNITIVE, EXEMPLARY, OR RETRIBUTIVE DAMAGES;
2. ANY LOSS OF PROFITS, DATA, USE, GOODWILL, BUSINESS OPPORTUNITY, CONTRACTS, OR ANTICIPATED SAVINGS;
3. ANY HARDWARE DAMAGE, NAND FLASH WEAR, CONTROLLER FAILURE, LOGIC BOARD ISSUE, SYSTEM INSTABILITY, FIRMWARE BRICKING, OR BOOTLOADER INCOMPATIBILITY;
4. ANY INTERRUPTION OF BUSINESS, COMPUTER FAILURE, CORRUPTION OF STORAGE DEVICES, OR SYSTEM DOWNTIME;
5. ANY CLAIMS, PROCEEDINGS, COSTS, EXPENSES, OR ATTORNEY'S FEES ARISING OUT OF OR IN CONNECTION WITH THE DOWNLOAD, INSTALLATION, USE, PERFORMANCE, OR INABILITY TO USE THE SOFTWARE;

EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES, AND EVEN IF ANY REMEDY SPECIFIED HEREIN IS FOUND TO HAVE FAILED OF ITS ESSENTIAL PURPOSE.

YOUR SOLE AND EXCLUSIVE REMEDY FOR DISSATISFACTION WITH THE SOFTWARE IS TO CEASE USING AND PERMANENTLY DELETE THE SOFTWARE.

---

## 5. Third-Party Trademarks & Strict Non-Affiliation

All product names, logos, brands, operating system titles, and registered or unregistered trademarks referenced within the Software or its documentation are the property of their respective trademark holders:

* **Microsoft, Windows, Windows 11, and Windows PE** are registered trademarks of Microsoft Corporation in the United States and/or other countries.
* **macOS, Apple, Apple Silicon, Mac, and DiskArbitration** are registered trademarks of Apple Inc.
* **Ubuntu** is a registered trademark of Canonical Ltd.
* **Fedora** is a registered trademark of Red Hat, Inc. / Fedora Project.
* **Debian** is a registered trademark of Software in the Public Interest, Inc.
* **Arch Linux** is a registered trademark of Aaron Griffin.
* **Rufus** is the trademark/creation of Pete Batard / Akeo Consulting.

**Macbeth is an entirely independent, open-source project.** The Software is **NOT** sponsored, endorsed, certified, vetted, affiliated with, or provided by Microsoft Corporation, Apple Inc., Canonical Ltd., Red Hat, Inc., the Debian Project, or any other trademark owner. All references to third-party operating systems or tools are made strictly for informational, descriptive, and nominative fair-use purposes.

---

## 6. End-User Compliance & Licensing Responsibility

The Software does **NOT** provide, distribute, mirror, or bundle proprietary operating system licenses, product keys, or digital activation tokens. 

Users are solely and exclusively responsible for:
1. Possessing valid, genuine, and legally acquired licenses and activation rights for any operating system images flashed or customized using the Software.
2. Complying with all applicable End User License Agreements (EULAs), Terms of Service, and software licenses associated with third-party software images.
3. Ensuring that their use of unattend automation scripts (`autounattend.xml`) and installation wrappers complies with the terms established by the software licensors.
4. Adhering to all applicable domestic and international laws, statutes, and export regulations governing data, cryptography, and computer hardware operations.

---

## 7. Global Severability & Jurisdiction

If any provision, clause, or term of this Legal Disclaimer is determined by a court of competent jurisdiction to be invalid, unlawful, unenforceable, or void under the laws of any particular jurisdiction:
1. Such determination shall not affect the validity, enforceability, or legality of any other provision, which shall remain in full force and effect.
2. The invalid or unenforceable provision shall be modified to the minimum extent necessary to make it valid and enforceable while retaining its original intent and protective scope for the author(s) and contributors.
3. This disclaimer shall be construed and interpreted broadly to provide the maximum legal protection, waiver of liability, and indemnification permitted under applicable international law.
