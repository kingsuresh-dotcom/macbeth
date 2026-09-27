import Foundation

public enum BurnPhase: String, Sendable, Codable {
    case idle = "Ready"
    case validating = "Validating target and image..."
    case preparing = "Acquiring locks and mounting image..."
    case unmounting = "Unmounting target drive..."
    case formatting = "Creating partition table and formatting..."
    case streaming = "Writing data to drive..."
    case finalizing = "Finalizing boot files and metadata..."
    case verifying = "Verifying data integrity..."
    case completed = "Successfully completed!"
    case rollingBack = "Rolling back changes due to error..."
    case failed = "Operation failed."
}

public struct ProgressState: Sendable, Codable {
    public var phase: BurnPhase
    public var statusMessage: String
    public var bytesWritten: Int64
    public var totalBytes: Int64
    public var speedMBps: Double
    public var etaSeconds: Int
    public var percentage: Double
    public var logs: [String]
    
    public init(
        phase: BurnPhase = .idle,
        statusMessage: String = "Ready",
        bytesWritten: Int64 = 0,
        totalBytes: Int64 = 0,
        speedMBps: Double = 0.0,
        etaSeconds: Int = 0,
        percentage: Double = 0.0,
        logs: [String] = []
    ) {
        self.phase = phase
        self.statusMessage = statusMessage
        self.bytesWritten = bytesWritten
        self.totalBytes = totalBytes
        self.speedMBps = speedMBps
        self.etaSeconds = etaSeconds
        self.percentage = percentage
        self.logs = logs
    }
}
