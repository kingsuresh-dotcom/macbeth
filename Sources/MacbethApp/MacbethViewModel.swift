import Foundation
import SwiftUI
import Combine
import MacbethCore

@MainActor
public final class MacbethViewModel: ObservableObject {
    // Disks
    @Published public var availableDevices: [DiskDevice] = []
    @Published public var selectedDevice: DiskDevice? = nil
    @Published public var isLoadingDevices: Bool = false
    
    // Image
    @Published public var selectedImageURL: URL? = nil
    @Published public var imageInfo: ImageInfo? = nil
    @Published public var isInspectingImage: Bool = false
    
    // Options
    @Published public var partitionScheme: PartitionScheme = .gpt
    @Published public var targetSystem: TargetSystem = .uefiNonCsm
    @Published public var fileSystem: TargetFileSystem = .exfat
    @Published public var volumeLabel: String = "MACBETH_USB"
    @Published public var quickFormat: Bool = true
    @Published public var checkBadBlocks: Bool = false
    @Published public var testFakeFlash: Bool = false
    @Published public var windowsExperience: WindowsExperience = WindowsExperience()
    
    // UI Sheets
    @Published public var showWindowsExperienceSheet: Bool = false
    @Published public var showDownloadSheet: Bool = false
    @Published public var linuxDistros: [DistroRelease] = LinuxCatalog.standardDistros
    @Published public var isResolvingLinuxDistros: Bool = false
    @Published public var showLogSheet: Bool = false
    @Published public var showFullDiskAccessSheet: Bool = false
    @Published public var showConfirmEraseAlert: Bool = false
    @Published public var alertErrorMessage: String? = nil
    @Published public var isTargetedForDrop: Bool = false
    
    // Progress
    @Published public var isBurning: Bool = false
    @Published public var burnPhase: BurnPhase = .idle
    @Published public var statusText: String = "READY"
    @Published public var progressPercentage: Double = 0.0
    @Published public var currentSpeedMBps: Double = 0.0
    @Published public var logs: [String] = []
    
    private let diskManager = DiskManager()
    private let inspector = ImageInspector()
    private let winPipeline = WindowsPipeline()
    private let rawStreamer = PosixRawStreamer()
    private var activeElevatedProcess: Process? = nil
    
    public init() {
        Task {
            await refreshDevices()
        }
    }
    
    public func refreshDevices() async {
        isLoadingDevices = true
        defer { isLoadingDevices = false }
        do {
            let disks = try await diskManager.listDisks(includeUnsafe: false)
            availableDevices = disks
            if selectedDevice == nil || !disks.contains(where: { $0.id == selectedDevice?.id }) {
                selectedDevice = disks.first
            }
        } catch {
            logs.append("Failed to refresh devices: \(error.localizedDescription)")
        }
    }
    
    public func refreshLinuxDistros() async {
        guard !isResolvingLinuxDistros else { return }
        isResolvingLinuxDistros = true
        defer { isResolvingLinuxDistros = false }
        let latest = await LinuxCatalog.fetchLatestDistros()
        linuxDistros = latest
    }
    
    public func selectImage(url: URL) async {
        selectedImageURL = url
        isInspectingImage = true
        defer { isInspectingImage = false }
        
        do {
            let info = try await inspector.inspect(imageURL: url)
            imageInfo = info
            logs.append("Loaded image: \(info.detectedOsName) (\(info.formattedSize))")
            
            // Adjust defaults based on image type
            if info.imageType == .windowsIso {
                volumeLabel = LabelSanitizer.sanitize(label: "WIN11_USB", for: .exfat)
                fileSystem = .exfat
                partitionScheme = .gpt
                targetSystem = .uefiNonCsm
                // Trigger Windows 11 Experience modal on Windows ISO selection!
                showWindowsExperienceSheet = true
            } else if info.imageType == .linuxHybridIso {
                let name = url.deletingPathExtension().lastPathComponent
                volumeLabel = LabelSanitizer.sanitize(label: name, for: .exfat)
                fileSystem = .exfat
            }
        } catch {
            alertErrorMessage = "Failed to inspect image: \(error.localizedDescription)"
        }
    }
    
    public func onStartClicked() {
        guard let device = selectedDevice else {
            alertErrorMessage = "Please select a target USB device."
            return
        }
        guard selectedImageURL != nil else {
            alertErrorMessage = "Please select an ISO or disk image."
            return
        }
        guard device.isSafeTarget else {
            alertErrorMessage = "Safety error: \(device.safetyRejectionReason ?? "Device is not safe.")"
            return
        }
        
        // Present destructive warning confirmation dialog
        showConfirmEraseAlert = true
    }
    
