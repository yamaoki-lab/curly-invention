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

    private weak var trailingButtonGroup: NSView?

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

        arrangeWindowButtons()
    }

    // 右上のボタンは標準の枠の外にあるので, アクティブかどうかが変わった時に自分で描き直させる.

    override func becomeKey() {
        super.becomeKey()
        redrawTrailingButtons()
    }

    override func resignKey() {
        super.resignKey()
        redrawTrailingButtons()
    }

    override func becomeMain() {
        super.becomeMain()
        redrawTrailingButtons()
    }

    override func resignMain() {
        super.resignMain()
        redrawTrailingButtons()
    }

    private func redrawTrailingButtons() {
        trailingButtonGroup?.subviews.forEach { $0.needsDisplay = true }
    }

    /// 信号機を Stickies のように並べ替える. 閉じるボタンは左上に残し, 拡大としまうボタンを右上に置く.
    ///
    /// 右上のボタンは標準のものを動かさず, 同じ見た目のものを新しく作る. 標準のボタンを右へ動かすと,
    /// AppKit の組の範囲 (3つのボタンの枠を全部含む長方形) が赤から黄まで広がり, 間のタイトルバーでも記号が出るため.
    /// 隠した標準のボタンは組の範囲に残るので, 赤の右隣の空いた所でも赤に × が出る. 標準の見た目に近い感触なので, そのままにしている.
    private func arrangeWindowButtons() {
        guard
            let closeButton = standardWindowButton(.closeButton),
            let standardMiniaturizeButton = standardWindowButton(.miniaturizeButton),
            let standardZoomButton = standardWindowButton(.zoomButton),
            let titlebarView = closeButton.superview,
            let zoomButton = NSWindow.standardWindowButton(.zoomButton, for: styleMask),
            let miniaturizeButton = NSWindow.standardWindowButton(.miniaturizeButton, for: styleMask)
        else { return }

        // 余白と間隔は, 標準の並びから読み取って右側でも同じにする.
        let edgeMargin = closeButton.frame.minX
        let spacing = standardMiniaturizeButton.frame.minX - closeButton.frame.maxX
        let buttonY = closeButton.frame.minY

        standardMiniaturizeButton.isHidden = true
        standardZoomButton.isHidden = true

        zoomButton.target = self
        zoomButton.action = #selector(performZoom(_:))
        zoomButton.isEnabled = styleMask.contains(.resizable)
        miniaturizeButton.target = self
        miniaturizeButton.action = #selector(performMiniaturize(_:))

        let group = WindowButtonGroupView(frame: NSRect(
            x: 0,
            y: 0,
            width: zoomButton.frame.width + spacing + miniaturizeButton.frame.width + edgeMargin,
            height: titlebarView.frame.height
        ))
        zoomButton.setFrameOrigin(NSPoint(x: 0, y: buttonY))
        miniaturizeButton.setFrameOrigin(NSPoint(x: zoomButton.frame.maxX + spacing, y: buttonY))
        group.addSubview(zoomButton)
        group.addSubview(miniaturizeButton)
        trailingButtonGroup = group

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .trailing
        accessory.view = group
        addTitlebarAccessoryViewController(accessory)
    }
}

/// 右上の組の入れ物. 標準の信号機と同じく, 組の上にマウスがある間は記号を出させる.
///
/// 信号機のボタンは, 記号を出すかを親のビューに非公開のメソッド `_mouseInGroup:` で問い合わせる
/// (標準の信号機では, ウインドウの枠のビューが実装している). この入れ物はその問い合わせに答える.
/// 非公開の仕組みに乗っているので, 将来の macOS で問い合わせ方が変わると記号が出なくなる. その場合もボタンは押せる.
private final class WindowButtonGroupView: NSView {
    private var isMouseInside = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        setMouseInside(true)
    }

    override func mouseExited(with event: NSEvent) {
        setMouseInside(false)
    }

    @objc(_mouseInGroup:)
    func mouseInGroup(_ button: NSButton) -> Bool {
        isMouseInside
    }

    private func setMouseInside(_ inside: Bool) {
        isMouseInside = inside
        subviews.forEach { $0.needsDisplay = true }
    }
}
