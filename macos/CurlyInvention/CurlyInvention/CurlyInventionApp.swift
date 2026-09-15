//
//  CurlyInventionApp.swift
//  CurlyInvention
//
//  Created by KN on R 8/09/10.
//

import SwiftUI

@main
struct CurlyInventionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Status", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .commands {
            AppCommands(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 主ウインドウを閉じてもアプリは終えない. 開き直すのはウインドウメニューから.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
