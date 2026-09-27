import SwiftUI
import AppKit

public struct LogConsoleSheet: View {
    @ObservedObject var vm: MacbethViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(vm: MacbethViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal")
                    .font(.title2)
                Text("Macbeth Event Log")
                    .font(.headline)
                Spacer()
                Button("Copy All") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(vm.logs.joined(separator: "\n"), forType: .string)
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(vm.logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
                .frame(height: 320)
                .onChange(of: vm.logs.count) { _, newCount in
                    if newCount > 0 {
                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 580)
    }
}
