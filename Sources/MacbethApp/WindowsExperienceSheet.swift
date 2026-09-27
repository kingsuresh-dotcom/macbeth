import SwiftUI
import MacbethCore

public struct WindowsExperienceSheet: View {
    @ObservedObject var vm: MacbethViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(vm: MacbethViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "window.badge.magnifyingglass")
                    .font(.title)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("Windows User Experience")
                        .font(.headline)
                    Text("Customize your Windows installation media")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $vm.windowsExperience.bypassTPMAndSecureBoot) {
                    VStack(alignment: .leading) {
                        Text("Remove requirement for 4GB+ RAM, Secure Boot and TPM 2.0")
                            .font(.subheadline)
                        Text("Bypasses Windows 11 hardware requirement checks in Windows Setup")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $vm.windowsExperience.bypassOnlineAccount) {
                    VStack(alignment: .leading) {
                        Text("Remove requirement for an online Microsoft account")
                            .font(.subheadline)
                        Text("Bypasses Microsoft Account/NRO setup and creates a local user account")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if vm.windowsExperience.bypassOnlineAccount {
                    HStack {
                        Text("Create a local account with username:")
                            .font(.caption)
                        TextField("Username", text: $vm.windowsExperience.localUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }
                    .padding(.leading, 24)
                }
                
                Toggle(isOn: $vm.windowsExperience.syncRtcToUtc) {
                    VStack(alignment: .leading) {
                        Text("Synchronize hardware clock to UTC (RealTimeIsUniversal)")
                            .font(.subheadline)
                        Text("Prevents dual-boot clock skew between macOS/Linux and Windows")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $vm.windowsExperience.disableTelemetry) {
                    VStack(alignment: .leading) {
                        Text("Disable data collection (Skip privacy questions)")
                            .font(.subheadline)
                        Text("Sets telemetry to minimal and accepts privacy defaults automatically")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $vm.windowsExperience.disableBitLocker) {
                    VStack(alignment: .leading) {
                        Text("Disable BitLocker automatic device encryption")
                            .font(.subheadline)
                        Text("Prevents drive from being automatically encrypted during OOBE")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $vm.windowsExperience.addInPlaceUpgradeWrapper) {
                    VStack(alignment: .leading) {
                        Text("Add in-place upgrade wrapper (setup.bat)")
                            .font(.subheadline)
                        Text("Enables hardware bypasses when running setup.exe from inside Windows")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            HStack {
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520)
    }
}