    public func startBurn() async {
        guard let device = selectedDevice, let info = imageInfo else { return }
        isBurning = true
        burnPhase = .preparing
        progressPercentage = 0.0
        statusText = "Preparing..."
        logs.append("----------------------------------------------------------------------")
        logs.append("Burn operation started for \(device.displayName)")
        
        let options = MacbethOptions(
            partitionScheme: partitionScheme,
            targetSystem: targetSystem,
            fileSystem: fileSystem,
            volumeLabel: volumeLabel,
            quickFormat: quickFormat,
            checkBadBlocks: checkBadBlocks,
            testFakeFlash: testFakeFlash,
            windowsExperience: windowsExperience
        )
        
        let operation: WorkerOperation = (info.imageType == .linuxHybridIso || info.imageType == .rawImage) ? .rawStream : .windowsPipeline
        
        // 1. If already root, run directly in-process
        if geteuid() == 0 {
            do {
                if operation == .rawStream {
                    burnPhase = .streaming
                    try rawStreamer.stream(sourceURL: info.imageURL, destinationBSD: device.bsdName) { [weak self] written, total, speed in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.progressPercentage = total > 0 ? (Double(written) / Double(total)) * 100.0 : 0.0
                            self.currentSpeedMBps = speed
                            self.statusText = String(format: "Streaming: %.1f%% (%.1f MB/s)", self.progressPercentage, speed)
                        }
                    }
                    burnPhase = .completed
                    statusText = "Completed successfully!"
                    progressPercentage = 100.0
                    logs.append("Raw stream finished successfully.")
                } else {
                    try await winPipeline.execute(imageInfo: info, targetDevice: device, options: options) { [weak self] state in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.burnPhase = state.phase
                            self.progressPercentage = state.percentage
                            self.currentSpeedMBps = state.speedMBps
                            self.statusText = state.statusMessage
                            if !state.logs.isEmpty {
                                self.logs.append(contentsOf: state.logs)
                            }
                        }
                    }
                    burnPhase = .completed
                    statusText = "Completed successfully!"
                    progressPercentage = 100.0
                    logs.append("Windows bootable media created successfully.")
                }
            } catch {
                burnPhase = .failed
                statusText = "Error: \(error.localizedDescription)"
                alertErrorMessage = error.localizedDescription
                logs.append("ERROR: \(error.localizedDescription)")
            }
            isBurning = false
            return
        }
        
        // 2. Unprivileged GUI context: launch elevated worker via macOS Authorization with FIFO bridge
        await launchElevatedBurn(device: device, info: info, options: options, operation: operation)
    }
    
    private func launchElevatedBurn(
        device: DiskDevice,
        info: ImageInfo,
        options: MacbethOptions,
        operation: WorkerOperation
    ) async {
        let runId = UUID().uuidString
        let jobFile = URL(fileURLWithPath: "/tmp/macbeth_job_\(runId).json")
        let ipcFile = URL(fileURLWithPath: "/tmp/macbeth_ipc_\(runId).json")
        let fifoPath = "/tmp/macbeth_pipe_\(runId)"
        
        // Ignore SIGPIPE so a closed reader doesn't crash the GUI app
        signal(SIGPIPE, SIG_IGN)
        
        let totalSize = (try? FileManager.default.attributesOfItem(atPath: info.imageURL.path)[.size] as? Int64) ?? 0
        var sourcePathForWorker = info.imageURL.path
        var feederTask: Task<Void, Never>? = nil
        
        if operation == .rawStream {
            // Create FIFO in /tmp to bridge between user TCC and elevated worker
            let mkRes = mkfifo(fifoPath, 0o666)
            if mkRes == 0 {
                sourcePathForWorker = fifoPath
                let srcURL = info.imageURL
                
                feederTask = Task.detached {
                    let srcFd = open(srcURL.path, O_RDONLY)
                    guard srcFd >= 0 else { return }
                    defer { close(srcFd) }
                    
                    let fifoFd = open(fifoPath, O_WRONLY)
                    guard fifoFd >= 0 else { return }
                    defer { close(fifoFd) }
                    
                    let chunkSize = 4 * 1024 * 1024 // 4MB aligned to NAND superpages
                    var rawBuf: UnsafeMutableRawPointer? = nil
                    guard posix_memalign(&rawBuf, 4096, chunkSize) == 0, let buffer = rawBuf else { return }
                    defer { free(buffer) }
                    
                    while true {
                        let bytesRead = Darwin.read(srcFd, buffer, chunkSize)
                        if bytesRead <= 0 { break }
                        
                        var written = 0
                        var hasError = false
                        while written < bytesRead {
                            let n = Darwin.write(fifoFd, buffer.advanced(by: written), bytesRead - written)
                            if n <= 0 { hasError = true; break }
                            written += n
                        }
                        if hasError { break }
                    }
                }
            }
        }
        
        defer {
            try? FileManager.default.removeItem(at: jobFile)
            try? FileManager.default.removeItem(at: ipcFile)
            unlink(fifoPath)
            feederTask?.cancel()
        }
        
        let job = WorkerJob(
            operation: operation,
            sourcePath: sourcePathForWorker,
            totalBytes: totalSize,
            destinationBSD: device.bsdName,
            options: options,
            progressIPCPath: ipcFile.path
        )
        
        do {
            let jobData = try JSONEncoder().encode(job)
            try jobData.write(to: jobFile)
        } catch {
            alertErrorMessage = "Failed to create worker job: \(error.localizedDescription)"
            isBurning = false
            return
        }
        
        // Resolve path to macbeth worker binary
        let bundleExec = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/macbeth").path
        let helperBinary: String
        if FileManager.default.fileExists(atPath: bundleExec) {
            helperBinary = bundleExec
        } else if FileManager.default.fileExists(atPath: "/Applications/Macbeth.app/Contents/MacOS/macbeth") {
            helperBinary = "/Applications/Macbeth.app/Contents/MacOS/macbeth"
        } else if FileManager.default.fileExists(atPath: "/Users/suresh/Macbeth/.build/debug/macbeth") {
            helperBinary = "/Users/suresh/Macbeth/.build/debug/macbeth"
        } else {
            helperBinary = "/Applications/Macbeth.app/Contents/MacOS/macbeth"
        }
        
        logs.append("Elevating privileges for raw device write via macOS authorization...")
        statusText = "Waiting for administrator authorization..."
        
        // Start polling IPC progress file
        let pollTask = Task { @MainActor [weak self] in
            var lastLogsCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000) // ~80ms smooth refresh
                guard let self = self else { break }
                if let data = try? Data(contentsOf: ipcFile),
                   let report = try? JSONDecoder().decode(WorkerProgress.self, from: data) {
                    self.burnPhase = report.state.phase
                    self.statusText = report.state.statusMessage
                    self.progressPercentage = report.state.percentage
                    self.currentSpeedMBps = report.state.speedMBps
                    if report.state.logs.count > lastLogsCount {
                        let newLogs = report.state.logs.dropFirst(lastLogsCount)
                        self.logs.append(contentsOf: newLogs)
                        lastLogsCount = report.state.logs.count
                    }
                }
            }
        }
        
        // Execute osascript in background thread
        let result: Result<Void, Error> = await Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [
                "-e", "set bin to quoted form of \"\(helperBinary)\"",
                "-e", "set arg to quoted form of \"\(jobFile.path)\"",
                "-e", "do shell script bin & \" worker --job \" & arg with administrator privileges"
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe
            
            await MainActor.run { [weak self] in
                self?.activeElevatedProcess = process
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                await MainActor.run { [weak self] in
                    self?.activeElevatedProcess = nil
                }
                
                if process.terminationStatus == 0 {
                    return .success(())
                } else {
                    let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                    var msg = String(data: errData, encoding: .utf8) ?? "Worker execution failed."
                    // Clean up AppleScript error prefix if present
                    if let colonIdx = msg.range(of: "execution error: ") {
                        msg = String(msg[colonIdx.upperBound...])
                    }
                    return .failure(NSError(
                        domain: "Macbeth.ElevatedWorker",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: msg.trimmingCharacters(in: .whitespacesAndNewlines)]
                    ))
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.activeElevatedProcess = nil
                }
                return .failure(error)
            }
        }.value
        
        pollTask.cancel()
        _ = await pollTask.result
        _ = await feederTask?.result
        
        // Read final progress report
        if let data = try? Data(contentsOf: ipcFile),
           let report = try? JSONDecoder().decode(WorkerProgress.self, from: data) {
            self.burnPhase = report.state.phase
            self.statusText = report.state.statusMessage
            self.progressPercentage = report.state.percentage
            self.currentSpeedMBps = report.state.speedMBps
            if let err = report.errorMessage {
                self.alertErrorMessage = err
                self.burnPhase = .failed
                if err.contains("errno 1") || err.contains("Operation not permitted") {
                    self.statusText = "Full Disk Access required in System Settings."
                    self.showFullDiskAccessSheet = true
                } else {
                    self.statusText = "Error: \(err)"
                }
                self.logs.append("ERROR: \(err)")
            }
        }
        
        switch result {
        case .success:
            if burnPhase != .failed {
                burnPhase = .completed
                statusText = "Completed successfully!"
                progressPercentage = 100.0
                logs.append("Burn operation finished successfully.")
            }
        case .failure(let err):
            let nsErr = err as NSError
            let desc = nsErr.localizedDescription
            if desc.contains("User canceled") || desc.contains("-128") {
                burnPhase = .idle
                statusText = "Authorization cancelled by user."
                logs.append("Authorization cancelled by user.")
            } else if desc.contains("errno 1") || desc.contains("Operation not permitted") {
                burnPhase = .failed
                statusText = "Full Disk Access required in System Settings."
                alertErrorMessage = "macOS requires Full Disk Access permission to write to physical drives. Please enable Full Disk Access in System Settings."
                logs.append("ERROR: Full Disk Access permission is required by macOS kernel.")
                showFullDiskAccessSheet = true
            } else {
                burnPhase = .failed
                statusText = "Error: \(desc)"
                alertErrorMessage = desc
                logs.append("ERROR: \(desc)")
            }
        }
        
        isBurning = false
    }
    
    public func cancelBurn() {
        rawStreamer.cancel()
        activeElevatedProcess?.terminate()
        activeElevatedProcess = nil
        Task {
            await winPipeline.cancel()
            isBurning = false
            statusText = "Cancelled by user."
            logs.append("Burn operation cancelled.")
        }
    }
}
