//
//  WebPageWindow.swift
//  CurlyInvention
//
//  Created by KN on R 8/10/25.
//

import AppKit
import WebKit

/// WKWebView でページを出すウインドウ1枚分.
///
/// 開発用という性格はここには持たせない. 将来 console を表示するウインドウが要る時に, 同じものを別の所から呼べるようにしておく
/// (二重に持つと実装の差で挙動がずれるため).
@MainActor
final class WebPageWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    /// 閉じた時に持ち主へ伝える. 複数枚持つ側が, 閉じた分を手放せるようにする.
    private var onClose: ((WebPageWindow) -> Void)?

    /// 大きさと位置は1つの名前で記憶する. 2枚目以降は前のウインドウからずらすので, 重なって見えなくなることはない.
    private static let frameAutosaveName = "WebPageWindow"
    /// 次のウインドウを置く位置. AppKit が自分で次の位置を返してくれる.
    private static var cascadePoint = NSPoint.zero
    /// 記憶が無い初回の大きさを, 画面の見える範囲に対する割合で決める. ページには自然な大きさが無いため.
    /// ページは横より縦に長いことが多いので, 縦を広く取る.
    private static let defaultWidthRatio = 0.5
    private static let defaultHeightRatio = 0.8

    init(onClose: @escaping (WebPageWindow) -> Void) {
        self.onClose = onClose

        webView = WKWebView()
        // Web インスペクタで中を見られるようにする. 開くのは Safari の 開発 メニュー > この Mac > このアプリ から.
        // WKWebView には開くための公開 API が無く, 右クリックのメニューにも項目は出ない (非公開の API が要る).
        webView.isInspectable = true

        window = StyledTitlebar.makeWindow(
            title: String(localized: "Web Page"),
            frameAutosaveName: Self.frameAutosaveName,
            style: TitlebarStyle(density: .standard),
            isResizable: true,
            contentView: webView,
            defaultContentSize: Self.defaultContentSize()
        )
        super.init()

        window.delegate = self
        // 最初の1枚には .zero を渡すので動かず, 2枚目以降が前の位置からずれる.
        Self.cascadePoint = window.cascadeTopLeft(from: Self.cascadePoint)

        // 題名はページのものに追従させる. まだ題名が無い間は URL を出すので, URL も見る.
        for observation in [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateTitle() }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateTitle() }
            },
        ] {
            observations.append(observation)
        }
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func load(_ url: URL) {
        if url.isFileURL {
            // ページが隣のファイルを読めるよう, 親ディレクトリまで読み取りを許す.
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func reload() {
        webView.reload()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
        onClose = nil
    }

    private func updateTitle() {
        // 題名を持たないページもあるので, その間は URL を出す.
        if let pageTitle = webView.title, !pageTitle.isEmpty {
            window.title = pageTitle
        } else if let url = webView.url {
            window.title = url.absoluteString
        } else {
            window.title = String(localized: "Web Page")
        }
    }

    private static func defaultContentSize() -> NSSize {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return .zero }
        return NSSize(
            width: visibleFrame.width * defaultWidthRatio,
            height: visibleFrame.height * defaultHeightRatio
        )
    }
}
