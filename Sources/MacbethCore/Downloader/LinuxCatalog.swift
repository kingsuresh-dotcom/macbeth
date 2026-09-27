import Foundation

public struct DistroRelease: Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let downloadURL: URL
    public let releaseNotesURL: URL
    public let expectedSha256: String?
    public let isDynamicallyResolved: Bool

    public init(
        name: String,
        version: String,
        downloadURL: URL,
        releaseNotesURL: URL,
        expectedSha256: String? = nil,
        isDynamicallyResolved: Bool = false
    ) {
        self.name = name
        self.version = version
        self.downloadURL = downloadURL
        self.releaseNotesURL = releaseNotesURL
        self.expectedSha256 = expectedSha256
        self.isDynamicallyResolved = isDynamicallyResolved
    }
}

public struct LinuxCatalog: Sendable {
    public static let standardDistros: [DistroRelease] = [
        DistroRelease(
            name: "Ubuntu Desktop",
            version: "26.04.1 LTS (Resolute Raccoon)",
            downloadURL: URL(string: "https://releases.ubuntu.com/26.04.1/ubuntu-26.04.1-desktop-amd64.iso")!,
            releaseNotesURL: URL(string: "https://discourse.ubuntu.com/t/resolute-raccoon-release-notes/59221")!,
            expectedSha256: "601e30fbf5d97759367c632e2c33630665039b7e2158fd068403da3ccf1bda1f",
            isDynamicallyResolved: false
        ),
        DistroRelease(
            name: "Fedora Workstation",
            version: "44 (x86_64)",
            downloadURL: URL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Workstation/x86_64/iso/Fedora-Workstation-Live-44-1.7.x86_64.iso")!,
            releaseNotesURL: URL(string: "https://docs.fedoraproject.org/en-US/fedora/latest/release-notes/")!,
            expectedSha256: "1620295f6a00c27c3208f0c00b8ece4eab1ec69b9002152d97488bf26a426ddf",
            isDynamicallyResolved: false
        ),
        DistroRelease(
            name: "Debian Live Standard",
            version: "13.7.0 Trixie",
            downloadURL: URL(string: "https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-13.7.0-amd64-standard.iso")!,
            releaseNotesURL: URL(string: "https://www.debian.org/News/2026/20260912")!,
            expectedSha256: "040a44f35186321eb6cdaab52a8a2d06224fe6b77f6fbb9f1861ad89c14e17ec",
            isDynamicallyResolved: false
        ),
        DistroRelease(
            name: "Arch Linux",
            version: "Rolling Release",
            downloadURL: URL(string: "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso")!,
            releaseNotesURL: URL(string: "https://archlinux.org/releng/releases/")!,
            expectedSha256: nil,
            isDynamicallyResolved: false
        )
    ]

    /// Fetches the latest distribution versions dynamically from official upstream sources.
    /// Falls back to verified standard baseline releases if network queries fail or time out.
    public static func fetchLatestDistros(timeout: TimeInterval = 6.0) async -> [DistroRelease] {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        async let debian = resolveDebian(session: session)
        async let ubuntu = resolveUbuntu(session: session)
        async let fedora = resolveFedora(session: session)
        async let arch = resolveArch(session: session)

        let resolvedDebian = await debian
        let resolvedUbuntu = await ubuntu
        let resolvedFedora = await fedora
        let resolvedArch = await arch

        var results: [DistroRelease] = []

        if let ubuntu = resolvedUbuntu {
            results.append(ubuntu)
        } else if let fallback = standardDistros.first(where: { $0.name == "Ubuntu Desktop" }) {
            results.append(fallback)
        }

        if let fedora = resolvedFedora {
            results.append(fedora)
        } else if let fallback = standardDistros.first(where: { $0.name == "Fedora Workstation" }) {
            results.append(fallback)
        }

        if let debian = resolvedDebian {
            results.append(debian)
        } else if let fallback = standardDistros.first(where: { $0.name == "Debian Live Standard" }) {
            results.append(fallback)
        }

        if let arch = resolvedArch {
            results.append(arch)
        } else if let fallback = standardDistros.first(where: { $0.name == "Arch Linux" }) {
            results.append(fallback)
        }

        return results
    }

