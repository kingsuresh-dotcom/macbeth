import Foundation

public enum ImageType: String, Sendable, Codable {
    case windowsIso = "Windows Installation Media"
    case linuxHybridIso = "Linux Hybrid ISO (DD / ISO)"
    case macOsInstallerApp = "macOS Bootable Installer App"
    case rawImage = "Raw Disk Image (.img / .raw)"
    case freeDos = "FreeDOS Bootable Media"
    case unknown = "Unknown Image Format"
}

public struct ImageInfo: Sendable, Codable {
    public let imageURL: URL
    public let fileSizeBytes: Int64
    public let imageType: ImageType
    public let detectedOsName: String
    public let architecture: String             // "amd64", "arm64", "x86", "universal"
    public let windowsBuildNumber: Int?
    public let hasLargeWim: Bool
    public let wimSizeBytes: Int64?
    public let hasSbatRevocationRisk: Bool
    public let requiresPopcntAdvisory: Bool
    public var sha256: String?
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .decimal)
    }
    
    public init(
        imageURL: URL,
        fileSizeBytes: Int64,
        imageType: ImageType,
        detectedOsName: String,
        architecture: String = "amd64",
        windowsBuildNumber: Int? = nil,
        hasLargeWim: Bool = false,
        wimSizeBytes: Int64? = nil,
        hasSbatRevocationRisk: Bool = false,
        requiresPopcntAdvisory: Bool = false,
        sha256: String? = nil
    ) {
        self.imageURL = imageURL
        self.fileSizeBytes = fileSizeBytes
        self.imageType = imageType
        self.detectedOsName = detectedOsName
        self.architecture = architecture
        self.windowsBuildNumber = windowsBuildNumber
        self.hasLargeWim = hasLargeWim
        self.wimSizeBytes = wimSizeBytes
        self.hasSbatRevocationRisk = hasSbatRevocationRisk
        self.requiresPopcntAdvisory = requiresPopcntAdvisory
        self.sha256 = sha256
    }
}
