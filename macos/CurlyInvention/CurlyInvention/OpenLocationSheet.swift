//
//  OpenLocationSheet.swift
//  CurlyInvention
//
//  Created by KN on R 8/10/25.
//

import AppKit
import SwiftUI

/// 場所を開く… のシート. URL を打つか, 最近開いたものから選ぶ.
///
/// 前面のウインドウにシートとして出す. 表示中のウインドウが1枚も無い時は, それ自体を手前のウインドウとして出す.
@MainActor
final class OpenLocationSheet {
    private let window: NSWindow
    private weak var host: NSWindow?
    private let onOpen: (URL) -> Void
    /// シートが出ている間だけ自分を保つ. 閉じたら手放す.
    private static var presented: OpenLocationSheet?

    /// - Parameter recents: 最近開いた URL. 新しい順.
    static func present(recents: [String], onOpen: @escaping (URL) -> Void) {
        // 二重に出さない. 既に出ているならそれを前に出す.
        if let presented {
            presented.window.makeKeyAndOrderFront(nil)
            return
        }
        let sheet = OpenLocationSheet(onOpen: onOpen)
        presented = sheet
        sheet.setUp(recents: recents)
        sheet.show()
    }

    /// 打たれた文字から URL を作る.
    ///
    /// 開発サーバの宛先やファイルのパスを打ちやすくするため, scheme が無ければ補う.
    /// 頭が / か ~ ならファイルのパスとして扱い, それ以外は http を付ける.
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        if trimmed.firstMatch(of: Self.schemePrefix) != nil, let url = URL(string: trimmed) {
            return url
        }
        return URL(string: "http://" + trimmed)
    }

    /// 頭が "名前://" の形か.
    ///
    /// URL(string:) は localhost:5173 を scheme が localhost の URL として読むので, scheme の有無では
    /// 宛先かどうかを見分けられない. 扱えない scheme のまま渡すと, 開くアプリケーションを選ぶダイアログが出る.
    private static let schemePrefix = /^[A-Za-z][A-Za-z0-9+.-]*:\/\//

    private init(onOpen: @escaping (URL) -> Void) {
        self.onOpen = onOpen
        // シートとして出すので, タイトルバーは画面に出ない.
        window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
    }

    private func setUp(recents: [String]) {
        let hostingView = NSHostingView(rootView: OpenLocationView(
            recents: recents,
            onOpen: { [weak self] url in self?.finish(with: url) },
            onCancel: { [weak self] in self?.finish(with: nil) }
        ))
        window.contentView = hostingView
        window.setContentSize(hostingView.fittingSize)
    }

    private func show() {
        host = NSApp.keyWindow ?? NSApp.mainWindow
        if let host {
            host.beginSheet(window)
        } else {
            window.center()
            NSApp.runModal(for: window)
        }
    }

    private func finish(with url: URL?) {
        if let host {
            host.endSheet(window)
        } else {
            NSApp.stopModal()
            window.orderOut(nil)
        }
        Self.presented = nil
        if let url {
            onOpen(url)
        }
    }
}

private struct OpenLocationView: View {
    let recents: [String]
    let onOpen: (URL) -> Void
    let onCancel: () -> Void

    @State private var text = ""

    private var url: URL? { OpenLocationSheet.url(from: text) }

    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent {
                URLComboBox(text: $text, recents: recents)
                    .frame(width: Self.fieldWidth)
            } label: {
                Text("Location:")
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Open") {
                    if let url { onOpen(url) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url == nil)
            }
        }
        .padding()
    }

    /// 入力欄の幅は, よくある長さの URL が収まる幅を字の大きさから求める. 寸法を数値で決め打ちしないため.
    private static var fieldWidth: CGFloat {
        let sample = "http://localhost:5173/pen-input/index.html" as NSString
        let font = NSFont.controlContentFont(ofSize: NSFont.systemFontSize)
        return sample.size(withAttributes: [.font: font]).width
    }
}

/// 打てて, かつ最近開いたものから選べる入力欄. SwiftUI には同じ部品が無いので NSComboBox を借りる.
private struct URLComboBox: NSViewRepresentable {
    @Binding var text: String
    let recents: [String]

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.delegate = context.coordinator
        // 途中まで打つと, 最近開いたものから続きを補う.
        comboBox.completes = true
        comboBox.addItems(withObjectValues: recents)
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.text = $text
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            text.wrappedValue = comboBox.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox, comboBox.indexOfSelectedItem >= 0 else { return }
            // 選んだ直後は stringValue がまだ古いので, 選ばれた項目そのものから取る.
            text.wrappedValue = comboBox.itemObjectValue(at: comboBox.indexOfSelectedItem) as? String ?? ""
        }
    }
}
