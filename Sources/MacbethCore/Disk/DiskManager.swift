import Foundation

public actor DiskManager {
    public init() {}
    
    /// Lists all attached storage devices, evaluating safety and filtering out system internal disks by default.
    public func listDisks(includeUnsafe: Bool = false) async throws -> [DiskDevice] {
        let listPlist = try await runCommandAndParsePlist(["diskutil", "list", "-plist"])
        guard let wholeDisks = listPlist["WholeDisks"] as? [String] else {
            return []
        }
        
        var devices: [DiskDevice] = []
        for diskId in wholeDisks {
            let cleanId = DeviceNodeSanitizer.clean(diskId)
            guard !cleanId.isEmpty else { continue }
            
            do {
                let info = try await runCommandAndParsePlist(["diskutil", "info", "-plist", cleanId])
                let safety = DiskSafety.evaluateSafety(info: info)
                
                let bsdName = "/dev/" + cleanId
                let mediaName = (info["MediaName"] as? String) ?? (info["IORegistryEntryName"] as? String) ?? "USB Disk"
                let totalSize = (info["TotalSize"] as? Int64) ?? 0
                let blockSize = (info["DeviceBlockSize"] as? Int) ?? 512
                let busProtocol = (info["BusProtocol"] as? String) ?? "Unknown"
                let isInternal = (info["Internal"] as? Bool) ?? true
                let isRemovable = (info["RemovableMedia"] as? Bool) ?? false
                let isEjectable = (info["Ejectable"] as? Bool) ?? false
                let partitionScheme = info["Content"] as? String
                
                // Parse partitions if any
                var partitions: [DiskPartition] = []
                if let parts = info["Partitions"] as? [[String: Any]] {
                    for p in parts {
                        let pId = (p["DeviceIdentifier"] as? String) ?? ""
                        let pName = p["VolumeName"] as? String
                        let pFs = p["Content"] as? String
                        let pSize = (p["Size"] as? Int64) ?? 0
                        let pMount = p["MountPoint"] as? String
                        partitions.append(DiskPartition(
                            bsdName: "/dev/" + pId,
                            name: pName,
                            filesystem: pFs,
                            sizeBytes: pSize,
                            mountPoint: pMount
                        ))
                    }
                }
                
                let device = DiskDevice(
                    bsdName: bsdName,
                    mediaName: mediaName,
                    totalSizeBytes: totalSize,
                    blockSizeBytes: blockSize,
                    busProtocol: busProtocol,
                    isInternal: isInternal,
                    isRemovable: isRemovable,
                    isEjectable: isEjectable,
                    partitionScheme: partitionScheme,
                    partitions: partitions,
                    isSafeTarget: safety.isSafe,
                    safetyRejectionReason: safety.reason
                )
                
                if safety.isSafe || includeUnsafe {
                    devices.append(device)
                }
            } catch {
                // Skip disks that cannot be queried
                continue
            }
        }
        
        return devices
    }
    
    /// Unmounts all partitions on the disk with retry logic.
    public func unmountDisk(bsdName: String, maxRetries: Int = 3) async throws {
        let clean = DeviceNodeSanitizer.clean(bsdName)
        var lastError: Error?
        for _ in 1...maxRetries {
            do {
                _ = try await runProcess(executable: "/usr/sbin/diskutil", arguments: ["unmountDisk", "force", clean])
                return
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms backoff
            }
        }
        if let err = lastError { throw err }
    }
    
    /// Ejects a disk cleanly using modern diskutil eject.
    public func ejectDisk(bsdName: String) async throws {
        let clean = DeviceNodeSanitizer.clean(bsdName)
        _ = try await runProcess(executable: "/usr/sbin/diskutil", arguments: ["eject", clean])
    }
    
    /// Partitions a disk using the designated scheme and filesystem.
    public func partitionDisk(
        bsdName: String,
        scheme: PartitionScheme,
        fileSystem: TargetFileSystem,
        volumeLabel: String
    ) async throws {
        let clean = DeviceNodeSanitizer.clean(bsdName)
        let schemeArg = (scheme == .gpt) ? "GPT" : "MBR"
        
        let fsArg: String
        switch fileSystem {
        case .fat32:
            fsArg = "MS-DOS FAT32"
        case .exfat:
            fsArg = "ExFAT"
        case .macOsExtended:
            fsArg = "JHFS+"
        case .apfs:
            fsArg = "APFS"
        case .ntfs:
            fsArg = "MS-DOS FAT32" // Fallback partition for UEFI:NTFS preparation
        }
        
        // Execute partitionDisk
        _ = try await runProcess(
            executable: "/usr/sbin/diskutil",
            arguments: ["partitionDisk", clean, schemeArg, fsArg, volumeLabel, "100%"]
        )
    }
    
    // MARK: - Helper Process Execution
    
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
                    let err = NSError(
                        domain: "Macbeth.DiskManager",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Command failed: \(executable) \(arguments.joined(separator: " ")) -> \(output)"]
                    )
                    continuation.resume(throwing: err)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func runCommandAndParsePlist(_ command: [String]) async throws -> [String: Any] {
        guard let first = command.first else { throw NSError(domain: "Macbeth", code: -1) }
        let args = Array(command.dropFirst())
        let xmlString = try await runProcess(executable: first.hasPrefix("/") ? first : "/usr/sbin/" + first, arguments: args)
        guard let data = xmlString.data(using: .utf8),
              let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "Macbeth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse plist output"])
        }
        return plist
    }
}
