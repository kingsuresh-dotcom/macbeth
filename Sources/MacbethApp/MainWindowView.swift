import SwiftUI
import MacbethCore
import UniformTypeIdentifiers

public struct MainWindowView: View {
    @ObservedObject var vm: MacbethViewModel
    
    public init(vm: MacbethViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Section 1: Drive Properties
            GroupBox(label: Label("Drive Properties", systemImage: "internaldrive").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    // Device Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device:").font(.caption).foregroundColor(.secondary)
                        HStack {
                            Picker("", selection: $vm.selectedDevice) {
                                if vm.availableDevices.isEmpty {
                                    Text("No removable USB drives found").tag(nil as DiskDevice?)
                                } else {
                                    ForEach(vm.availableDevices) { dev in
                                        Text(dev.displayName).tag(dev as DiskDevice?)
                                    }
                                }
                            }
                            .labelsHidden()
                            .disabled(vm.isBurning)
                            
                            Button(action: { Task { await vm.refreshDevices() } }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Refresh devices")
                            .disabled(vm.isBurning)
                        }
                    }
                    
                    // Boot Selection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Boot selection:").font(.caption).foregroundColor(.secondary)
                        HStack {
                            TextField("Select an ISO or disk image...", text: .constant(vm.imageInfo?.detectedOsName ?? vm.selectedImageURL?.lastPathComponent ?? ""))
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                            
                            Button("SELECT") {
                                openFilePicker()
                            }
                            .disabled(vm.isBurning)
                            
                            Button("DOWNLOAD") {
                                vm.showDownloadSheet = true
                            }
                            .disabled(vm.isBurning)
                        }
                        
                        if let info = vm.imageInfo {
                            HStack {
                                Text("\(info.imageType.rawValue) - \(info.architecture) (\(info.formattedSize))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if info.requiresPopcntAdvisory {
                                    Text("Requires SSE4.2 / POPCNT CPU")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // Partition Scheme & Target System
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Partition scheme:").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: $vm.partitionScheme) {
                                ForEach(PartitionScheme.allCases, id: \.self) { scheme in
                                    Text(scheme.rawValue).tag(scheme)
                                }
                            }
                            .labelsHidden()
                            .disabled(vm.isBurning)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target system:").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: $vm.targetSystem) {
                                ForEach(TargetSystem.allCases, id: \.self) { sys in
                                    Text(sys.rawValue).tag(sys)
                                }
                            }
                            .labelsHidden()
                            .disabled(vm.isBurning)
                        }
                    }
                }
                .padding(6)
            }
            
            // Section 2: Format Options
            GroupBox(label: Label("Format Options", systemImage: "slider.horizontal.3").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume label:").font(.caption).foregroundColor(.secondary)
                        TextField("Volume Label", text: $vm.volumeLabel)
                            .textFieldStyle(.roundedBorder)
                            .disabled(vm.isBurning)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("File system:").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: $vm.fileSystem) {
                                ForEach(TargetFileSystem.allCases, id: \.self) { fs in
                                    Text(fs.rawValue).tag(fs)
                                }
                            }
                            .labelsHidden()
                            .disabled(vm.isBurning)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cluster size:").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: .constant("4096 bytes (Default)")) {
                                Text("4096 bytes (Default)").tag("4096 bytes (Default)")
                            }
                            .labelsHidden()
                            .disabled(vm.isBurning)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Quick format", isOn: $vm.quickFormat)
                        Toggle("Check device for bad blocks (1 pass)", isOn: $vm.checkBadBlocks)
                        Toggle("Test for counterfeit flash (10-second boundary probe)", isOn: $vm.testFakeFlash)
                    }
                    .font(.subheadline)
                    .disabled(vm.isBurning)
                }
                .padding(6)
            }
            
            // Section 3: Status & Progress
            GroupBox(label: Label("Status", systemImage: "info.circle").font(.headline)) {
                VStack(spacing: 8) {
                    ProgressView(value: vm.progressPercentage, total: 100.0)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text(vm.statusText)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(vm.burnPhase == .failed ? .red : .primary)
                        Spacer()
                        if vm.currentSpeedMBps > 0 && vm.isBurning {
                            Text(String(format: "%.1f MB/s", vm.currentSpeedMBps))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(6)
            }
            
            // Bottom Action Bar
            HStack {
                Button(action: { vm.showLogSheet = true }) {
                    Label("LOG", systemImage: "list.bullet.rectangle")
                }
                .help("Show execution logs (Ctrl+L)")
                
                Spacer()
                
                if vm.isBurning {
                    Button("CANCEL") {
                        vm.cancelBurn()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button("START") {
                        vm.onStartClicked()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.selectedDevice == nil || vm.selectedImageURL == nil)
                }
                
                Button("CLOSE") {
                    NSApplication.shared.terminate(nil)
                }
                .disabled(vm.isBurning)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(width: 520)
        .sheet(isPresented: $vm.showWindowsExperienceSheet) {
            WindowsExperienceSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showLogSheet) {
            LogConsoleSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showDownloadSheet) {
            DownloadCenterSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showFullDiskAccessSheet) {
            FullDiskAccessSheet(vm: vm)
        }
        .alert("Erase Confirmation", isPresented: $vm.showConfirmEraseAlert) {
            Button("Cancel", role: .cancel) {}
            Button("ERASE AND BURN", role: .destructive) {
                Task { await vm.startBurn() }
            }
        } message: {
            if let dev = vm.selectedDevice {
                Text("WARNING: ALL DATA ON \(dev.displayName) WILL BE DESTROYED PERMANENTLY!\n\nTo continue with this operation, click ERASE AND BURN.")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $vm.isTargetedForDrop) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    Task { @MainActor in
                        await vm.selectImage(url: url)
                    }
                }
            }
            return true
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "iso") ?? .data,
            UTType(filenameExtension: "img") ?? .data,
            UTType(filenameExtension: "raw") ?? .data,
            .application
        ]
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await vm.selectImage(url: url)
            }
        }
    }
}
