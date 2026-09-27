import Foundation

public enum WorkerOperation: String, Sendable, Codable {
    case rawStream = "rawStream"
    case windowsPipeline = "windowsPipeline"
}

public struct WorkerJob: Sendable, Codable {
    public var operation: WorkerOperation
    public var sourcePath: String // Path to source file, FIFO, or mounted volume
    public var totalBytes: Int64
    public var destinationBSD: String
    public var options: MacbethOptions
    public var progressIPCPath: String
    
    public init(
        operation: WorkerOperation,
        sourcePath: String,
        totalBytes: Int64 = 0,
        destinationBSD: String,
        options: MacbethOptions,
        progressIPCPath: String
    ) {
        self.operation = operation
        self.sourcePath = sourcePath
        self.totalBytes = totalBytes
        self.destinationBSD = destinationBSD
        self.options = options
        self.progressIPCPath = progressIPCPath
    }
}

public struct WorkerProgress: Sendable, Codable {
    public var state: ProgressState
    public var isFinished: Bool
    public var errorMessage: String?
    
    public init(state: ProgressState, isFinished: Bool = false, errorMessage: String? = nil) {
        self.state = state
        self.isFinished = isFinished
        self.errorMessage = errorMessage
    }
}
