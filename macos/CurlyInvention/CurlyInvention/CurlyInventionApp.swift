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

    var body: some Scene {
        // 主ウインドウ "状況" は AppDelegate が StatusWindow として持つ.
        Settings {
            SettingsView(model: appDelegate.model)
        }
        .commands {
            AppCommands(model: appDelegate.model, showStatusWindow: appDelegate.showStatusWindow)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusWindow: NSWindow?
    #if DEBUG
    private var titlebarSampleWindows: [NSWindow] = []
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        showStatusWindow()
        #if DEBUG
        showTitlebarSampleWindows()
        #endif
    }

    #if DEBUG
    /// 開発用: タイトルバーの様式の見本を, 状況のウインドウの下に並べて開く.
    private func showTitlebarSampleWindows() {
        guard let statusWindow else { return }
        titlebarSampleWindows = TitlebarSamples.makeWindows(below: statusWindow)
        titlebarSampleWindows.forEach { $0.orderFront(nil) }
        statusWindow.makeKeyAndOrderFront(nil)
    }
    #endif

    /// 主ウインドウを閉じてもアプリは終えない. 開き直すのはウインドウメニューか Dock から.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Dock のアイコンをクリックした時, 表示中のウインドウが無ければ "状況" を開き直す.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showStatusWindow()
        }
        return true
    }

    func showStatusWindow() {
        let window = statusWindow ?? StatusWindow.make(model: model)
        statusWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
