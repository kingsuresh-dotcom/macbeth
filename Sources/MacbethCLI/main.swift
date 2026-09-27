import Foundation
import MacbethCore

@main
struct MacbethCLI {
    static func main() async {
        let args = CommandLine.arguments
        if args.count < 2 {
            printUsage()
            return
        }
        
        let command = args[1]
        switch command {
        case "list":
            await handleList(showAll: args.contains("--all"))
            
        case "inspect":
            if args.count < 3 {
                print("Error: Missing image path. Usage: macbeth inspect <path-to-iso>")
                exit(1)
            }
            await handleInspect(path: args[2])
            
        case "test-fake-flash":
            if args.count < 3 {
                print("Error: Missing device node. Usage: macbeth test-fake-flash <bsd-device>")
                exit(1)
            }
            handleFakeFlash(device: args[2])
            
        case "worker":
            var jobPath: String? = nil
            var i = 2
            while i < args.count {
                if args[i] == "--job" && i + 1 < args.count {
                    jobPath = args[i + 1]
                    i += 1
                }
                i += 1
            }
            guard let path = jobPath else {
                print("Error: Missing --job <path-to-job.json>")
                exit(1)
            }
            await handleWorker(jobPath: path)
            
        case "write":
            await handleWrite(args: Array(args.dropFirst(2)))
            
        case "version", "-v", "--version":
            print("macbeth version 1.0.0 (Macbeth for macOS - 2026 Native Edition)")
            
        case "help", "-h", "--help":
            printUsage()
            
        default:
            print("Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }
    
    static func printUsage() {
        print("""
        ======================================================================
         Macbeth for macOS (macbeth) - The Native Bootable Media Creator
        ======================================================================
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
        """)
    }
    
    static func handleWorker(jobPath: String) async {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: jobPath))
            let job = try JSONDecoder().decode(WorkerJob.self, from: data)
            try await PrivilegedWorker.execute(job: job)
            exit(0)
        } catch {
            fputs("Worker execution failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    
    static func handleList(showAll: Bool) async {
        let mgr = DiskManager()
        do {
            let disks = try await mgr.listDisks(includeUnsafe: showAll)
            if disks.isEmpty {
                print("No safe removable storage devices detected.")
                if !showAll {
                    print("Tip: Run 'macbeth list --all' to inspect all system disks.")
                }
                return
            }
            
            print("Discovered Storage Devices:")
            print("----------------------------------------------------------------------")
            for disk in disks {
                let statusBadge = disk.isSafeTarget ? "[SAFE TARGET]" : "[PROTECTED - BLOCKED]"
                print("\(statusBadge) \(disk.displayName)")
                print("   Protocol: \(disk.busProtocol) | Removable: \(disk.isRemovable) | Internal: \(disk.isInternal)")
                if let reason = disk.safetyRejectionReason {
                    print("   Safety reason: \(reason)")
                }
                for part in disk.partitions {
                    print("   └─ \(part.bsdName): \(part.name ?? "Untitled") (\(part.filesystem ?? "Unknown"), \(ByteCountFormatter.string(fromByteCount: part.sizeBytes, countStyle: .decimal)))")
                }
                print("")
            }
        } catch {
            print("Failed to enumerate disks: \(error.localizedDescription)")
        }
    }
    
    static func handleInspect(path: String) async {
        let url = URL(fileURLWithPath: path)
        let inspector = ImageInspector()
        do {
            print("Inspecting \(url.lastPathComponent)...")
            let info = try await inspector.inspect(imageURL: url)
            print("----------------------------------------------------------------------")
            print("Detected OS:     \(info.detectedOsName)")
            print("Image Type:      \(info.imageType.rawValue)")
            print("File Size:       \(info.formattedSize)")
            print("Architecture:    \(info.architecture)")
            if let wimSize = info.wimSizeBytes {
                let formattedWim = ByteCountFormatter.string(fromByteCount: wimSize, countStyle: .decimal)
                print("OS Image (WIM):  \(formattedWim) (\(info.hasLargeWim ? "Requires Split SWM" : "Fits FAT32 directly"))")
            }
            if info.requiresPopcntAdvisory {
                print("Advisory:        Requires CPU with SSE 4.2 / POPCNT support (Windows 11 24H2+).")
            }
            print("----------------------------------------------------------------------")
        } catch {
            print("Inspection failed: \(error.localizedDescription)")
        }
    }
    
    static func handleFakeFlash(device: String) {
        let clean = DeviceNodeSanitizer.clean(device)
        print("Starting 10-second counterfeit flash boundary probe on \(clean)...")
        let detector = FakeFlashDetector()
        do {
            // Assume 1TB check range
            let result = try detector.testDrive(bsdName: clean, totalSizeBytes: 1024 * 1024 * 1024 * 1024) { gb, msg in
                print("  [\(gb)GB] \(msg)")
            }
            if result.isGenuine {
                print("SUCCESS: \(result.message)")
            } else {
                print("ALERT: \(result.message)")
            }
        } catch {
            print("Probe failed: \(error.localizedDescription)")
        }
    }
    
    static func handleWrite(args: [String]) async {
        if geteuid() != 0 {
            print("======================================================================")
            print(" ERROR: Root privileges are required to write raw disk blocks on macOS.")
            print(" Please run this command with sudo:")
            print("   sudo macbeth write \(args.joined(separator: " "))")
            print("======================================================================")
            exit(1)
        }
        
        var device: String? = nil
        var image: String? = nil
        var label = "MACBETH_USB"
        var bypassTPM = true
        var bypassMSA = true
        var forceDD = false
        
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--device":
                if i + 1 < args.count { device = args[i + 1]; i += 1 }
            case "--image":
                if i + 1 < args.count { image = args[i + 1]; i += 1 }
            case "--label":
                if i + 1 < args.count { label = args[i + 1]; i += 1 }
            case "--no-tpm-bypass":
                bypassTPM = false
            case "--no-msa-bypass":
                bypassMSA = false
            case "--dd":
                forceDD = true
            default:
                break
            }
            i += 1
        }
        
        guard let dev = device, let img = image else {
            print("Error: Missing --device or --image. Run 'macbeth write --help' for usage.")
            exit(1)
        }
        
        let imgURL = URL(fileURLWithPath: img)
        let inspector = ImageInspector()
        do {
            let imgInfo = try await inspector.inspect(imageURL: imgURL)
            let diskMgr = DiskManager()
            let disks = try await diskMgr.listDisks(includeUnsafe: true)
            guard let target = disks.first(where: { $0.bsdName == dev || $0.bsdName == "/dev/" + dev }) else {
                print("Error: Device \(dev) not found.")
                exit(1)
            }
            
            guard target.isSafeTarget else {
                print("CRITICAL SAFETY BLOCK: Target \(target.bsdName) is blocked from erase:")
                print("Reason: \(target.safetyRejectionReason ?? "Internal or system disk")")
                exit(1)
            }
            
            var exp = WindowsExperience()
            exp.bypassTPMAndSecureBoot = bypassTPM
            exp.bypassOnlineAccount = bypassMSA
            
            let options = MacbethOptions(
                partitionScheme: .gpt,
                targetSystem: .uefiNonCsm,
                fileSystem: .exfat,
                volumeLabel: label,
                windowsExperience: exp
            )
            
            print("Beginning burn operation...")
            print("  Image:  \(imgInfo.detectedOsName) (\(imgInfo.formattedSize))")
            print("  Target: \(target.displayName)")
            print("----------------------------------------------------------------------")
            
            if forceDD || imgInfo.imageType == .linuxHybridIso || imgInfo.imageType == .rawImage {
                let streamer = PosixRawStreamer()
                try streamer.stream(sourceURL: imgURL, destinationBSD: target.bsdName) { written, total, speed in
                    let pct = total > 0 ? (Double(written) / Double(total)) * 100.0 : 0.0
                    print(String(format: "\rProgress: %5.1f%% | Speed: %6.1f MB/s", pct, speed), terminator: "")
                    fflush(stdout)
                }
                print("\nRaw DD stream completed successfully.")
            } else {
                let pipeline = WindowsPipeline()
                try await pipeline.execute(imageInfo: imgInfo, targetDevice: target, options: options) { state in
                    print("\r[\(state.phase.rawValue)] \(state.statusMessage)", terminator: "")
                    fflush(stdout)
                }
                print("\nWindows media created successfully.")
            }
        } catch {
            print("\nBurn failed: \(error.localizedDescription)")
            exit(1)
        }
    }
}
