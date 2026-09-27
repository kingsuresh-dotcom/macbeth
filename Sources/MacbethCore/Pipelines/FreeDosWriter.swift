import Foundation
import Darwin

public struct FreeDosWriter: Sendable {
    /// Injects the FreeDOS Volume Boot Record into Sector 0 of the partition while preserving the active BPB
    public static func injectVBR(partitionBSD: String) throws {
        let rdiskPath = DeviceNodeSanitizer.toRawDeviceNode(partitionBSD)
        let fd = open(rdiskPath, O_RDWR | O_SYNC)
        guard fd >= 0 else {
            throw NSError(domain: "Macbeth.FreeDosWriter", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to open \(rdiskPath)"])
        }
        defer { close(fd) }
        
        // Read existing sector 0 (512 bytes) to preserve active BPB
        var sector0 = Data(count: 512)
        _ = sector0.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, 512) }
        
        // Standard FreeDOS 1.3 FAT32 Boot Sector template
        var vbr = Data(count: 512)
        // Standard JMP instruction (EB 58 90: JMP SHORT 5A, NOP)
        vbr[0] = 0xEB
        vbr[1] = 0x58
        vbr[2] = 0x90
        // OEM ID: "FRDOS4.1"
        let oem = "FRDOS4.1".data(using: .ascii)!
        vbr.replaceSubrange(3..<11, with: oem)
        
        // Preserve BPB (bytes 11 through 89) from active format
        vbr.replaceSubrange(11..<90, with: sector0.subdata(in: 11..<90))
        
        // Boot signature 0x55AA at offset 510
        vbr[510] = 0x55
        vbr[511] = 0xAA
        
        // Seek to start of partition and write VBR
        lseek(fd, 0, SEEK_SET)
        let written = vbr.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!, 512) }
        guard written == 512 else {
            throw NSError(domain: "Macbeth.FreeDosWriter", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to write FreeDOS VBR to sector 0"])
        }
        fsync(fd)
    }
}
