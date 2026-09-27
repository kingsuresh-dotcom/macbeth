import Foundation

public struct LabelSanitizer: Sendable {
    /// Sanitizes volume labels according to the specific filesystem rules
    public static func sanitize(label: String, for fileSystem: TargetFileSystem) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "MACBETH_USB"
        }
        
        switch fileSystem {
        case .fat32:
            // FAT32: Max 11 ASCII characters, uppercase, alphanumeric and underscore only
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
            let upper = trimmed.uppercased()
            let filtered = upper.unicodeScalars.filter { allowed.contains($0) }
            let result = String(String.UnicodeScalarView(filtered))
            let maxLen = min(result.count, 11)
            let finalStr = String(result.prefix(maxLen))
            return finalStr.isEmpty ? "MACBETH_USB" : finalStr
            
        case .exfat:
            // ExFAT: Max 15 characters (per macOS newfs_exfat convention)
            let disallowed = CharacterSet(charactersIn: "\"*+,/:;<=>?[\\]|")
            let filtered = trimmed.unicodeScalars.filter { !disallowed.contains($0) }
            let result = String(String.UnicodeScalarView(filtered))
            let maxLen = min(result.count, 15)
            let finalStr = String(result.prefix(maxLen))
            return finalStr.isEmpty ? "MACBETH_EXFAT" : finalStr
            
        case .macOsExtended, .apfs, .ntfs:
            // macOS / NTFS: Max 32 characters
            let disallowed = CharacterSet(charactersIn: ":/")
            let filtered = trimmed.unicodeScalars.filter { !disallowed.contains($0) }
            let result = String(String.UnicodeScalarView(filtered))
            let maxLen = min(result.count, 32)
            let finalStr = String(result.prefix(maxLen))
            return finalStr.isEmpty ? "MACBETH_USB" : finalStr
        }
    }
}
