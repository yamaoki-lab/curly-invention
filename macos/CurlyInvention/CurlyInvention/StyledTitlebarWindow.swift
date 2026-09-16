//
//  StyledTitlebarWindow.swift
//  CurlyInvention
//

import AppKit
import SwiftUI

/// タイトルバーの様式. console/ のウインドウの `titleBarDensity` に揃えた軸.
/// console/ の `titleBarOrientation` (縦向き) は未実装で, 追って足す.
struct TitlebarStyle: Equatable {
    enum Density {
        /// 普通のウインドウの大きさのタイトルバー.
        case standard
        /// ユーティリティパネルの小さなタイトルバー.
        case compact
    }

    var density: Density = .standard

    fileprivate var styleMask: NSWindow.StyleMask {
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if density == .compact {
            // 小さなタイトルバーと信号機は NSPanel でしか使えない.
            mask.insert(.utilityWindow)
        }
        return mask
    }
}

/// タイトルバーを様式に沿って組み直したウインドウを作る.
///
/// 標準の密度は普通のウインドウ (NSWindow), コンパクトはパネル (NSPanel) にする. パネルの振る舞い
/// (手前に浮く, アプリを切り替えると隠れる, など) は変えず, 信号機の並びだけを組み直す.
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
        window.setUpStyledTitlebar(title: title, frameAutosaveName: frameAutosaveName, content: content())
        return window
    }
}

/// 標準の密度のウインドウ.
/// 折りたたみの処理は CollapsibleTitlebarWindow に共通で持ち, ここでは AppKit の入口から渡すだけにする.
final class StyledTitlebarWindow: NSWindow, CollapsibleTitlebarWindow {
    let titlebarStyle: TitlebarStyle
    let collapseState = TitlebarCollapseState()

    init(titlebarStyle: TitlebarStyle) {
        self.titlebarStyle = titlebarStyle
        super.init(contentRect: .zero, styleMask: titlebarStyle.styleMask, backing: .buffered, defer: false)
    }

    override func miniaturize(_ sender: Any?) { toggleCollapsed() }
    override func performMiniaturize(_ sender: Any?) { toggleCollapsed() }

    override func sendEvent(_ event: NSEvent) {
        if handleTitlebarDoubleClick(event) { return }
        super.sendEvent(event)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validateCollapseMenuItem(menuItem) ?? super.validateMenuItem(menuItem)
    }

    override func resignKey() {
        super.resignKey()
        resetMiniaturizeMenuItemTitle()
    }
}

/// コンパクトの密度のパネル.
/// 折りたたみの処理は CollapsibleTitlebarWindow に共通で持ち, ここでは AppKit の入口から渡すだけにする.
final class StyledTitlebarPanel: NSPanel, CollapsibleTitlebarWindow {
    let titlebarStyle: TitlebarStyle
    let collapseState = TitlebarCollapseState()

    init(titlebarStyle: TitlebarStyle) {
        self.titlebarStyle = titlebarStyle
        super.init(contentRect: .zero, styleMask: titlebarStyle.styleMask, backing: .buffered, defer: false)
    }

    override func miniaturize(_ sender: Any?) { toggleCollapsed() }
    override func performMiniaturize(_ sender: Any?) { toggleCollapsed() }

    override func sendEvent(_ event: NSEvent) {
        if handleTitlebarDoubleClick(event) { return }
        super.sendEvent(event)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validateCollapseMenuItem(menuItem) ?? super.validateMenuItem(menuItem)
    }

    override func resignKey() {
        super.resignKey()
        resetMiniaturizeMenuItemTitle()
    }
}

/// 折りたたみの状態. ウインドウとパネルで同じ処理を使うため, 状態だけを別の入れ物に持つ.
final class TitlebarCollapseState {
    fileprivate var isCollapsed = false
    fileprivate var expandedHeight: CGFloat = 0
    /// 折りたたみ中は位置の記憶を止めるので, その間の名前を預かる.
    fileprivate var suspendedFrameAutosaveName = ""
    /// 中身の SwiftUI の大きさをウインドウに伝える設定を切り替える. 作る時に設定する.
    fileprivate var setHostingSizingOptions: (NSHostingSizingOptions) -> Void = { _ in }
    fileprivate var expandedContentMinSize: NSSize = .zero
    fileprivate var expandedContentMaxSize: NSSize = .zero
    /// 文言を書き換えたウインドウメニューの "しまう" の項目.
    fileprivate weak var miniaturizeMenuItem: NSMenuItem?
}

/// Stickies のように, しまう操作をタイトルバーだけの高さへの折りたたみに置き換える.
///
/// しまう操作の行き先 (miniaturize と performMiniaturize) を差し替えるので, 右上の黄のボタン, ⌘M, ウインドウメニュー,
/// アクセシビリティの操作のどこから呼ばれても折りたたむ. タイトルバーのダブルクリックは, システム設定に関係なく常に折りたたむ.
protocol CollapsibleTitlebarWindow: NSWindow {
    var collapseState: TitlebarCollapseState { get }
}

