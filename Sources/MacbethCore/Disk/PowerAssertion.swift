import Foundation
import IOKit.pwr_mgt

public final class PowerAssertion: @unchecked Sendable {
    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion: Bool = false
    
    public init() {}
    
    public func acquire(reason: String = "Macbeth is writing bootable media to USB") -> Bool {
        guard !hasAssertion else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            hasAssertion = true
            return true
        }
        return false
    }
    
    public func release() {
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
            assertionID = 0
        }
    }
    
    deinit {
        release()
    }
}
