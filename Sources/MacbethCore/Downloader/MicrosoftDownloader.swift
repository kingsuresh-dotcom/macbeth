import Foundation

public struct WindowsDownloadInfo: Sendable {
    public let version: String
    public let architecture: String
    public let officialPortalURL: URL
    public let directApiDocumentation: String
}

public struct MicrosoftDownloader: Sendable {
    public static let availableReleases: [WindowsDownloadInfo] = [
        WindowsDownloadInfo(
            version: "Windows 11 (24H2 / 23H2 Multi-Edition)",
            architecture: "x64 (AMD64)",
            officialPortalURL: URL(string: "https://www.microsoft.com/en-us/software-download/windows11")!,
            directApiDocumentation: "Official Microsoft Retail ISO for 64-bit systems."
        ),
        WindowsDownloadInfo(
            version: "Windows 11 ARM64 (Snapdragon X / Apple Silicon VM)",
            architecture: "arm64",
            officialPortalURL: URL(string: "https://www.microsoft.com/en-us/software-download/windows11arm64")!,
            directApiDocumentation: "Official Microsoft ARM64 retail installation image."
        ),
        WindowsDownloadInfo(
            version: "Windows 10 (22H2 Multi-Edition)",
            architecture: "x64 (AMD64)",
            officialPortalURL: URL(string: "https://www.microsoft.com/en-us/software-download/windows10")!,
            directApiDocumentation: "Official Microsoft Windows 10 22H2 installation media."
        )
    ]
}
