import Foundation

public struct DiskSafety: Sendable {
    /// Comprehensive 5-layer safety check ensuring internal SSDs, APFS system containers, and Time Machine drives can never be erased.
    public static func evaluateSafety(info: [String: Any]) -> (isSafe: Bool, reason: String?) {
        // Layer 1: Protocol filter (Block Apple Fabric, PCI-Express internal system buses)
        if let bus = info["BusProtocol"] as? String {
            let blockedBuses = ["Apple Fabric", "PCI-Express", "NVMe", "Virtual Interface"]
            for blocked in blockedBuses {
                if bus.localizedCaseInsensitiveContains(blocked) {
                    return (false, "Device is connected via internal system bus (\(bus)).")
                }
            }
        }
        
        // Layer 2: Internal hardware flag
        if let isInternal = info["Internal"] as? Bool, isInternal {
            return (false, "Device is marked as an internal system disk.")
        }
        
        // Layer 3: System root or user volume protection
        let blockedMounts = ["/", "/System", "/System/Volumes/Data", "/System/Volumes/Preboot", "/System/Volumes/Update", "/Users"]
        if let mountPoint = info["MountPoint"] as? String {
            for blocked in blockedMounts {
                if mountPoint == blocked || mountPoint.hasPrefix(blocked + "/") {
                    return (false, "Device hosts critical system mount point: \(mountPoint).")
                }
            }
        }
        
        // Also check sub-partitions if present
        if let partitions = info["Partitions"] as? [[String: Any]] {
            for part in partitions {
                if let pMount = part["MountPoint"] as? String {
                    for blocked in blockedMounts {
                        if pMount == blocked || pMount.hasPrefix(blocked + "/") {
                            return (false, "Partition \(part["DeviceIdentifier"] ?? "") hosts critical system mount: \(pMount).")
                        }
                    }
                }
            }
        }
        
        // Layer 4: Time Machine backup volume check
        if let isTimeMachine = info["TimeMachine"] as? Bool, isTimeMachine {
            return (false, "Device is an active Time Machine backup volume.")
        }
        if let volumeName = info["VolumeName"] as? String, volumeName.localizedCaseInsensitiveContains("Time Machine") {
            return (false, "Volume name indicates a Time Machine backup.")
        }
        
        // Layer 5: disk0 hardlock
        if let devNode = info["DeviceNode"] as? String {
            let cleanNode = DeviceNodeSanitizer.clean(devNode)
            if cleanNode == "/dev/disk0" || cleanNode == "/dev/rdisk0" || cleanNode.contains("disk0s") {
                return (false, "disk0 is the primary macOS host disk and is permanently protected.")
            }
        }
        
        // Layer 6: Non-zero size requirement (filters out empty multi-card reader slots)
        if let size = info["TotalSize"] as? Int64, size <= 0 {
            return (false, "Device has no media inserted (size is 0 bytes).")
        }
        
        return (true, nil)
    }
}
