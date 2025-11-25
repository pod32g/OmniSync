//
//  OmniSyncApp.swift
//  OmniSync
//
//  Created by David on 24/11/25.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // hides dock icon, keeps menu bar extra
    }
}

@main
struct OmniSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = SyncViewModel()
    @State private var mainWindow: NSWindow?

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .commands {
            CommandMenu("Sync") {
                Button("Sync Now") { viewModel.sync() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(!viewModel.canSync)
                Toggle(isOn: $viewModel.autoSyncEnabled) {
                    Text("Enable Auto Sync")
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("OmniSync", systemImage: "externaldrive.fill.badge.icloud") {
            VStack(alignment: .leading, spacing: 10) {
                Text("OmniSync")
                    .font(.headline)
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.sync()
                } label: {
                    HStack {
                        if viewModel.isSyncing {
                            ProgressView()
                        }
                        Text("Sync Now")
                    }
                }
                .disabled(!viewModel.canSync)

                Toggle("Auto Sync", isOn: $viewModel.autoSyncEnabled)
                Stepper("Every \(viewModel.autoSyncIntervalMinutes) min", value: $viewModel.autoSyncIntervalMinutes, in: 5...240, step: 5)
                    .disabled(!viewModel.autoSyncEnabled)

                Divider()
                Text("Host: \(viewModel.host.isEmpty ? "—" : viewModel.host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Show Main Window") {
                    showMainWindow()
                }
                Button("Hide Main Window") {
                    hideMainWindow()
                }
                Button("Quit OmniSync") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 240)
        }
    }

    private func showMainWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = mainWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
                mainWindow = window
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }

            let controller = NSHostingController(rootView: ContentView(viewModel: viewModel))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "OmniSync"
            window.contentViewController = controller
            window.makeKeyAndOrderFront(nil)
            mainWindow = window
        }
    }

    private func hideMainWindow() {
        DispatchQueue.main.async {
            if let window = mainWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
                window.orderOut(nil)
            }
        }
    }
}
