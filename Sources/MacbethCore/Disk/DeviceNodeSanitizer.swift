import Foundation

public struct DeviceNodeSanitizer: Sendable {
    /// Strips trailing whitespace, carriage returns, tabs, and any trailing whitespace returned by macOS CLI tools
    public static func clean(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.components(separatedBy: .whitespaces).first ?? ""
    }
    
    /// Returns the raw character device node path corresponding to a block device node path
    /// e.g. "/dev/disk4" -> "/dev/rdisk4"
    public static func toRawDeviceNode(_ bsdPath: String) -> String {
        let cleanPath = clean(bsdPath)
        if cleanPath.contains("/dev/disk") {
            return cleanPath.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
        } else if cleanPath.hasPrefix("disk") {
            return "/dev/r" + cleanPath
        }
        return cleanPath
    }
    
    /// Returns the standard block device node path corresponding to a raw character device
    /// e.g. "/dev/rdisk4" -> "/dev/disk4"
    public static func toBlockDeviceNode(_ rawPath: String) -> String {
        let cleanPath = clean(rawPath)
        if cleanPath.contains("/dev/rdisk") {
            return cleanPath.replacingOccurrences(of: "/dev/rdisk", with: "/dev/disk")
        } else if cleanPath.hasPrefix("rdisk") {
            return "/dev/" + cleanPath.dropFirst()
        }
        return cleanPath
    }
}
