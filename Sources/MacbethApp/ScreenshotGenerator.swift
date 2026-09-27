import SwiftUI
import AppKit
import MacbethCore

@MainActor
public struct ScreenshotGenerator {
    public static func generateScreenshots(outDir: String) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        
        let vm = MacbethViewModel()
        
        let sampleDevice = DiskDevice(
            bsdName: "/dev/disk4",
            mediaName: "SanDisk Ultra Luxe USB 3.2",
            totalSizeBytes: 64_000_000_000,
            blockSizeBytes: 512,
            busProtocol: "USB",
            isInternal: false,
            isRemovable: true,
            isEjectable: true,
            partitionScheme: "GUID_partition_scheme",
            partitions: [],
            isSafeTarget: true
        )
        vm.availableDevices = [sampleDevice]
        vm.selectedDevice = sampleDevice
        vm.volumeLabel = "WIN11_24H2"
        vm.fileSystem = .exfat
        vm.partitionScheme = .gpt
        vm.targetSystem = .uefiNonCsm
        vm.statusText = "READY (Press START to burn)"
        vm.progressPercentage = 0.0
        vm.selectedImageURL = URL(fileURLWithPath: "/Users/suresh/Downloads/Win11_24H2_English_x64.iso")
        vm.imageInfo = ImageInfo(
            imageURL: URL(fileURLWithPath: "/Users/suresh/Downloads/Win11_24H2_English_x64.iso"),
            fileSizeBytes: 5_824_100_352,
            imageType: .windowsIso,
            detectedOsName: "Windows 11 24H2 (Build 26100 Multi-Edition)",
            architecture: "amd64",
            windowsBuildNumber: 26100,
            hasLargeWim: true,
            wimSizeBytes: 4_720_000_000
        )
        vm.logs = [
            "[Macbeth 2026] System initialized. Swift 6.4 Concurrency active.",
            "[DiskManager] Probing hardware storage buses...",
            "[DiskManager] Identified safe removable USB target: /dev/disk4 (SanDisk Ultra Luxe - 64.0 GB)",
            "[ImageInspector] Inspecting /Users/suresh/Downloads/Win11_24H2_English_x64.iso",
            "[ImageInspector] Detected Microsoft Windows 11 installation media (install.wim: 4.72 GB)",
            "[ImageInspector] UEFI non-CSM GPT bootloader validated.",
            "[WindowsExperience] Automated unattend bypasses configured (TPM 2.0, SecureBoot, RAM, MSA).",
            "[Status] Ready."
        ]
        
        // 1. Main Window
        let mainView = MainWindowView(vm: vm)
            .frame(width: 520, height: 560)
            .background(Color(NSColor.windowBackgroundColor))
        render(view: mainView, size: CGSize(width: 520, height: 560), to: "\(outDir)/macbeth_main.png")
        
        // 2. Windows Experience Sheet
        let winExpView = WindowsExperienceSheet(vm: vm)
            .frame(width: 520)
            .background(Color(NSColor.windowBackgroundColor))
        render(view: winExpView, size: CGSize(width: 520, height: 480), to: "\(outDir)/macbeth_windows_experience.png")
        
        // 3. Download Center Sheet
        let downloadView = DownloadCenterSheet(vm: vm)
            .frame(width: 560, height: 480)
            .background(Color(NSColor.windowBackgroundColor))
        render(view: downloadView, size: CGSize(width: 560, height: 480), to: "\(outDir)/macbeth_download_center.png")
        
        // 4. Log Console Sheet
        let logView = LogConsoleSheet(vm: vm)
            .frame(width: 560, height: 400)
            .background(Color(NSColor.windowBackgroundColor))
        render(view: logView, size: CGSize(width: 560, height: 400), to: "\(outDir)/macbeth_event_log.png")
        
        print("[ScreenshotGenerator] Rendered pixel-perfect screenshots to \(outDir)")
    }
    
    private static func render<V: View>(view: V, size: CGSize, to path: String) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: URL(fileURLWithPath: path))
    }
}
