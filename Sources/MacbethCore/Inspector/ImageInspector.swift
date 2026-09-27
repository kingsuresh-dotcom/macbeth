import Foundation

public actor ImageInspector {
    public init() {}
    
    /// Inspects a disk image or macOS installer app and returns structured ImageInfo
    public func inspect(imageURL: URL) async throws -> ImageInfo {
        let path = imageURL.path
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            throw NSError(domain: "Macbeth", code: 404, userInfo: [NSLocalizedDescriptionKey: "File does not exist: \(path)"])
        }
        
        // 1. Check for macOS Installer App
        if path.hasSuffix(".app") {
            let createInstallMedia = imageURL.appendingPathComponent("Contents/Resources/createinstallmedia")
            if fileManager.fileExists(atPath: createInstallMedia.path) {
                let appName = imageURL.deletingPathExtension().lastPathComponent
                let size = try calculateDirectorySize(url: imageURL)
                return ImageInfo(
                    imageURL: imageURL,
                    fileSizeBytes: size,
                    imageType: .macOsInstallerApp,
                    detectedOsName: appName,
                    architecture: "universal"
                )
            }
        }
        
        // 2. Check Raw Disk Images (.img, .raw, .vhd)
        let ext = imageURL.pathExtension.lowercased()
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        if ext == "img" || ext == "raw" || ext == "vhd" {
            return ImageInfo(
                imageURL: imageURL,
                fileSizeBytes: fileSize,
                imageType: .rawImage,
                detectedOsName: "Raw Disk Image (\(imageURL.lastPathComponent))",
                architecture: "universal"
            )
        }
        
        // 3. For ISO Images: Perform deep inspection
        if ext == "iso" {
            return try await inspectIso(imageURL: imageURL, fileSize: fileSize)
        }
        
        return ImageInfo(
            imageURL: imageURL,
            fileSizeBytes: fileSize,
            imageType: .unknown,
            detectedOsName: imageURL.lastPathComponent
        )
    }
    
    private func inspectIso(imageURL: URL, fileSize: Int64) async throws -> ImageInfo {
        // Mount ISO using contemporary diskutil image attach
        let attachOutput = try await runProcess(
            executable: "/usr/sbin/diskutil",
            arguments: ["image", "attach", "--plist", "-nobrowse", "-readonly", imageURL.path]
        )
        
        guard let data = attachOutput.data(using: .utf8),
              let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            // If mounting fails, treat as generic raw hybrid ISO
            return ImageInfo(
                imageURL: imageURL,
                fileSizeBytes: fileSize,
                imageType: .linuxHybridIso,
                detectedOsName: "Raw Hybrid ISO (Mount failed, DD mode available)",
                architecture: "amd64"
            )
        }
        
        // Find mount point
        var mountPoint: String? = nil
        var deviceNode: String? = nil
        for entity in entities {
            if let mp = entity["mount-point"] as? String {
                mountPoint = mp
            }
            if let dev = entity["dev-entry"] as? String {
                deviceNode = dev
            }
        }
        
        guard let mount = mountPoint else {
            // Eject device node if no mount point
            if let dev = deviceNode {
                _ = try? await runProcess(executable: "/usr/sbin/diskutil", arguments: ["eject", dev])
            }
            return ImageInfo(
                imageURL: imageURL,
                fileSizeBytes: fileSize,
                imageType: .linuxHybridIso,
                detectedOsName: "Linux Hybrid ISO (No UDF mount)",
                architecture: "amd64"
            )
        }
        
        defer {
            // Ensure disk image is always unmounted cleanly
            Task {
                _ = try? await runProcess(executable: "/usr/sbin/diskutil", arguments: ["eject", mount])
            }
        }
        
        let fm = FileManager.default
        let sourcesPath = (mount as NSString).appendingPathComponent("sources")
        let bootWim = (sourcesPath as NSString).appendingPathComponent("boot.wim")
        let installWim = (sourcesPath as NSString).appendingPathComponent("install.wim")
        let installEsd = (sourcesPath as NSString).appendingPathComponent("install.esd")
        
        // Check if Windows
        if fm.fileExists(atPath: bootWim) && (fm.fileExists(atPath: installWim) || fm.fileExists(atPath: installEsd)) {
            var wimSize: Int64 = 0
            if fm.fileExists(atPath: installWim) {
                wimSize = (try? fm.attributesOfItem(atPath: installWim)[.size] as? Int64) ?? 0
            } else if fm.fileExists(atPath: installEsd) {
                wimSize = (try? fm.attributesOfItem(atPath: installEsd)[.size] as? Int64) ?? 0
            }
            
            let hasLargeWim = wimSize > 4_000_000_000
            
            // Detect architecture
            let efiBootDir = (mount as NSString).appendingPathComponent("efi/boot")
            let hasArmBoot = fm.fileExists(atPath: (efiBootDir as NSString).appendingPathComponent("bootaa64.efi"))
            let arch = hasArmBoot ? "arm64" : "amd64"
            
            // Check for Windows 11 vs 10
            var osName = "Windows 10/11 Installation Media"
            var buildNum: Int? = nil
            var requiresPopcnt = false
            
            // Attempt to read build info
            let idwbinfo = (sourcesPath as NSString).appendingPathComponent("idwbinfo.txt")
            if let content = try? String(contentsOfFile: idwbinfo, encoding: .utf8) {
                if let match = content.range(of: "BuildLab=") {
                    let sub = content[match.upperBound...]
                    let buildStr = sub.components(separatedBy: ".").first ?? ""
                    if let b = Int(buildStr) {
                        buildNum = b
                        if b >= 26100 {
                            osName = "Windows 11 24H2+ (Build \(b))"
                            requiresPopcnt = true
                        } else if b >= 22000 {
                            osName = "Windows 11 (Build \(b))"
                        } else {
                            osName = "Windows 10 (Build \(b))"
                        }
                    }
                }
            } else {
                // If larger than 5GB, it is almost certainly Windows 11
                if fileSize > 5_000_000_000 {
                    osName = "Windows 11 Installation Media"
                    requiresPopcnt = true
                }
            }
            
            return ImageInfo(
                imageURL: imageURL,
                fileSizeBytes: fileSize,
                imageType: .windowsIso,
                detectedOsName: osName,
                architecture: arch,
                windowsBuildNumber: buildNum,
                hasLargeWim: hasLargeWim,
                wimSizeBytes: wimSize,
                requiresPopcntAdvisory: requiresPopcnt
            )
        }
        
        // Otherwise: Check for Linux Distros
        var linuxDistro = "Linux Hybrid ISO"
        let isUbuntu = fm.fileExists(atPath: (mount as NSString).appendingPathComponent(".disk")) ||
                       fm.fileExists(atPath: (mount as NSString).appendingPathComponent("casper"))
        let isArch = fm.fileExists(atPath: (mount as NSString).appendingPathComponent("arch"))
        let isFedora = fm.fileExists(atPath: (mount as NSString).appendingPathComponent("images/install.img"))
        
        if isUbuntu {
            linuxDistro = "Ubuntu / Debian Live ISO"
        } else if isArch {
            linuxDistro = "Arch Linux Live ISO"
        } else if isFedora {
            linuxDistro = "Fedora Live ISO"
        }
        
        return ImageInfo(
            imageURL: imageURL,
            fileSizeBytes: fileSize,
            imageType: .linuxHybridIso,
            detectedOsName: linuxDistro,
            architecture: "amd64"
        )
    }
    
    private func calculateDirectorySize(url: URL) throws -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(resourceValues.fileSize ?? 0)
        }
        return total
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
                    let err = NSError(
                        domain: "Macbeth.ImageInspector",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: output]
                    )
                    continuation.resume(throwing: err)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
