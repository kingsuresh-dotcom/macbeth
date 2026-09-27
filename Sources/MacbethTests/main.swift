import Foundation
import MacbethCore

@main
@MainActor
struct MacbethTestRunner {
    static var testsPassed = 0
    static var testsFailed = 0
    
    static func main() async throws {
        print("======================================================================")
        print(" Running Macbeth Automated Test Suite (Swift 6.4 Strict Concurrency)")
        print("======================================================================")
        
        runTest(name: "DeviceNodeSanitizer.clean with trailing whitespace and tabs") {
            let dirty = "/dev/disk4          \t                               \t\n"
            let clean = DeviceNodeSanitizer.clean(dirty)
            assert(clean == "/dev/disk4", "Expected /dev/disk4, got \(clean)")
        }
        
        runTest(name: "DeviceNodeSanitizer.toRawDeviceNode conversions") {
            assert(DeviceNodeSanitizer.toRawDeviceNode("/dev/disk4") == "/dev/rdisk4")
            assert(DeviceNodeSanitizer.toRawDeviceNode("disk5") == "/dev/rdisk5")
            assert(DeviceNodeSanitizer.toRawDeviceNode("/dev/rdisk4") == "/dev/rdisk4")
        }
        
        runTest(name: "DiskSafety: Reject internal Apple Fabric bus") {
            let mockInfo: [String: Any] = [
                "DeviceNode": "/dev/disk0",
                "BusProtocol": "Apple Fabric",
                "Internal": true,
                "TotalSize": Int64(500_000_000_000)
            ]
            let result = DiskSafety.evaluateSafety(info: mockInfo)
            assert(!result.isSafe, "Internal Apple Fabric disk must be rejected")
            assert(result.reason != nil, "Rejection reason must be provided")
        }
        
        runTest(name: "DiskSafety: Reject system mount point /System/Volumes/Data") {
            let mockInfo: [String: Any] = [
                "DeviceNode": "/dev/disk3s1",
                "BusProtocol": "USB",
                "Internal": false,
                "MountPoint": "/System/Volumes/Data",
                "TotalSize": Int64(500_000_000_000)
            ]
            let result = DiskSafety.evaluateSafety(info: mockInfo)
            assert(!result.isSafe, "System mount point must be rejected")
        }
        
        runTest(name: "DiskSafety: Reject Time Machine backup volume") {
            let mockInfo: [String: Any] = [
                "DeviceNode": "/dev/disk5",
                "BusProtocol": "USB",
                "Internal": false,
                "TimeMachine": true,
                "TotalSize": Int64(1_000_000_000_000)
            ]
            let result = DiskSafety.evaluateSafety(info: mockInfo)
            assert(!result.isSafe, "Time Machine volume must be rejected")
        }
        
        runTest(name: "DiskSafety: Reject empty card reader (0 bytes)") {
            let mockInfo: [String: Any] = [
                "DeviceNode": "/dev/disk6",
                "BusProtocol": "USB",
                "Internal": false,
                "TotalSize": Int64(0)
            ]
            let result = DiskSafety.evaluateSafety(info: mockInfo)
            assert(!result.isSafe, "Empty card reader slot must be rejected")
        }
        
        runTest(name: "DiskSafety: Accept safe external USB flash drive") {
            let mockInfo: [String: Any] = [
                "DeviceNode": "/dev/disk4",
                "BusProtocol": "USB",
                "Internal": false,
                "RemovableMedia": true,
                "TotalSize": Int64(32_000_000_000),
                "MountPoint": "/Volumes/Untitled"
            ]
            let result = DiskSafety.evaluateSafety(info: mockInfo)
            assert(result.isSafe, "External removable USB flash drive must be accepted")
        }
        
        runTest(name: "LabelSanitizer: FAT32 11-char uppercase truncation") {
            let sanitized = LabelSanitizer.sanitize(label: "Windows 11 Pro 24H2", for: .fat32)
            assert(sanitized == "WINDOWS11PR", "Expected WINDOWS11PR, got \(sanitized)")
            assert(sanitized.count <= 11)
        }
        
        runTest(name: "LabelSanitizer: ExFAT 15-char truncation") {
            let sanitized = LabelSanitizer.sanitize(label: "My Very Long USB Installer Name", for: .exfat)
            assert(sanitized == "My Very Long US", "Expected 'My Very Long US', got '\(sanitized)'")
            assert(sanitized.count <= 15)
        }
        
        runTest(name: "UnattendGenerator: 2026 Windows 11 hardening schema") {
            var exp = WindowsExperience()
            exp.bypassTPMAndSecureBoot = true
            exp.bypassRAMCheck = true
            exp.bypassCPUAndStorageCheck = true
            exp.bypassOnlineAccount = true
            exp.localUsername = "TestAdmin"
            exp.syncRtcToUtc = true
            exp.disableBitLocker = true
            
            let xml = UnattendGenerator.generate(arch: "amd64", options: exp)
            assert(xml.contains("<PasswordExpires>false</PasswordExpires>"), "Must contain PasswordExpires=false")
            assert(xml.contains("RealTimeIsUniversal"), "Must contain RealTimeIsUniversal for UTC RTC sync")
            assert(xml.contains("BypassTPMCheck"), "Must contain BypassTPMCheck")
            assert(xml.contains("BypassSecureBootCheck"), "Must contain BypassSecureBootCheck")
            assert(xml.contains("BypassRAMCheck"), "Must contain BypassRAMCheck")
            assert(xml.contains("BypassCPUCheck"), "Must contain BypassCPUCheck")
            assert(xml.contains("BypassStorageCheck"), "Must contain BypassStorageCheck")
            assert(xml.contains("PreventDeviceEncryption"), "Must contain PreventDeviceEncryption")
            assert(xml.contains("<Name>TestAdmin</Name>"), "Must contain designated local username")
            assert(xml.contains("processorArchitecture=\"amd64\""), "Must contain correct architecture")
        }
        
        runTest(name: "UnattendGenerator: ARM64 architecture support") {
            let exp = WindowsExperience()
            let xml = UnattendGenerator.generate(arch: "arm64", options: exp)
            assert(xml.contains("processorArchitecture=\"arm64\""), "Must contain arm64")
            assert(!xml.contains("processorArchitecture=\"amd64\""), "Must not contain amd64")
        }
        
        runTest(name: "SetupBatWrapper: setup.exe /product server in-place wrapper") {
            let bat = SetupBatWrapper.generateSetupBat()
            assert(bat.contains("setup.exe /product server"), "Must contain /product server switch")
            let autorun = SetupBatWrapper.generateAutorunInf(label: "TEST_USB")
            assert(autorun.contains("label=TEST_USB"), "Must contain label")
            assert(autorun.contains("open=setup.bat"), "Must open setup.bat")
        }
        
        runTest(name: "ChecksumEngine: SHA-256 and MD5 streaming calculation") {
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("macbeth_test_\(UUID().uuidString).bin")
            let testData = "Hello Macbeth 2026 Test Suite".data(using: .utf8)!
            try testData.write(to: testFile)
            defer { try? FileManager.default.removeItem(at: testFile) }
            
            let (sha256, md5) = try ChecksumEngine.computeHashes(fileURL: testFile)
            assert(sha256.count == 64, "SHA-256 must be 64 hex characters")
            assert(md5.count == 32, "MD5 must be 32 hex characters")
        }
        
        runTest(name: "LinuxCatalog: Modern distributions catalog integrity") {
            let distros = LinuxCatalog.standardDistros
            assert(!distros.isEmpty, "Catalog must not be empty")
            
            let debian = distros.first { $0.name == "Debian Live Standard" }
            assert(debian != nil, "Debian must be present in catalog")
            assert(debian!.version.contains("Trixie"), "Debian version must be Trixie (Debian 13), got: \(debian!.version)")
            assert(debian!.downloadURL.absoluteString.contains("debian-live-13."), "Download URL must target Debian 13")
            assert(debian!.expectedSha256?.count == 64, "Expected SHA256 checksum must be 64 hex characters")
            
            for distro in distros {
                assert(distro.downloadURL.scheme == "https", "\(distro.name) URL must be HTTPS")
                assert(distro.releaseNotesURL.scheme == "https", "\(distro.name) release notes must be HTTPS")
            }
        }
        
        await runAsyncTest(name: "LinuxCatalog: Dynamic upstream resolution of latest distros") {
            let latest = await LinuxCatalog.fetchLatestDistros(timeout: 8.0)
            assert(!latest.isEmpty, "Dynamic catalog should not be empty")
            
            // Debian dynamic validation
            if let debian = latest.first(where: { $0.name == "Debian Live Standard" }) {
                assert(debian.downloadURL.absoluteString.contains("debian-live-"), "Debian ISO link must follow naming convention")
                assert(debian.expectedSha256?.count == 64, "Dynamic Debian must include verified SHA256 checksum")
                assert(debian.isDynamicallyResolved, "Debian should be dynamically resolved from upstream SHA256SUMS")
            } else {
                assertionFailure("Debian must be present in dynamic catalog")
            }
            
            // Fedora dynamic validation
            if let fedora = latest.first(where: { $0.name == "Fedora Workstation" }) {
                assert(fedora.downloadURL.absoluteString.hasSuffix(".iso"), "Fedora link must target ISO")
                assert(fedora.isDynamicallyResolved, "Fedora should be dynamically resolved from releases.json")
            } else {
                assertionFailure("Fedora must be present in dynamic catalog")
            }
            
            // Ubuntu dynamic validation
            if let ubuntu = latest.first(where: { $0.name == "Ubuntu Desktop" }) {
                assert(ubuntu.downloadURL.absoluteString.contains("ubuntu-"), "Ubuntu link must target Ubuntu ISO")
                assert(ubuntu.isDynamicallyResolved, "Ubuntu should be dynamically resolved from meta-release")
            } else {
                assertionFailure("Ubuntu must be present in dynamic catalog")
            }
        }
        
        runTest(name: "PosixRawStreamer: 16MB unbuffered DMA stream integrity") {
            let tempDir = FileManager.default.temporaryDirectory
            let srcFile = tempDir.appendingPathComponent("macbeth_stream_src_\(UUID().uuidString).bin")
            let dstFile = tempDir.appendingPathComponent("macbeth_stream_dst_\(UUID().uuidString).bin")
            
            let testSize = 16 * 1024 * 1024
            var sampleData = Data(count: testSize)
            for i in 0..<testSize {
                sampleData[i] = UInt8(i & 0xFF)
            }
            try sampleData.write(to: srcFile)
            FileManager.default.createFile(atPath: dstFile.path, contents: nil)
            
            defer {
                try? FileManager.default.removeItem(at: srcFile)
                try? FileManager.default.removeItem(at: dstFile)
            }
            
            final class SafeCounter: @unchecked Sendable {
                private var val = 0
                private let lock = NSLock()
                func inc() { lock.lock(); val += 1; lock.unlock() }
                func count() -> Int { lock.lock(); defer { lock.unlock() }; return val }
            }
            let counter = SafeCounter()
            
            let streamer = PosixRawStreamer()
            try streamer.stream(sourcePath: srcFile.path, destinationBSD: dstFile.path, expectedTotalBytes: Int64(testSize)) { written, total, speed in
                counter.inc()
                assert(written <= total, "Written bytes cannot exceed total bytes")
            }
            
            let (srcHash, _) = try ChecksumEngine.computeHashes(fileURL: srcFile)
            let (dstHash, _) = try ChecksumEngine.computeHashes(fileURL: dstFile)
            
            assert(srcHash == dstHash, "Streamed data hash must be byte-for-byte identical to source")
            assert(counter.count() > 0, "Progress reporter must have been invoked during streaming")
        }
        
        print("======================================================================")
        print(" TEST SUITE SUMMARY: \(testsPassed) PASSED, \(testsFailed) FAILED")
        print("======================================================================")
        
        if testsFailed > 0 {
            exit(1)
        }
    }
    
    static func runTest(name: String, block: () throws -> Void) {
        do {
            try block()
            print("  [PASS] \(name)")
            testsPassed += 1
        } catch {
            print("  [FAIL] \(name): \(error)")
            testsFailed += 1
        }
    }

    static func runAsyncTest(name: String, block: () async throws -> Void) async {
        do {
            try await block()
            print("  [PASS] \(name)")
            testsPassed += 1
        } catch {
            print("  [FAIL] \(name): \(error)")
            testsFailed += 1
        }
    }
}
