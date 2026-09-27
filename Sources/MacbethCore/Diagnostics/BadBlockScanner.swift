import Foundation
import Darwin

public final class BadBlockScanner: @unchecked Sendable {
    private var isCancelled: Bool = false
    
    public init() {}
    
    public func scan(
        bsdName: String,
        totalSizeBytes: Int64,
        passes: Int = 1,
        progress: @Sendable (Int, Int64, Int64, Double) -> Void
    ) throws -> Int {
        isCancelled = false
        let rdiskPath = DeviceNodeSanitizer.toRawDeviceNode(bsdName)
        let fd = open(rdiskPath, O_RDWR | O_SYNC)
        guard fd >= 0 else {
            throw NSError(domain: "Macbeth.BadBlockScanner", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to open \(rdiskPath) with write access."])
        }
        defer { close(fd) }
        
        _ = fcntl(fd, F_NOCACHE, 1)
        
        let chunkSize = 1024 * 1024 // 1MB buffer
        var rawBuf: UnsafeMutableRawPointer? = nil
        let alignErr = posix_memalign(&rawBuf, 4096, chunkSize)
        guard alignErr == 0, let buffer = rawBuf else {
            throw NSError(domain: "Macbeth", code: Int(alignErr), userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed."])
        }
        defer { free(buffer) }
        
        let patterns: [UInt8] = [0x55, 0xAA, 0x00, 0xFF]
        var badBlocksFound = 0
        let effectivePasses = min(max(1, passes), 4)
        
        for passIndex in 0..<effectivePasses {
            if isCancelled { break }
            let patternByte = patterns[passIndex]
            memset(buffer, Int32(patternByte), chunkSize)
            
            lseek(fd, 0, SEEK_SET)
            var offset: Int64 = 0
            let passStartTime = CFAbsoluteTimeGetCurrent()
            
            while offset < totalSizeBytes && !isCancelled {
                let toWrite = min(Int64(chunkSize), totalSizeBytes - offset)
                let written = Darwin.write(fd, buffer, Int(toWrite))
                if written != toWrite {
                    badBlocksFound += 1
                }
                offset += toWrite
                let elapsed = CFAbsoluteTimeGetCurrent() - passStartTime
                let speed = elapsed > 0 ? (Double(offset) / (1024.0 * 1024.0)) / elapsed : 0.0
                progress(passIndex + 1, offset, totalSizeBytes, speed)
            }
            fsync(fd)
        }
        
        return badBlocksFound
    }
    
    public func cancel() {
        isCancelled = true
    }
}