    /// Dynamically resolves latest Debian Live Standard by parsing the upstream SHA256SUMS file
    public static func resolveDebian(session: URLSession) async -> DistroRelease? {
        guard let manifestURL = URL(string: "https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/SHA256SUMS") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: manifestURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            for line in text.components(separatedBy: .newlines) {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 2 else { continue }
                let hash = String(parts[0])
                let filename = String(parts[1])
                if filename.hasPrefix("debian-live-") && filename.hasSuffix("-amd64-standard.iso") {
                    let versionNum = filename
                        .replacingOccurrences(of: "debian-live-", with: "")
                        .replacingOccurrences(of: "-amd64-standard.iso", with: "")
                    guard let downloadURL = URL(string: "https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/\(filename)") else {
                        continue
                    }
                    let majorVersion = versionNum.split(separator: ".").first ?? "13"
                    let codename = (majorVersion == "13") ? "Trixie" : (majorVersion == "12" ? "Bookworm" : "Stable")
                    let releaseNotes = URL(string: "https://www.debian.org/releases/stable/")!
                    return DistroRelease(
                        name: "Debian Live Standard",
                        version: "\(versionNum) \(codename) (Latest)",
                        downloadURL: downloadURL,
                        releaseNotesURL: releaseNotes,
                        expectedSha256: hash,
                        isDynamicallyResolved: true
                    )
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Dynamically resolves latest Ubuntu LTS by parsing official Canonical meta-release manifest
    public static func resolveUbuntu(session: URLSession) async -> DistroRelease? {
        guard let metaURL = URL(string: "https://changelogs.ubuntu.com/meta-release-lts") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: metaURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            var name = ""
            var version = ""
            for line in text.components(separatedBy: .newlines) {
                if line.hasPrefix("Name: ") {
                    name = line.replacingOccurrences(of: "Name: ", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Version: ") {
                    version = line.replacingOccurrences(of: "Version: ", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
            if !version.isEmpty {
                let verNum = version.components(separatedBy: " ").first ?? version
                let majorMinor = verNum.split(separator: ".").prefix(2).joined(separator: ".")
                if let isoURL = URL(string: "https://releases.ubuntu.com/\(majorMinor)/ubuntu-\(verNum)-desktop-amd64.iso") {
                    let notes = URL(string: "https://discourse.ubuntu.com/c/release/")!
                    return DistroRelease(
                        name: "Ubuntu Desktop",
                        version: "\(version) (\(name)) (Latest)",
                        downloadURL: isoURL,
                        releaseNotesURL: notes,
                        expectedSha256: nil,
                        isDynamicallyResolved: true
                    )
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Dynamically resolves latest Fedora Workstation by querying fedoraproject releases.json
    public static func resolveFedora(session: URLSession) async -> DistroRelease? {
        guard let releasesURL = URL(string: "https://fedoraproject.org/releases.json") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: releasesURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }
            for item in json {
                guard let variant = item["variant"] as? String, variant == "Workstation",
                      let arch = item["arch"] as? String, arch == "x86_64",
                      let linkStr = item["link"] as? String, linkStr.hasSuffix(".iso"),
                      let version = item["version"] as? String, !version.lowercased().contains("beta"),
                      let linkURL = URL(string: linkStr) else {
                    continue
                }
                let sha256 = item["sha256"] as? String
                let notes = URL(string: "https://docs.fedoraproject.org/en-US/fedora/latest/release-notes/")!
                return DistroRelease(
                    name: "Fedora Workstation",
                    version: "\(version) (x86_64) (Latest)",
                    downloadURL: linkURL,
                    releaseNotesURL: notes,
                    expectedSha256: sha256,
                    isDynamicallyResolved: true
                )
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Dynamically resolves latest Arch Linux snapshot version
    public static func resolveArch(session: URLSession) async -> DistroRelease? {
        guard let archURL = URL(string: "https://archlinux.org/releng/releases/json/") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: archURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let latestVersion = json["latest_version"] as? String,
                  let downloadURL = URL(string: "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso") else {
                return nil
            }
            var sha256: String? = nil
            if let releases = json["releases"] as? [[String: Any]],
               let latest = releases.first(where: { ($0["version"] as? String) == latestVersion }) {
                sha256 = latest["sha256_sum"] as? String
            }
            let notes = URL(string: "https://archlinux.org/releng/releases/")!
            return DistroRelease(
                name: "Arch Linux",
                version: "Rolling Release (\(latestVersion)) (Latest)",
                downloadURL: downloadURL,
                releaseNotesURL: notes,
                expectedSha256: sha256,
                isDynamicallyResolved: true
            )
        } catch {
            return nil
        }
    }
}
