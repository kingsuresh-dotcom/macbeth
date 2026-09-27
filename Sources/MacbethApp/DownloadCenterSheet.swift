import SwiftUI
import MacbethCore

public struct DownloadCenterSheet: View {
    @ObservedObject var vm: MacbethViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(vm: MacbethViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.title)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("Official OS Download Center")
                        .font(.headline)
                    Text("Authentic retail images directly from Microsoft, Canonical, Fedora, and Debian")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Windows Section
                    Text("Microsoft Windows Official Images")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(MicrosoftDownloader.availableReleases, id: \.version) { win in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(win.version)
                                    .font(.body)
                                Text("Architecture: \(win.architecture) - \(win.directApiDocumentation)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Download") {
                                NSWorkspace.shared.open(win.officialPortalURL)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Linux Section
                    HStack {
                        Text("Official Linux Distributions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        if vm.isResolvingLinuxDistros {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Checking latest upstream...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(action: {
                                Task { await vm.refreshLinuxDistros() }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check Latest")
                                }
                                .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    ForEach(vm.linuxDistros) { distro in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(distro.name)
                                        .font(.body)
                                    if distro.isDynamicallyResolved {
                                        Text("LATEST")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.15))
                                            .foregroundColor(.green)
                                            .cornerRadius(3)
                                    }
                                }
                                Text(distro.version)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if let sha = distro.expectedSha256 {
                                    Text("SHA256: \(sha.prefix(12))...\(sha.suffix(8))")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Button(action: {
                                    NSWorkspace.shared.open(distro.releaseNotesURL)
                                }) {
                                    Image(systemName: "info.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("View Release Notes")

                                Button("Download ISO") {
                                    NSWorkspace.shared.open(distro.downloadURL)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 360)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 560)
        .task {
            await vm.refreshLinuxDistros()
        }
    }
}