extension CollapsibleTitlebarWindow {
    /// タイトルバーだけの高さに折りたたむ, または元の高さに開く. 上端の位置は保つ.
    func toggleCollapsed() {
        guard let contentView else { return }
        let state = collapseState

        if state.isCollapsed {
            var expandedFrame = frame
            expandedFrame.size.height = state.expandedHeight
            expandedFrame.origin.y = frame.maxY - state.expandedHeight
            contentView.isHidden = false
            setFrame(expandedFrame, display: true, animate: true)
            contentMinSize = state.expandedContentMinSize
            contentMaxSize = state.expandedContentMaxSize
            state.setHostingSizingOptions(.standardBounds)
            if !state.suspendedFrameAutosaveName.isEmpty {
                // setFrameAutosaveName は保存済みの位置へウインドウを戻すので, 先に今の位置 (折りたたみ中に動かした先) を保存しておく.
                saveFrame(usingName: state.suspendedFrameAutosaveName)
                setFrameAutosaveName(state.suspendedFrameAutosaveName)
                state.suspendedFrameAutosaveName = ""
            }
            state.isCollapsed = false
        } else {
            state.expandedHeight = frame.height
            state.expandedContentMinSize = contentMinSize
            state.expandedContentMaxSize = contentMaxSize
            // 縮んだ大きさを次の起動に持ち越さないよう, 折りたたみ中は位置の記憶を止める.
            if !frameAutosaveName.isEmpty {
                saveFrame(usingName: frameAutosaveName)
                state.suspendedFrameAutosaveName = frameAutosaveName
                setFrameAutosaveName("")
            }
            // 中身の自然な大きさがウインドウの最小の大きさになっているので, その伝達を外してから縮める.
            state.setHostingSizingOptions([])
            contentMinSize = .zero

            // タイトルバーの高さは, 同じ様式の純正のタイトルバーの高さを AppKit に計算させる.
            let titlebarHeight = NSWindow.frameRect(forContentRect: .zero, styleMask: styleMask).height
            var collapsedFrame = frame
            collapsedFrame.size.height = titlebarHeight
            collapsedFrame.origin.y = frame.maxY - titlebarHeight
            setFrame(collapsedFrame, display: true, animate: true)
            contentView.isHidden = true
            state.isCollapsed = true
        }
    }

    /// タイトルバーの範囲でのダブルクリックを拾って折りたたむ. 拾った時は true を返し, AppKit には渡さない. 信号機の上は除く.
    ///
    /// 2回目の押下で折りたたみ, 2回目の離しも AppKit に渡さない. AppKit はシステム設定 (しまう, 画面全体に表示など) の
    /// 動作を, 押下と離しのどちらかで行うので, 両方を止めないと折りたたみと一緒に動いてしまう.
    func handleTitlebarDoubleClick(_ event: NSEvent) -> Bool {
        guard event.type == .leftMouseDown || event.type == .leftMouseUp, event.clickCount == 2 else { return false }
        guard event.locationInWindow.y >= contentLayoutRect.maxY else { return false }
        if let hitView = contentView?.superview?.hitTest(event.locationInWindow), hitView is NSButton {
            return false
        }
        if event.type == .leftMouseDown {
            toggleCollapsed()
        }
        return true
    }

    /// ウインドウメニューの "しまう" を, 折りたたみの文言にする. 他のメニュー項目なら nil を返し, 判定を AppKit に任せる.
    /// このアプリのウインドウは全て折りたたむので, 文言は "折りたたむ" を基本にし, 折りたたみ中だけ "開く" にする.
    func validateCollapseMenuItem(_ menuItem: NSMenuItem) -> Bool? {
        guard menuItem.action == #selector(NSWindow.performMiniaturize(_:)) else { return nil }
        collapseState.miniaturizeMenuItem = menuItem
        menuItem.title = collapseState.isCollapsed ? String(localized: "Expand") : String(localized: "Collapse")
        return true
    }

    /// キーから外れた時に, 文言を "折りたたむ" に戻す. 設定ウインドウ (SwiftUI の Settings シーン) は
    /// このクラスではなく文言を書き換えないので, 折りたたみ中の "開く" が残らないようにする.
    func resetMiniaturizeMenuItemTitle() {
        collapseState.miniaturizeMenuItem?.title = String(localized: "Collapse")
    }
}

private extension NSWindow {
    func setUpStyledTitlebar<Content: View>(title: String, frameAutosaveName: String?, content: Content) {
        self.title = title
        // 閉じても捨てず, ウインドウメニューや Dock から開き直せるようにする.
        isReleasedWhenClosed = false

        // NSHostingView は SwiftUI の自然な大きさを, ウインドウの最小と最大の大きさとして伝える.
        let hostingView = NSHostingView(rootView: content)
        contentView = hostingView
        setContentSize(hostingView.fittingSize)
        (self as? CollapsibleTitlebarWindow)?.collapseState.setHostingSizingOptions = { [weak hostingView] options in
            hostingView?.sizingOptions = options
        }

        if let frameAutosaveName {
            if !setFrameUsingName(frameAutosaveName) {
                center()
            }
            setFrameAutosaveName(frameAutosaveName)
        } else {
            center()
        }

        arrangeWindowButtons()
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
