import SwiftUI
import AppKit

public struct FullDiskAccessSheet: View {
    @ObservedObject var vm: MacbethViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(vm: MacbethViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Full Disk Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("macOS requires Full Disk Access permission to write raw disk blocks directly to physical USB drives (standard requirement for disk imagers like Balena Etcher and Raspberry Pi Imager).")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("1.")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("Click **Open System Settings** below.")
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("2.")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("Turn **ON** the switch next to **Macbeth** (or click **+** and add `/Applications/Macbeth.app`).")
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("3.")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("Return here and click **START** to burn your drive.")
                }
            }
            .font(.callout)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: 420)
            
            HStack(spacing: 16) {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
