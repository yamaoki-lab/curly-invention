//
//  CurlyInventionApp.swift
//  CurlyInvention
//
//  Created by KN on R 8/09/10.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct CurlyInventionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 主ウインドウ "状況" は AppDelegate が StatusWindow として持つ.
        Settings {
            SettingsView(model: appDelegate.model)
        }
        .commands {
            AppCommands(
                model: appDelegate.model,
                showStatusWindow: appDelegate.showStatusWindow,
                openLocation: appDelegate.presentOpenLocation,
                openFile: appDelegate.presentOpenFile,
                reloadWebPage: appDelegate.reloadFrontWebPage
            )
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusWindow: NSWindow?
    /// 開いている Web のウインドウ. 閉じた分はその場で手放す.
    private var webPageWindows: [WebPageWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        showStatusWindow()
    }

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

    // MARK: - 開発 のメニュー

    /// 場所を開く… のシートを出し, 打たれた URL を新しいウインドウで開く.
    func presentOpenLocation() {
        OpenLocationSheet.present(recents: model.recentLocations) { [weak self] url in
            self?.openWebPage(url)
        }
    }

    /// ファイルを開く… で選ばれた手元のページを, 新しいウインドウで開く.
    func presentOpenFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openWebPage(url)
        }
    }

    /// 前面の Web のウインドウを読み込み直す. 前面に無ければ, 最後に開いたものを読み込み直す.
    func reloadFrontWebPage() {
        let front = webPageWindows.first { $0.window === NSApp.keyWindow }
        (front ?? webPageWindows.last)?.reload()
    }

    private func openWebPage(_ url: URL) {
        let webPageWindow = WebPageWindow { [weak self] closed in
            self?.webPageWindows.removeAll { $0 === closed }
            self?.model.hasWebPages = self?.webPageWindows.isEmpty == false
        }
        webPageWindows.append(webPageWindow)
        model.hasWebPages = true
        webPageWindow.load(url)
        webPageWindow.show()
        model.rememberLocation(url)
    }
}
