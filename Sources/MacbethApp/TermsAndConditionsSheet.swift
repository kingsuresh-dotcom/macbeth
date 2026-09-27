import SwiftUI
import AppKit

public struct TermsAndConditionsSheet: View {
    @ObservedObject var vm: MacbethViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(vm: MacbethViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Legal Disclaimer & Terms of Use")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Please read and accept these terms to continue using Macbeth")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 2)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        Text("1. Purely Educational & Research Purposes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Macbeth is developed, published, and maintained solely and strictly for educational, evaluative, interoperability, and systems architecture research purposes. It is not designed or licensed for mission-critical computing environments.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Group {
                        Text("2. Inherent Risks of Low-Level Disk Operations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Raw disk writing, partitioning, and bootloader creation are INHERENTLY DESTRUCTIVE operations. Flashing an image will permanently and irreversibly erase all data on the target storage medium. You bear 100% sole responsibility for verifying target device nodes (/dev/disk*) and backing up all critical data before writing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Group {
                        Text("3. \"AS-IS\" Warranty Disclaimer")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("The Software is provided \"AS IS\", \"WITH ALL FAULTS\", and without warranties of any kind, whether express, implied, statutory, or otherwise, including but not limited to warranties of merchantability, fitness for a particular purpose, non-infringement, or error-free operation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Group {
                        Text("4. Absolute Limitation of Liability")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Under no legal theory shall the author(s), contributor(s), or copyright holder(s) be liable for any direct, indirect, incidental, consequential, special, punitive, or exemplary damages, including but not limited to loss of data, hardware damage, controller failure, or system inoperability arising from your use of this Software.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Group {
                        Text("5. Third-Party Trademarks & Non-Affiliation")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Microsoft, Windows, Windows 11, Apple, macOS, Ubuntu, Canonical, Fedora, Debian, Arch Linux, and Rufus are registered trademarks of their respective owners. Macbeth is an independent open-source project and is NOT affiliated with, sponsored by, or endorsed by any trademark holder.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Group {
                        Text("6. User Compliance & Licensing")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("You agree that you possess genuine, valid licenses for any operating systems installed using Macbeth and that your use complies with all applicable local, national, and international laws, regulations, and third-party End User License Agreements (EULAs).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
            }
            .frame(height: 280)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
            
            Divider()
            
            HStack {
                Button("Decline & Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Accept & Continue") {
                    vm.acceptTerms()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 540)
    }
}
