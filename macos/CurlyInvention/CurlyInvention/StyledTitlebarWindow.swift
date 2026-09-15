//
//  StyledTitlebarWindow.swift
//  CurlyInvention
//

import AppKit
import SwiftUI

/// タイトルバーの様式. console/ のウインドウの `titleBarOrientation` と `titleBarDensity` に揃えた2つの軸.
struct TitlebarStyle: Equatable {
    enum Orientation {
        /// 上端に横向きのタイトルバー.
        case horizontal
        /// 左端に縦向きのタイトルバー.
        case vertical
    }

    enum Density {
        /// 普通のウインドウの大きさのタイトルバー.
        case standard
        /// ユーティリティパネルの小さなタイトルバー.
        case compact
    }

    var orientation: Orientation = .horizontal
    var density: Density = .standard

    fileprivate var styleMask: NSWindow.StyleMask {
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if density == .compact {
            // 小さなタイトルバーと信号機は NSPanel でしか使えない.
            mask.insert(.utilityWindow)
        }
        if orientation == .vertical {
            // 純正のタイトルバーを透明にし, 中身をその下まで広げる.
            mask.insert(.fullSizeContentView)
        }
        return mask
    }

    /// タイトルバーの厚み. 同じ密度の純正のタイトルバーの高さを AppKit に計算させる.
    fileprivate var titlebarThickness: CGFloat {
        let mask = styleMask.subtracting(.fullSizeContentView)
        return NSWindow.frameRect(forContentRect: .zero, styleMask: mask).height
    }
}

/// タイトルバーを様式に沿って組み直したウインドウを作る.
///
/// 標準の密度は普通のウインドウ (NSWindow), コンパクトはパネル (NSPanel) にする. パネルの振る舞い
/// (手前に浮く, アプリを切り替えると隠れる, など) は変えず, 信号機の並びだけを組み直す.
/// 縦向きは確認の段で, 左端に仮の帯を置くだけ (信号機と題名はまだ無い).
enum StyledTitlebar {
    /// - Parameter frameAutosaveName: 位置を記憶する名前. nil なら記憶せず, 画面の中央に置く.
    static func makeWindow<Content: View>(
        title: String,
        frameAutosaveName: String?,
        style: TitlebarStyle,
        @ViewBuilder content: () -> Content
    ) -> NSWindow {
        let window: NSWindow = switch style.density {
        case .standard: StyledTitlebarWindow(titlebarStyle: style)
        case .compact: StyledTitlebarPanel(titlebarStyle: style)
        }
        window.setUpStyledTitlebar(title: title, frameAutosaveName: frameAutosaveName, style: style, content: content())
        return window
    }
}

/// 標準の密度のウインドウ.
final class StyledTitlebarWindow: NSWindow {
    let titlebarStyle: TitlebarStyle

    init(titlebarStyle: TitlebarStyle) {
        self.titlebarStyle = titlebarStyle
        super.init(contentRect: .zero, styleMask: titlebarStyle.styleMask, backing: .buffered, defer: false)
    }
}

/// コンパクトの密度のパネル.
final class StyledTitlebarPanel: NSPanel {
    let titlebarStyle: TitlebarStyle

    init(titlebarStyle: TitlebarStyle) {
        self.titlebarStyle = titlebarStyle
        super.init(contentRect: .zero, styleMask: titlebarStyle.styleMask, backing: .buffered, defer: false)
    }
}

private extension NSWindow {
    func setUpStyledTitlebar<Content: View>(
        title: String,
        frameAutosaveName: String?,
        style: TitlebarStyle,
        content: Content
    ) {
        self.title = title
        // 閉じても捨てず, ウインドウメニューや Dock から開き直せるようにする.
        isReleasedWhenClosed = false

        // NSHostingView は SwiftUI の自然な大きさを持つので, ウインドウの大きさはそこから決める.
        let hostingView = NSHostingView(rootView: content)
        switch style.orientation {
        case .horizontal:
            contentView = hostingView
        case .vertical:
            // 中身はタイトルバーの下まで広がるので, SwiftUI にタイトルバーの分の余白を取らせない.
            hostingView.safeAreaRegions = []
            contentView = makeVerticalTitlebarContainer(hostingView: hostingView, thickness: style.titlebarThickness)
        }
        if let contentView {
            setContentSize(contentView.fittingSize)
        }

        if let frameAutosaveName {
            if !setFrameUsingName(frameAutosaveName) {
                center()
            }
            setFrameAutosaveName(frameAutosaveName)
        } else {
            center()
        }

        switch style.orientation {
        case .horizontal:
            arrangeWindowButtons()
        case .vertical:
            break
        }
    }

