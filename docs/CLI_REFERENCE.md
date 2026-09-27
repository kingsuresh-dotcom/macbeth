# Macbeth CLI Reference Manual

`macbeth` is the standalone command-line interface for the Macbeth media engine.

## Command Overview

```
USAGE:
  macbeth list [--all]
     List available storage devices (filters out internal drives by default).
     
  macbeth inspect <path-to-image>
     Deep inspect an ISO or macOS installer app.
     
  macbeth test-fake-flash <bsd-device>
     Run 10-second counterfeit flash boundary probe (e.g. /dev/disk4).
     
  macbeth write --device <bsd-device> --image <path-to-iso> [options]
     (Requires root: sudo macbeth write ...)
     Options:
       --label <name>       Custom volume label
       --no-tpm-bypass      Disable Windows 11 TPM & Secure Boot bypass
       --no-msa-bypass      Disable Microsoft Account bypass
       --dd                 Force raw DD mode for hybrid ISOs
```

---

## Commands

### 1. `list`
Scans and presents connected storage devices:
```bash
macbeth list
```
**Flags:**
* `--all`: Include internal system drives (for diagnostic inspection only).

### 2. `inspect`
Analyzes an ISO image or macOS installer package and extracts architectural metadata, build numbers, payload sizes, and bootloader compatibility:
```bash
macbeth inspect /path/to/windows11.iso
```

### 3. `test-fake-flash`
Executes a quick 10-second boundary verification test to ensure the storage device is not a counterfeit drive with spoofed flash boundaries:
```bash
macbeth test-fake-flash /dev/disk4
```

### 4. `write`
Writes the specified installation image to the external device. **Requires administrative privileges (`sudo`)**:
```bash
sudo macbeth write \
  --device /dev/disk4 \
  --image ~/Downloads/Win11_24H2_English_x64.iso \
  --label "WIN11_INSTALL"
```
**Options:**
* `--device <bsd-device>`: Target disk (e.g. `/dev/disk4`). Automatically converts to raw device node (`/dev/rdisk4`) for fast streaming.
* `--image <path-to-image>`: Path to `.iso`, `.img`, or `.app`.
* `--label <string>`: Custom target partition label (sanitized according to target filesystem limits).
* `--no-tpm-bypass`: Retains standard Windows 11 TPM 2.0 and Secure Boot requirement checks.
* `--no-msa-bypass`: Does not enforce local offline account creation.
* `--dd`: Forces unbuffered raw block streaming (recommended for hybrid Linux ISOs like Arch or Ubuntu Live).
