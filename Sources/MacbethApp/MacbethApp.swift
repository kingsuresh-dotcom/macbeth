import SwiftUI
import MacbethCore

@main
struct MacbethApp: App {
    @StateObject private var viewModel = MacbethViewModel()
    
    init() {
        if CommandLine.arguments.contains("--generate-screenshots") {
            ScreenshotGenerator.generateScreenshots(outDir: "docs/screenshots")
            exit(0)
        }
    }
    
    var body: some Scene {
        Window("Macbeth", id: "main") {
            MainWindowView(vm: viewModel)
                .frame(minWidth: 520, maxWidth: 520, minHeight: 560, maxHeight: 560)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Device") {
                Button("Refresh Devices") {
                    Task {
                        await viewModel.refreshDevices()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Show Event Log") {
                    viewModel.showLogSheet = true
                }
                .keyboardShortcut("l", modifiers: .control)
            }
        }
    }
}
