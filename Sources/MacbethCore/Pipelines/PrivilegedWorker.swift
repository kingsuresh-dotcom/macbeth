import Foundation

private final class IPCReporter: @unchecked Sendable {
    let ipcPath: String
    let encoder: JSONEncoder
    private var lastReportTime: CFAbsoluteTime = 0
    
    init(ipcPath: String) {
        self.ipcPath = ipcPath
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        self.encoder = enc
    }
    
    func report(state: ProgressState, isFinished: Bool, error: String? = nil, force: Bool = false) {
        let now = CFAbsoluteTimeGetCurrent()
        // Throttle disk updates to max 10 Hz unless completing or reporting an error/phase change
        if !force && !isFinished && error == nil && (now - lastReportTime < 0.09) {
            return
        }
        lastReportTime = now
        
        let report = WorkerProgress(state: state, isFinished: isFinished, errorMessage: error)
        if let data = try? encoder.encode(report) {
            let tempURL = URL(fileURLWithPath: ipcPath + ".tmp")
            let finalURL = URL(fileURLWithPath: ipcPath)
            if (try? data.write(to: tempURL, options: .atomic)) != nil {
                _ = try? FileManager.default.removeItem(at: finalURL)
                _ = try? FileManager.default.moveItem(at: tempURL, to: finalURL)
            }
        }
    }
}

public struct PrivilegedWorker: Sendable {
    public static func execute(job: WorkerJob) async throws {
        let reporter = IPCReporter(ipcPath: job.progressIPCPath)
        
        do {
            switch job.operation {
            case .rawStream:
                reporter.report(
                    state: ProgressState(phase: .unmounting, statusMessage: "Unmounting target drive...", logs: ["Starting elevated high-throughput streaming worker..."]),
                    isFinished: false,
                    force: true
                )
                
                let streamer = PosixRawStreamer()
                try streamer.stream(sourcePath: job.sourcePath, destinationBSD: job.destinationBSD, expectedTotalBytes: job.totalBytes) { written, total, speed in
                    let pct = total > 0 ? (Double(written) / Double(total)) * 100.0 : 0.0
                    let state = ProgressState(
                        phase: .streaming,
                        statusMessage: String(format: "Streaming: %.1f%% (%.1f MB/s)", pct, speed),
                        bytesWritten: written,
                        totalBytes: total,
                        speedMBps: speed,
                        percentage: pct
                    )
                    reporter.report(state: state, isFinished: false)
                }
                
                reporter.report(
                    state: ProgressState(phase: .completed, statusMessage: "Write completed successfully!", percentage: 100.0, logs: ["Raw image stream written and synchronized."]),
                    isFinished: true,
                    force: true
                )
                
            case .windowsPipeline:
                reporter.report(
                    state: ProgressState(phase: .validating, statusMessage: "Inspecting Windows image...", logs: ["Starting elevated Windows pipeline worker..."]),
                    isFinished: false,
                    force: true
                )
                
                let sourceURL = URL(fileURLWithPath: job.sourcePath)
                let inspector = ImageInspector()
                var imgInfo = try? await inspector.inspect(imageURL: sourceURL)
                if imgInfo == nil {
                    imgInfo = ImageInfo(
                        imageURL: sourceURL,
                        fileSizeBytes: job.totalBytes,
                        imageType: .windowsIso,
                        detectedOsName: "Windows Installation Media",
                        architecture: "amd64",
                        hasLargeWim: true
                    )
                }
                guard let finalInfo = imgInfo else {
                    throw NSError(domain: "Macbeth.Worker", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to read Windows image structure."])
                }
                
                let diskMgr = DiskManager()
                let disks = try await diskMgr.listDisks(includeUnsafe: true)
                guard let target = disks.first(where: { $0.bsdName == job.destinationBSD || $0.bsdName == "/dev/" + job.destinationBSD }) else {
                    throw NSError(domain: "Macbeth.Worker", code: 404, userInfo: [NSLocalizedDescriptionKey: "Device \(job.destinationBSD) not found."])
                }
                
                let pipeline = WindowsPipeline()
                try await pipeline.execute(imageInfo: finalInfo, targetDevice: target, options: job.options) { current in
                    reporter.report(state: current, isFinished: false)
                }
                
                reporter.report(
                    state: ProgressState(phase: .completed, statusMessage: "Windows bootable media created successfully!", percentage: 100.0),
                    isFinished: true,
                    force: true
                )
            }
        } catch {
            let errState = ProgressState(
                phase: .failed,
                statusMessage: "Error: \(error.localizedDescription)",
                logs: ["ERROR: \(error.localizedDescription)"]
            )
            reporter.report(state: errState, isFinished: true, error: error.localizedDescription, force: true)
            throw error
        }
    }
}
