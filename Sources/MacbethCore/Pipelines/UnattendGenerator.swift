import Foundation

public struct UnattendGenerator: Sendable {
    /// Generates schema-compliant autounattend.xml for Windows 10/11 with 2026 hardening
    public static func generate(
        arch: String = "amd64",
        options: WindowsExperience
    ) -> String {
        var runCommands = ""
        var cmdOrder = 1
        
        if options.bypassTPMAndSecureBoot {
            runCommands += """
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder)</Order>
                            <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder + 1)</Order>
                            <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
            """
            cmdOrder += 2
        }
        
        if options.bypassRAMCheck {
            runCommands += """
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder)</Order>
                            <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
            """
            cmdOrder += 1
        }
        
        if options.bypassCPUAndStorageCheck {
            runCommands += """
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder)</Order>
                            <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder + 1)</Order>
                            <Path>reg add HKLM\\SYSTEM\\Setup\\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
            """
            cmdOrder += 2
        }
        
        if options.syncRtcToUtc {
            runCommands += """
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder)</Order>
                            <Path>reg add HKLM\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
            """
            cmdOrder += 1
        }
        
        if options.disableBitLocker {
            runCommands += """
                        <RunSynchronousCommand wcm:action="add">
                            <Order>\(cmdOrder)</Order>
                            <Path>reg add HKLM\\SYSTEM\\CurrentControlSet\\Control\\BitLocker /v PreventDeviceEncryption /t REG_DWORD /d 1 /f</Path>
                        </RunSynchronousCommand>
            """
            cmdOrder += 1
        }
        
        let localUserBlock = options.bypassOnlineAccount ? """
                    <UserAccounts>
                        <LocalAccounts>
                            <LocalAccount wcm:action="add">
                                <Name>\(options.localUsername)</Name>
                                <DisplayName>\(options.localUsername)</DisplayName>
                                <Group>Administrators</Group>
                                <Password>
                                    <Value></Value>
                                    <PlainText>true</PlainText>
                                </Password>
                                <PasswordExpires>false</PasswordExpires>
                            </LocalAccount>
                        </LocalAccounts>
                    </UserAccounts>
        """ : ""
        
        let protectPC = options.disableTelemetry ? 3 : 1
        
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <unattend xmlns="urn:schemas-microsoft-com:unattend">
            <settings pass="windowsPE">
                <component name="Microsoft-Windows-Setup" processorArchitecture="\(arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                    <RunSynchronous>
        \(runCommands)
                    </RunSynchronous>
                    <UserData>
                        <AcceptEula>true</AcceptEula>
                    </UserData>
                </component>
            </settings>
            <settings pass="oobeSystem">
                <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="\(arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                    <OOBE>
                        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                        <ProtectYourPC>\(protectPC)</ProtectYourPC>
                    </OOBE>
        \(localUserBlock)
                </component>
            </settings>
        </unattend>
        """
    }
}
