import Foundation

public enum PartitionScheme: String, Sendable, Codable, CaseIterable {
    case gpt = "GPT (UEFI non-CSM)"
    case mbr = "MBR (BIOS or UEFI-CSM)"
}

public enum TargetSystem: String, Sendable, Codable, CaseIterable {
    case uefiNonCsm = "UEFI (non CSM)"
    case biosOrCsm = "BIOS (or UEFI-CSM)"
}

public enum TargetFileSystem: String, Sendable, Codable, CaseIterable {
    case exfat = "ExFAT (Default)"
    case fat32 = "FAT32"
    case ntfs = "NTFS (UEFI:NTFS)"
    case macOsExtended = "Mac OS Extended (Journaled)"
    case apfs = "APFS"
}

public struct MacbethOptions: Sendable, Codable {
    public var partitionScheme: PartitionScheme
    public var targetSystem: TargetSystem
    public var fileSystem: TargetFileSystem
    public var volumeLabel: String
    public var quickFormat: Bool
    public var checkBadBlocks: Bool
    public var badBlockPasses: Int
    public var testFakeFlash: Bool
    public var persistenceSizeMB: Int
    public var windowsExperience: WindowsExperience
    
    public init(
        partitionScheme: PartitionScheme = .gpt,
        targetSystem: TargetSystem = .uefiNonCsm,
        fileSystem: TargetFileSystem = .exfat,
        volumeLabel: String = "MACBETH_USB",
        quickFormat: Bool = true,
        checkBadBlocks: Bool = false,
        badBlockPasses: Int = 1,
        testFakeFlash: Bool = false,
        persistenceSizeMB: Int = 0,
        windowsExperience: WindowsExperience = WindowsExperience()
    ) {
        self.partitionScheme = partitionScheme
        self.targetSystem = targetSystem
        self.fileSystem = fileSystem
        self.volumeLabel = volumeLabel
        self.quickFormat = quickFormat
        self.checkBadBlocks = checkBadBlocks
        self.badBlockPasses = badBlockPasses
        self.testFakeFlash = testFakeFlash
        self.persistenceSizeMB = persistenceSizeMB
        self.windowsExperience = windowsExperience
    }
}
