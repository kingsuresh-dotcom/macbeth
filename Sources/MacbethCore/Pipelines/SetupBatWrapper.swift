import Foundation

public struct SetupBatWrapper: Sendable {
    /// Generates setup.bat executing setup.exe /product server for Windows 11 in-place upgrades
    public static func generateSetupBat() -> String {
        return """
        @echo off
        cls
        echo ===================================================================
        echo  Starting Windows 11 Setup with Macbeth Hardware Bypasses
        echo ===================================================================
        echo.
        echo Launching Setup with /product server to bypass TPM, CPU and RAM checks...
        setup.exe /product server
        """
    }
    
    /// Generates autorun.inf to label the USB and provide a clean icon/action
    public static func generateAutorunInf(label: String) -> String {
        return """
        [AutoRun]
        open=setup.bat
        icon=setup.exe,0
        label=\(label)
        """
    }
}
