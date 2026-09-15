//
//  AppModel.swift
//  CurlyInvention
//

import AppKit
import Observation

/// ランタイムの情報. 表示名や ID はランタイム自身が持つ (nk-a-79/hozonnyou#104).
struct RuntimeInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let version: String
    let summary: String
    /// 接続先. 接続先を持たないランタイムでは nil.
    var serverAddress: String?
}

/// console を開けるアプリ. 同じアプリの別の版も別の項目として持つ.
struct BrowserApplication: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let version: String?
    let icon: NSImage
    /// 同じ名前のアプリが他にもあり, 版で見分ける必要があるか.
    var showsVersion = false
}

@Observable
final class AppModel {
    var runtimes: [RuntimeInfo]
    var selectedRuntimeID: RuntimeInfo.ID?
    var consoleURL: URL?
    var storageFolder: URL?
    var storageUsedBytes: Int64?
    private(set) var browsers: [BrowserApplication] = []

    var selectedRuntime: RuntimeInfo? {
        runtimes.first { $0.id == selectedRuntimeID }
    }

    init() {
        // 仮の値. ランタイムの取得を実装したら置き換える.
        runtimes = [
            RuntimeInfo(id: "example.remote", name: "Example (Remote)", version: "0.0.0", summary: "", serverAddress: "example.local:3579"),
            RuntimeInfo(id: "example.local", name: "Example (Local)", version: "0.0.0", summary: "", serverAddress: nil),
        ]
        selectedRuntimeID = runtimes.first?.id
        consoleURL = URL(string: "http://127.0.0.1:3579/")
        refreshBrowsers()
    }

    func refreshBrowsers() {
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com/")!)
        browsers = Self.browserApplications(from: appURLs)
    }

    func openConsole(in browser: BrowserApplication) {
        guard let consoleURL else { return }
        NSWorkspace.shared.open([consoleURL], withApplicationAt: browser.url, configuration: NSWorkspace.OpenConfiguration())
    }

    func copyConsoleURL() {
        guard let consoleURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(consoleURL.absoluteString, forType: .URL)
        pasteboard.setString(consoleURL.absoluteString, forType: .string)
    }

    func revealStorageFolder() {
        guard let storageFolder else { return }
        NSWorkspace.shared.activateFileViewerSelecting([storageFolder])
    }

    /// https を開けるアプリの一覧から, メニューに並べる項目を作る.
    /// Finder の "このアプリケーションで開く" に倣い, 名前順に並べ, 同じ名前は版の新しい順にして版を添える.
    private static func browserApplications(from appURLs: [URL]) -> [BrowserApplication] {
        var apps = appURLs.map { url in
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            return BrowserApplication(
                url: url,
                // Finder と同じ表示名 (拡張子を見せる設定にも従う).
                name: FileManager.default.displayName(atPath: url.path),
                version: Bundle(url: url)?.infoDictionary?["CFBundleShortVersionString"] as? String,
                icon: icon
            )
        }
        apps.sort { lhs, rhs in
            let byName = sortKey(of: lhs.name).localizedStandardCompare(sortKey(of: rhs.name))
            if byName != .orderedSame { return byName == .orderedAscending }
            return (lhs.version ?? "").compare(rhs.version ?? "", options: .numeric) == .orderedDescending
        }
        let duplicatedNames = Dictionary(grouping: apps, by: \.name).filter { $0.value.count > 1 }.keys
        for index in apps.indices where duplicatedNames.contains(apps[index].name) {
            apps[index].showsVersion = true
        }
        return apps
    }

    /// 並べ替えでは拡張子を除く. 付けたままだと "Google Chrome for Testing.app" が "Google Chrome.app" より前に来る.
    private static func sortKey(of name: String) -> String {
        name.hasSuffix(".app") ? String(name.dropLast(".app".count)) : name
    }
}
