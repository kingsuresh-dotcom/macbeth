import Foundation

public struct DiskPartition: Sendable, Codable, Identifiable, Hashable {
    public var id: String { bsdName }
    public let bsdName: String
    public let name: String?
    public let filesystem: String?
    public let sizeBytes: Int64
    public let mountPoint: String?
    
    public init(bsdName: String, name: String?, filesystem: String?, sizeBytes: Int64, mountPoint: String?) {
        self.bsdName = bsdName
        self.name = name
        self.filesystem = filesystem
        self.sizeBytes = sizeBytes
        self.mountPoint = mountPoint
    }
}

public struct DiskDevice: Sendable, Codable, Identifiable, Hashable {
    public var id: String { bsdName }
    public let bsdName: String             // e.g. "/dev/disk4"
    public let rawDeviceNode: String       // e.g. "/dev/rdisk4"
    public let mediaName: String           // e.g. "SanDisk Ultra USB 3.0"
    public let totalSizeBytes: Int64
    public let blockSizeBytes: Int
    public let busProtocol: String         // e.g. "USB", "Thunderbolt", "Apple Fabric"
    public let isInternal: Bool
    public let isRemovable: Bool
    public let isEjectable: Bool
    public let partitionScheme: String?    // "GUID_partition_scheme", "FDisk_partition_scheme"
    public let partitions: [DiskPartition]
    public let isSafeTarget: Bool
    public let safetyRejectionReason: String?
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .decimal)
    }
    
    public var displayName: String {
        "\(mediaName) (\(formattedSize)) - \(bsdName)"
    }
    
    public init(
        bsdName: String,
        mediaName: String,
        totalSizeBytes: Int64,
        blockSizeBytes: Int = 512,
        busProtocol: String,
        isInternal: Bool,
        isRemovable: Bool,
        isEjectable: Bool,
        partitionScheme: String?,
        partitions: [DiskPartition] = [],
        isSafeTarget: Bool,
        safetyRejectionReason: String? = nil
    ) {
        self.bsdName = bsdName
        self.rawDeviceNode = bsdName.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
        self.mediaName = mediaName
        self.totalSizeBytes = totalSizeBytes
        self.blockSizeBytes = blockSizeBytes
        self.busProtocol = busProtocol
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.partitionScheme = partitionScheme
        self.partitions = partitions
        self.isSafeTarget = isSafeTarget
        self.safetyRejectionReason = safetyRejectionReason
    }
}
