import Foundation

public actor WindowsPipeline {
    private var isCancelled: Bool = false
    private let powerAssertion = PowerAssertion()
    
    public init() {}
    
    public func execute(
        imageInfo: ImageInfo,
        targetDevice: DiskDevice,
        options: MacbethOptions,
        progress: @Sendable (ProgressState) -> Void
    ) async throws {
        isCancelled = false
        _ = powerAssertion.acquire()
        defer { powerAssertion.release() }
        
        var state = ProgressState(phase: .validating, statusMessage: "Validating safety gates...")
        progress(state)
        
        guard targetDevice.isSafeTarget else {
            throw NSError(
                domain: "Macbeth.WindowsPipeline",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: targetDevice.safetyRejectionReason ?? "Device is not safe for destructive operations."]
            )
        }
        
        let sanitizedLabel = LabelSanitizer.sanitize(label: options.volumeLabel, for: options.fileSystem)
        state.logs.append("Target disk: \(targetDevice.bsdName) (\(targetDevice.mediaName))")
        state.logs.append("Sanitized label: \(sanitizedLabel)")
        state.phase = .formatting
        state.statusMessage = "Partitioning and formatting \(sanitizedLabel)..."
        progress(state)
        
        let diskMgr = DiskManager()
        try await diskMgr.unmountDisk(bsdName: targetDevice.bsdName)
        try await diskMgr.partitionDisk(
            bsdName: targetDevice.bsdName,
            scheme: options.partitionScheme,
            fileSystem: options.fileSystem,
            volumeLabel: sanitizedLabel
        )
        
        // Wait for partition to be mounted
        state.phase = .preparing
        state.statusMessage = "Mounting Windows ISO..."
        progress(state)
        
        let isoMount = try await mountIso(imageURL: imageInfo.imageURL)
        defer {
            Task { _ = try? await runProcess(executable: "/usr/sbin/diskutil", arguments: ["eject", isoMount]) }
        }
        
        let targetMount = "/Volumes/\(sanitizedLabel)"
        guard FileManager.default.fileExists(atPath: targetMount) else {
            throw NSError(
                domain: "Macbeth.WindowsPipeline",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Formatted target volume not found at \(targetMount)."]
            )
        }
        
        // Touch .metadata_never_index to suppress Spotlight
        FileManager.default.createFile(atPath: (targetMount as NSString).appendingPathComponent(".metadata_never_index"), contents: nil)
        
        state.phase = .streaming
        state.statusMessage = "Copying installation files to USB..."
        progress(state)
        
        let currentLogs = state.logs
        try copyIsoContents(from: isoMount, to: targetMount, hasLargeWim: imageInfo.hasLargeWim) { bytes, total, speed in
            let pct = total > 0 ? (Double(bytes) / Double(total)) * 100.0 : 0.0
            let updatedState = ProgressState(
                phase: .streaming,
                statusMessage: String(format: "Copying files: %.1f MB/s", speed),
                bytesWritten: bytes,
                totalBytes: total,
                speedMBps: speed,
                etaSeconds: 0,
                percentage: pct,
                logs: currentLogs
            )
            progress(updatedState)
        }
        
        state.phase = .finalizing
        state.statusMessage = "Injecting Windows 11 bypasses and setup wrapper..."
        progress(state)
        
        // Inject autounattend.xml
        let unattendXml = UnattendGenerator.generate(
            arch: imageInfo.architecture,
            options: options.windowsExperience
        )
        let unattendPath = (targetMount as NSString).appendingPathComponent("autounattend.xml")
        try unattendXml.write(toFile: unattendPath, atomically: true, encoding: .utf8)
        state.logs.append("Injected autounattend.xml at root")
        
        // Inject setup.bat wrapper for in-place upgrade bypass
        if options.windowsExperience.addInPlaceUpgradeWrapper {
            let setupBat = SetupBatWrapper.generateSetupBat()
            let setupBatPath = (targetMount as NSString).appendingPathComponent("setup.bat")
            try setupBat.write(toFile: setupBatPath, atomically: true, encoding: .utf8)
            
            let autorun = SetupBatWrapper.generateAutorunInf(label: sanitizedLabel)
            let autorunPath = (targetMount as NSString).appendingPathComponent("autorun.inf")
            try autorun.write(toFile: autorunPath, atomically: true, encoding: .utf8)
            state.logs.append("Injected setup.bat and autorun.inf wrapper")
        }
        
        state.phase = .completed
        state.statusMessage = "Bootable Windows USB created successfully!"
        state.percentage = 100.0
        progress(state)
    }
    
    public func cancel() {
        isCancelled = true
    }
    
    private func mountIso(imageURL: URL) async throws -> String {
        if imageURL.path.hasPrefix("/Volumes/") {
            return imageURL.path
        }
        let output = try await runProcess(
            executable: "/usr/sbin/diskutil",
            arguments: ["image", "attach", "--plist", "-nobrowse", "-readonly", imageURL.path]
        )
        guard let data = output.data(using: .utf8),
              let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw NSError(domain: "Macbeth.WindowsPipeline", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse mounted ISO plist."])
        }
        for entity in entities {
            if let mp = entity["mount-point"] as? String {
                return mp
            }
        }
        throw NSError(domain: "Macbeth.WindowsPipeline", code: -4, userInfo: [NSLocalizedDescriptionKey: "No mount point found for attached ISO."])
    }
    
    private func copyIsoContents(
        from sourceDir: String,
        to targetDir: String,
        hasLargeWim: Bool,
        progress: @Sendable (Int64, Int64, Double) -> Void
    ) throws {
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(atPath: sourceDir)
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalBytesCopied: Int64 = 0
        let approxTotal = (try? fm.attributesOfItem(atPath: sourceDir)[.size] as? Int64) ?? 5_000_000_000
        
        for item in items {
            if isCancelled { throw NSError(domain: "Macbeth", code: -999, userInfo: [NSLocalizedDescriptionKey: "Operation cancelled."]) }
            if item.hasPrefix(".") || item.hasPrefix("._") { continue }
            
            let srcPath = (sourceDir as NSString).appendingPathComponent(item)
            let dstPath = (targetDir as NSString).appendingPathComponent(item)
            
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: srcPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    try copyDirectoryContents(from: srcPath, to: dstPath, hasLargeWim: hasLargeWim) { bytes in
                        totalBytesCopied += bytes
                        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                        let speed = elapsed > 0 ? (Double(totalBytesCopied) / (1024.0 * 1024.0)) / elapsed : 0.0
                        progress(totalBytesCopied, approxTotal, speed)
                    }
                } else {
                    // Regular file
                    if item.lowercased() == "install.wim" && hasLargeWim {
                        // Split WIM routine
                        try splitWimFile(sourceWim: srcPath, destDir: (dstPath as NSString).deletingLastPathComponent)
                    } else {
                        try copySingleFile(from: srcPath, to: dstPath)
                    }
                    let sz = (try? fm.attributesOfItem(atPath: dstPath)[.size] as? Int64) ?? 0
                    totalBytesCopied += sz
                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    let speed = elapsed > 0 ? (Double(totalBytesCopied) / (1024.0 * 1024.0)) / elapsed : 0.0
                    progress(totalBytesCopied, approxTotal, speed)
                }
            }
        }
    }
    
    private func copyDirectoryContents(
        from srcDir: String,
        to dstDir: String,
        hasLargeWim: Bool,
        progress: (Int64) -> Void
    ) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dstDir) {
            try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        }
        
        let subItems = try fm.contentsOfDirectory(atPath: srcDir)
        for sub in subItems {
            if isCancelled { throw NSError(domain: "Macbeth", code: -999, userInfo: [NSLocalizedDescriptionKey: "Operation cancelled."]) }
            if sub.hasPrefix(".") || sub.hasPrefix("._") { continue }
            
            let subSrc = (srcDir as NSString).appendingPathComponent(sub)
            let subDst = (dstDir as NSString).appendingPathComponent(sub)
            
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: subSrc, isDirectory: &isDir) {
                if isDir.boolValue {
                    try copyDirectoryContents(from: subSrc, to: subDst, hasLargeWim: hasLargeWim, progress: progress)
                } else {
                    if sub.lowercased() == "install.wim" && hasLargeWim {
                        try splitWimFile(sourceWim: subSrc, destDir: dstDir)
                    } else {
                        try copySingleFile(from: subSrc, to: subDst)
                    }
                    let sz = (try? fm.attributesOfItem(atPath: subDst)[.size] as? Int64) ?? 0
                    progress(sz)
                }
            }
        }
    }
    
    private func copySingleFile(from src: String, to dst: String) throws {
        // POSIX data-fork only copy without extended attributes to prevent ._ AppleDouble files on FAT32/ExFAT
        let fm = FileManager.default
        if fm.fileExists(atPath: dst) {
            try? fm.removeItem(atPath: dst)
        }
        let res = copyfile(src, dst, nil, copyfile_flags_t(COPYFILE_DATA | COPYFILE_NOFOLLOW))
        if res != 0 {
            try fm.copyItem(atPath: src, toPath: dst)
        }
    }
    
    private func splitWimFile(sourceWim: String, destDir: String) throws {
        let destSwm = (destDir as NSString).appendingPathComponent("install.swm")
        
        // Check for bundled wimlib-imagex or system wimlib
        let wimlibPath = Bundle.main.path(forResource: "wimlib-imagex", ofType: nil, inDirectory: "bin") ??
                         (FileManager.default.fileExists(atPath: "/opt/homebrew/bin/wimlib-imagex") ? "/opt/homebrew/bin/wimlib-imagex" : nil)
        
        if let bin = wimlibPath {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin)
            proc.arguments = ["split", sourceWim, destSwm, "3800"]
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus != 0 {
                throw NSError(domain: "Macbeth.WimSplit", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "wimlib-imagex split failed."])
            }
        } else {
            // If wimlib not found, perform standard copy if file fits, or warn
            try copySingleFile(from: sourceWim, to: destSwm.replacingOccurrences(of: ".swm", with: ".wim"))
        }
    }
    
    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: NSError(domain: "Macbeth", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
