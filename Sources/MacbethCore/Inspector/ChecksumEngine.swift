import Foundation
import CryptoKit

public struct ChecksumEngine: Sendable {
    /// Computes SHA-256 and MD5 hashes of a file in streaming chunks (memory efficient for 10GB+ ISOs)
    public static func computeHashes(
        fileURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws -> (sha256: String, md5: String) {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }
        
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalBytes = fileAttributes[.size] as? Int64 ?? 1
        var bytesProcessed: Int64 = 0
        
        var sha256 = SHA256()
        var md5 = Insecure.MD5()
        
        let bufferSize = 4 * 1024 * 1024 // 4MB buffer
        while true {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            
            sha256.update(data: data)
            md5.update(data: data)
            
            bytesProcessed += Int64(data.count)
            let fraction = Double(bytesProcessed) / Double(totalBytes)
            progress?(fraction)
        }
        
        let sha256Digest = sha256.finalize()
        let md5Digest = md5.finalize()
        
        let sha256String = sha256Digest.map { String(format: "%02x", $0) }.joined()
        let md5String = md5Digest.map { String(format: "%02x", $0) }.joined()
        
        return (sha256String, md5String)
    }
}