    /// 縦向き: 純正のタイトルバーを見えなくし, 左端の帯と SwiftUI の中身を横に並べた入れ物を作る.
    func makeVerticalTitlebarContainer(hostingView: NSView, thickness: CGFloat) -> NSView {
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(buttonType)?.isHidden = true
        }
        // 透明にしても, AppKit はタイトルバーの範囲 (上端) を覚えていて, その範囲の何も無い所を掴むとウインドウが動く.
        // ボタンや選択できるテキストのような部品は移動を許さないと答えるので, 部品の操作は奪われない. 何も無い所で動くのは受け入れる.
        // isMovable = false で止めると, ウインドウメニューの移動の項目まで無効になるので使わない.
        let titlebar = VerticalTitlebarView()
        let container = NSView()
        for view in [titlebar, hostingView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            titlebar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titlebar.topAnchor.constraint(equalTo: container.topAnchor),
            titlebar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            titlebar.widthAnchor.constraint(equalToConstant: thickness),
            hostingView.leadingAnchor.constraint(equalTo: titlebar.trailingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    /// 信号機を Stickies のように並べ替える. 閉じるボタンは左上に残し, 拡大としまうボタンを右上に置く.
    ///
    /// 右上のボタンは標準のものを動かさず, 同じ見た目のものを新しく作る. 標準のボタンを右へ動かすと,
    /// AppKit の組の範囲 (3つのボタンの枠を全部含む長方形) が赤から黄まで広がり, 間のタイトルバーでも記号が出るため.
    /// 隠した標準のボタンは組の範囲に残るので, 赤の右隣の空いた所でも赤に × が出る. 標準の見た目に近い感触なので, そのままにしている.
    func arrangeWindowButtons() {
        guard
            let closeButton = standardWindowButton(.closeButton),
            let standardMiniaturizeButton = standardWindowButton(.miniaturizeButton),
            let standardZoomButton = standardWindowButton(.zoomButton),
            let titlebarView = closeButton.superview,
            let zoomButton = NSWindow.standardWindowButton(.zoomButton, for: styleMask),
            let miniaturizeButton = NSWindow.standardWindowButton(.miniaturizeButton, for: styleMask)
        else { return }

        // 余白と間隔は, 標準の並びから読み取って右側でも同じにする. 密度が変わっても追従する.
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

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .trailing
        accessory.view = group
        addTitlebarAccessoryViewController(accessory)
    }
}

/// 縦向きのタイトルバーの帯. 今は確認用の仮の見た目で, ドラッグでウインドウを動かせるだけ.
private final class VerticalTitlebarView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemOrange.withAlphaComponent(0.4).setFill()
        NSBezierPath(rect: bounds).fill()
    }

    /// 純正のタイトルバーと同じく, アクティブでないウインドウでも最初のクリックからドラッグを受け付ける.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
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
        isMouseInside = true
        redrawButtons()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        redrawButtons()
    }

    @objc(_mouseInGroup:)
    func mouseInGroup(_ button: NSButton) -> Bool {
        isMouseInside
    }

    // ボタンは標準の枠の外にあるので, ウインドウがアクティブかどうかが変わった時に自分で描き直す (非アクティブで灰色にするため).

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(self, selector: #selector(windowActivationDidChange(_:)), name: name, object: window)
        }
    }

    @objc private func windowActivationDidChange(_ notification: Notification) {
        redrawButtons()
    }

    private func redrawButtons() {
        subviews.forEach { $0.needsDisplay = true }
    }
}
