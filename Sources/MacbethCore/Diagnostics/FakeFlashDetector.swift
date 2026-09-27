import Foundation
import Darwin

public struct FakeFlashResult: Sendable {
    public let isGenuine: Bool
    public let testedBoundariesGB: [Int]
    public let failureBoundaryGB: Int?
    public let message: String
}

public final class FakeFlashDetector: @unchecked Sendable {
    private var isCancelled: Bool = false
    
    public init() {}
    
    /// Executes a 10-second sparse power-of-two boundary probe to detect fake capacity flash fraud
    public func testDrive(
        bsdName: String,
        totalSizeBytes: Int64,
        progress: @Sendable (Int, String) -> Void
    ) throws -> FakeFlashResult {
        isCancelled = false
        let rdiskPath = DeviceNodeSanitizer.toRawDeviceNode(bsdName)
        let fd = open(rdiskPath, O_RDWR | O_SYNC)
        guard fd >= 0 else {
            throw NSError(
                domain: "Macbeth.FakeFlash",
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "Failed to open \(rdiskPath) with write access (errno \(errno)). Ensure elevated privileges are granted."]
            )
        }
        defer { close(fd) }
        
        _ = fcntl(fd, F_NOCACHE, 1)
        
        // 4KB test block
        let blockSize = 4096
        var originalSector0 = Data(count: blockSize)
        _ = originalSector0.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, blockSize) }
        
        let testBoundariesGB = [4, 8, 16, 32, 64, 128, 256, 512, 1024]
        var passedBoundaries: [Int] = []
        
        for gb in testBoundariesGB {
            if isCancelled { break }
            let byteOffset = Int64(gb) * 1024 * 1024 * 1024
            if byteOffset >= totalSizeBytes { break }
            
            progress(gb, "Probing \(gb) GB boundary...")
            
            // Generate test signature for this boundary
            let sigString = "MACBETH_TEST_SIG_\(gb)_GB_\(UUID().uuidString)"
            var testBlock = sigString.data(using: .utf8)!
            testBlock.count = blockSize // pad to 4KB
            
            // Backup existing sector at offset
            lseek(fd, off_t(byteOffset), SEEK_SET)
            var backupBlock = Data(count: blockSize)
            _ = backupBlock.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, blockSize) }
            
            // Write test signature
            lseek(fd, off_t(byteOffset), SEEK_SET)
            let written = testBlock.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, blockSize) }
            if written != blockSize {
                return FakeFlashResult(
                    isGenuine: false,
                    testedBoundariesGB: passedBoundaries,
                    failureBoundaryGB: gb,
                    message: "Write failed at \(gb) GB boundary. Drive capacity is likely counterfeit."
                )
            }
            fsync(fd)
            
            // Read back signature
            lseek(fd, off_t(byteOffset), SEEK_SET)
            var readBack = Data(count: blockSize)
            _ = readBack.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, blockSize) }
            
            if readBack != testBlock {
                return FakeFlashResult(
                    isGenuine: false,
                    testedBoundariesGB: passedBoundaries,
                    failureBoundaryGB: gb,
                    message: "Data read back from \(gb) GB boundary did not match written pattern! Fake flash detected."
                )
            }
            
            // Verify Sector 0 was NOT overwritten (wrap-around detection)
            lseek(fd, 0, SEEK_SET)
            var currentSector0 = Data(count: blockSize)
            _ = currentSector0.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, blockSize) }
            if currentSector0 == testBlock {
                return FakeFlashResult(
                    isGenuine: false,
                    testedBoundariesGB: passedBoundaries,
                    failureBoundaryGB: gb,
                    message: "FATAL: Sector 0 was overwritten when writing to \(gb) GB! The controller is wrapping addresses. Drive is 100% counterfeit!"
                )
            }
            
            // Restore backup sector
            lseek(fd, off_t(byteOffset), SEEK_SET)
            _ = backupBlock.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, blockSize) }
            fsync(fd)
            
            passedBoundaries.append(gb)
        }
        
        // Restore sector 0
        lseek(fd, 0, SEEK_SET)
        _ = originalSector0.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, blockSize) }
        fsync(fd)
        
        return FakeFlashResult(
            isGenuine: true,
            testedBoundariesGB: passedBoundaries,
            failureBoundaryGB: nil,
            message: "Drive successfully verified genuine across all tested boundaries (\(passedBoundaries.map { "\($0)GB" }.joined(separator: ", ")))."
        )
    }
    
    public func cancel() {
        isCancelled = true
    }
}
