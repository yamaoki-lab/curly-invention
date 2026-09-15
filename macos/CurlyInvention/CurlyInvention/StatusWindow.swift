//
//  StatusWindow.swift
//  CurlyInvention
//

import AppKit
import SwiftUI

/// 主ウインドウ "状況".
/// 折りたたみを入れるために, SwiftUI のシーンではなく NSWindow のサブクラスとして持つ. 中身は SwiftUI の ContentView.
final class StatusWindow: NSWindow {
    private static let frameAutosaveName = "StatusWindow"

    init(model: AppModel) {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = String(localized: "Status")
        // 閉じても捨てず, ウインドウメニューや Dock から開き直せるようにする.
        isReleasedWhenClosed = false

        // NSHostingView は SwiftUI の自然な大きさを, ウインドウの最小と最大の大きさとして伝える.
        let hostingView = NSHostingView(rootView: ContentView(model: model))
        contentView = hostingView
        setContentSize(hostingView.fittingSize)

        if !setFrameUsingName(Self.frameAutosaveName) {
            center()
        }
        setFrameAutosaveName(Self.frameAutosaveName)
    }
}
