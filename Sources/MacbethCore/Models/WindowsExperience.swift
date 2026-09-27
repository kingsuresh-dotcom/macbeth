import Foundation

public struct WindowsExperience: Sendable, Codable {
    public var bypassTPMAndSecureBoot: Bool
    public var bypassRAMCheck: Bool
    public var bypassCPUAndStorageCheck: Bool
    public var bypassOnlineAccount: Bool
    public var localUsername: String
    public var disableBitLocker: Bool
    public var disableTelemetry: Bool
    public var syncRtcToUtc: Bool
    public var addInPlaceUpgradeWrapper: Bool
    
    public init(
        bypassTPMAndSecureBoot: Bool = true,
        bypassRAMCheck: Bool = true,
        bypassCPUAndStorageCheck: Bool = true,
        bypassOnlineAccount: Bool = true,
        localUsername: String = NSUserName(),
        disableBitLocker: Bool = true,
        disableTelemetry: Bool = true,
        syncRtcToUtc: Bool = true,
        addInPlaceUpgradeWrapper: Bool = true
    ) {
        self.bypassTPMAndSecureBoot = bypassTPMAndSecureBoot
        self.bypassRAMCheck = bypassRAMCheck
        self.bypassCPUAndStorageCheck = bypassCPUAndStorageCheck
        self.bypassOnlineAccount = bypassOnlineAccount
        self.localUsername = localUsername.isEmpty ? "User" : localUsername
        self.disableBitLocker = disableBitLocker
        self.disableTelemetry = disableTelemetry
        self.syncRtcToUtc = syncRtcToUtc
        self.addInPlaceUpgradeWrapper = addInPlaceUpgradeWrapper
    }
}
