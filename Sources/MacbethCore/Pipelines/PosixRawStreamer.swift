import Foundation
import Darwin

public final class PosixRawStreamer: @unchecked Sendable {
    private var isCancelled: Bool = false
    
    public init() {}
    
    public func stream(
        sourceURL: URL,
        destinationBSD: String,
        progress: @Sendable (Int64, Int64, Double) -> Void
    ) throws {
        try stream(sourcePath: sourceURL.path, destinationBSD: destinationBSD, expectedTotalBytes: 0, progress: progress)
    }
    
    public func stream(
        sourcePath: String,
        destinationBSD: String,
        expectedTotalBytes: Int64 = 0,
        progress: @Sendable (Int64, Int64, Double) -> Void
    ) throws {
        isCancelled = false
        let cleanBSD = DeviceNodeSanitizer.clean(destinationBSD)
        let rdiskPath = DeviceNodeSanitizer.toRawDeviceNode(cleanBSD)
        
        // Step 1: Pre-unmount all partitions on destination disk to release OS volume locks
        let unmountProc = Process()
        unmountProc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        unmountProc.arguments = ["unmountDisk", "force", cleanBSD]
        try? unmountProc.run()
        unmountProc.waitUntilExit()
        
        let srcFd = open(sourcePath, O_RDONLY)
        guard srcFd >= 0 else {
            let err = errno
            throw NSError(
                domain: "Macbeth.RawStreamer",
                code: Int(err),
                userInfo: [NSLocalizedDescriptionKey: "Failed to open source: \(sourcePath) (errno \(err))"]
            )
        }
        defer { close(srcFd) }
        
        // Step 2: Open target raw character device for non-blocking direct streaming
        // NOTE: We deliberately omit O_SYNC to allow the USB host controller and flash drive firmware
        // to stream continuously into onboard high-speed SLC cache without thousands of bus flush stalls.
        let dstFd = open(rdiskPath, O_WRONLY)
        guard dstFd >= 0 else {
            let err = errno
            let msg: String
            if err == 13 {
                msg = "Failed to open destination raw device \(rdiskPath) (Permission denied, errno 13). Raw disk writing on macOS requires administrator privileges."
            } else if err == 1 {
                msg = "Failed to open destination raw device \(rdiskPath) (Operation not permitted, errno 1). macOS requires Full Disk Access in System Settings > Privacy & Security to write raw blocks to removable drives."
            } else {
                msg = "Failed to open destination raw device \(rdiskPath) (errno \(err))."
            }
            throw NSError(
                domain: "Macbeth.RawStreamer",
                code: Int(err),
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }
        defer { close(dstFd) }
        
        // Disable macOS page cache (F_NOCACHE) for maximum unbuffered DMA bus saturation
        _ = fcntl(dstFd, F_NOCACHE, 1)
        
        // 4MB buffer aligned to 4096-byte hardware page boundary (NAND flash superpage erase-block optimal)
        let chunkSize = 4 * 1024 * 1024
        var rawBuffer: UnsafeMutableRawPointer? = nil
        let alignErr = posix_memalign(&rawBuffer, 4096, chunkSize)
        guard alignErr == 0, let buffer = rawBuffer else {
            throw NSError(
                domain: "Macbeth.RawStreamer",
                code: Int(alignErr),
                userInfo: [NSLocalizedDescriptionKey: "posix_memalign failed to allocate 4MB aligned buffer."]
            )
        }
        defer { free(buffer) }
        
        let detectedSize = (try? FileManager.default.attributesOfItem(atPath: sourcePath)[.size] as? Int64) ?? 0
        let totalSize = expectedTotalBytes > 0 ? expectedTotalBytes : detectedSize
        var totalWritten: Int64 = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        var lastCallbackTime = startTime
        var smoothedSpeedMBps: Double = 0.0
        
        while !isCancelled {
            if totalSize > 0 && totalWritten >= totalSize { break }
            let bytesRead = Darwin.read(srcFd, buffer, chunkSize)
            if bytesRead <= 0 { break }
            
            var bytesWrittenThisBlock = 0
            while bytesWrittenThisBlock < bytesRead {
                let written = Darwin.write(dstFd, buffer.advanced(by: bytesWrittenThisBlock), bytesRead - bytesWrittenThisBlock)
                if written < 0 {
                    let err = errno
                    if err == ENXIO || err == EIO {
                        throw NSError(
                            domain: "Macbeth.RawStreamer",
                            code: Int(err),
                            userInfo: [NSLocalizedDescriptionKey: "Drive was disconnected during write (ENXIO/EIO). Operation aborted."]
                        )
                    }
                    throw NSError(
                        domain: "Macbeth.RawStreamer",
                        code: Int(err),
                        userInfo: [NSLocalizedDescriptionKey: "POSIX write failed on \(rdiskPath) with errno \(err)."]
                    )
                }
                bytesWrittenThisBlock += written
            }
            
            totalWritten += Int64(bytesRead)
            let now = CFAbsoluteTimeGetCurrent()
            
            // Calculate smoothed transfer speed (Exponential Moving Average)
            let totalElapsed = now - startTime
            let instantaneousSpeed = totalElapsed > 0 ? (Double(totalWritten) / (1024.0 * 1024.0)) / totalElapsed : 0.0
            if smoothedSpeedMBps == 0.0 {
                smoothedSpeedMBps = instantaneousSpeed
            } else {
                smoothedSpeedMBps = (0.8 * smoothedSpeedMBps) + (0.2 * instantaneousSpeed)
            }
            
            // Throttle progress callbacks to max 10 Hz to prevent UI thread flooding
            if now - lastCallbackTime >= 0.08 || totalWritten >= totalSize {
                progress(totalWritten, totalSize, smoothedSpeedMBps)
                lastCallbackTime = now
            }
        }
        
        // Single final hardware cache flush: commits all written data to non-volatile flash silicon
        fsync(dstFd)
        
        if isCancelled {
            throw NSError(
                domain: "Macbeth.RawStreamer",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "Operation cancelled by user."]
            )
        }
        
        // Final 100% progress report
        progress(totalWritten, totalSize, smoothedSpeedMBps)
        
        // Refresh and eject disk cleanly so macOS recognizes the newly created partition map
        let ejectProc = Process()
        ejectProc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        ejectProc.arguments = ["eject", cleanBSD]
        try? ejectProc.run()
        ejectProc.waitUntilExit()
    }
    
    public func cancel() {
        isCancelled = true
    }
}
