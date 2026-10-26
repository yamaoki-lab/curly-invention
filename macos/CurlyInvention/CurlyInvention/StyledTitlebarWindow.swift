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
    /// 中身を SwiftUI で渡す口. 中身の自然な大きさがそのままウインドウの大きさになる.
    /// - Parameter frameAutosaveName: 位置を記憶する名前. nil なら記憶せず, 画面の中央に置く.
    /// - Parameter isResizable: 利用者が大きさを変えられるようにするか.
    static func makeWindow<Content: View>(
        title: String,
        frameAutosaveName: String?,
        style: TitlebarStyle,
        isResizable: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> NSWindow {
        // NSHostingView は SwiftUI の自然な大きさを, ウインドウの最小と最大の大きさとして伝える.
        let hostingView = NSHostingView(rootView: content())
        let window = makeWindow(
            title: title,
            frameAutosaveName: frameAutosaveName,
            style: style,
            isResizable: isResizable,
            contentView: hostingView
        )
        // 折りたたむ時は, その伝達を外してから縮める.
        (window as? CollapsibleTitlebarWindow)?.collapseState.setHostingSizingOptions = { [weak hostingView] options in
            hostingView?.sizingOptions = options
        }
        return window
    }

    /// 中身を AppKit のビューで渡す口. WKWebView のように自然な大きさを持たないものはこちらを使う.
    /// - Parameter defaultContentSize: 記憶した位置が無い時の中身の大きさ. .zero ならビューの自然な大きさにする.
    static func makeWindow(
        title: String,
        frameAutosaveName: String?,
        style: TitlebarStyle,
        isResizable: Bool = false,
        contentView: NSView,
        defaultContentSize: NSSize = .zero
    ) -> NSWindow {
        let window: NSWindow = switch style.density {
        case .standard: StyledTitlebarWindow(titlebarStyle: style)
        case .compact: StyledTitlebarPanel(titlebarStyle: style)
        }
        // 拡大のボタンを押せるかは style mask から読むので, 中身を入れる前に決める.
        if isResizable {
            window.styleMask.insert(.resizable)
        }
        window.setUpStyledTitlebar(
            title: title,
            frameAutosaveName: frameAutosaveName,
            contentView: contentView,
            defaultContentSize: defaultContentSize
        )
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
    @objc func performZoomOrFullScreen(_ sender: Any?) { zoomOrToggleFullScreen(sender) }

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
    @objc func performZoomOrFullScreen(_ sender: Any?) { zoomOrToggleFullScreen(sender) }

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
    /// 折りたたむ前に伸縮できたか. 折りたたみ中は伸縮を止めるので, 開く時に戻す.
    fileprivate var wasResizable = false
    /// 右上に作り直した拡大のボタン. 伸縮を止めている間は押せなくする.
    fileprivate weak var zoomButton: NSButton?
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
        // フルスクリーンの間は高さを変えられないので折りたたまない.
        guard let contentView, !styleMask.contains(.fullScreen) else { return }
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
            if state.wasResizable {
                styleMask.insert(.resizable)
                state.zoomButton?.isEnabled = true
            }
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
            // 伸縮できるままだと, 折りたたみ中に下端を掴んで引き伸ばせてしまう (状態は折りたたみのままで見た目だけ開く).
            // 純正のウインドウでも伸縮できない間は拡大のボタンが押せないので, 作り直したボタンも揃える.
            state.wasResizable = styleMask.contains(.resizable)
            if state.wasResizable {
                styleMask.remove(.resizable)
                state.zoomButton?.isEnabled = false
            }

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
    /// 偶数回目の押下で折りたたみを切り替え, 離しも AppKit に渡さない. AppKit はシステム設定 (しまう, 画面全体に表示など) の
    /// 動作を, 押下と離しのどちらかで行うので, 両方を止めないと折りたたみと一緒に動いてしまう.
    func handleTitlebarDoubleClick(_ event: NSEvent) -> Bool {
        guard event.type == .leftMouseDown || event.type == .leftMouseUp, event.clickCount >= 2 else { return false }
        guard event.locationInWindow.y >= contentLayoutRect.maxY else { return false }
        if let hitView = contentView?.superview?.hitTest(event.locationInWindow), hitView is NSButton {
            return false
        }
        // 素早く続けて押すと, 3回目以降も1つの連なりとして届く. 2回ごとに1度だけ切り替える.
        // 2回目だけを見ていると3回目以降が AppKit に渡り, システム設定の動作 (画面全体に表示など) が起きてしまう.
        if event.type == .leftMouseDown, event.clickCount.isMultiple(of: 2) {
            toggleCollapsed()
        }
        return true
    }

    /// 右上に作り直した緑のボタンの行き先.
    ///
    /// このボタンはフルスクリーンの矢印の記号を出すので, そのまま押したらフルスクリーンにする.
    /// ⌥ を持つと記号が + に変わるので, その時は拡大/縮小にする. 純正のボタンと同じ振り分け.
    func zoomOrToggleFullScreen(_ sender: Any?) {
        let allowsFullScreen = styleMask.contains(.resizable)
            && !(self is NSPanel)
            && !collectionBehavior.contains(.fullScreenNone)
        if allowsFullScreen, !NSEvent.modifierFlags.contains(.option) {
            toggleFullScreen(sender)
        } else {
            performZoom(sender)
        }
    }

    /// ウインドウメニューの "しまう" を, 折りたたみの文言にする. 他のメニュー項目なら nil を返し, 判定を AppKit に任せる.
    /// このアプリのウインドウは全て折りたたむので, 文言は "折りたたむ" を基本にし, 折りたたみ中だけ "開く" にする.
    func validateCollapseMenuItem(_ menuItem: NSMenuItem) -> Bool? {
        guard menuItem.action == #selector(NSWindow.performMiniaturize(_:)) else { return nil }
        collapseState.miniaturizeMenuItem = menuItem
        menuItem.title = collapseState.isCollapsed ? String(localized: "Expand") : String(localized: "Collapse")
        // フルスクリーンの間は高さを変えられないので折りたためない. 純正の しまう も同じ扱い.
        return !styleMask.contains(.fullScreen)
    }

    /// キーから外れた時に, 文言を "折りたたむ" に戻す. 設定ウインドウ (SwiftUI の Settings シーン) は
    /// このクラスではなく文言を書き換えないので, 折りたたみ中の "開く" が残らないようにする.
    func resetMiniaturizeMenuItemTitle() {
        collapseState.miniaturizeMenuItem?.title = String(localized: "Collapse")
    }
}

private extension NSWindow {
    func setUpStyledTitlebar(
        title: String,
        frameAutosaveName: String?,
        contentView view: NSView,
        defaultContentSize: NSSize
    ) {
        self.title = title
        // 閉じても捨てず, ウインドウメニューや Dock から開き直せるようにする.
        isReleasedWhenClosed = false

        contentView = view
        setContentSize(defaultContentSize == .zero ? view.fittingSize : defaultContentSize)

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
        // 記号に合わせてフルスクリーンと拡大/縮小を振り分ける. 振り分けを持たないウインドウでは拡大/縮小のままにする.
        let zoomAction = #selector(StyledTitlebarWindow.performZoomOrFullScreen(_:))
        zoomButton.action = responds(to: zoomAction) ? zoomAction : #selector(performZoom(_:))
        zoomButton.isEnabled = styleMask.contains(.resizable)
        (self as? CollapsibleTitlebarWindow)?.collapseState.zoomButton = zoomButton
        miniaturizeButton.target = self
        miniaturizeButton.action = #selector(performMiniaturize(_:))

        // フルスクリーンの間は, しまう操作ができない (純正の信号機も黄が無効になる).
        miniaturizeButton.isEnabled = !styleMask.contains(.fullScreen)

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
        group.miniaturizeButton = miniaturizeButton
        group.hostWindow = self

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
    /// しまうボタン. フルスクリーンの間は押せなくする.
    weak var miniaturizeButton: NSButton?
    /// ボタンたちが属するウインドウ.
    ///
    /// フルスクリーンに入ると, タイトルバーの付属ビューは AppKit によって別のウインドウへ移される.
    /// 今いるウインドウを見ると移った先を指してしまうので, 作った時のウインドウを覚えておく.
    weak var hostWindow: NSWindow? {
        didSet { observeHostWindow() }
    }
    private var isMouseInside = false
    /// ⌥ の押し下げを受け取る口. 記号が + に変わるのを, このボタンにも伝えるため.
    private var modifierMonitor: Any?

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

    // 信号機のセルは, 自分を囲むタイトルバーの枠を親からたどって探す. その探し方は `_mouseInGroup:` に
    // 答えるビューを枠と見なすものなので, この入れ物が枠として扱われる. すると枠にしか答えられないこと
    // (⌥ が押されているか, フルスクリーンか) を聞かれても答えられず, 記号が追従しなくなる.
    // 自分が答えられるもの以外は, 本物の枠へ取り次ぐ. 取り次ぎは Objective-C の標準の仕組みで, 非公開の
    // メソッドを呼ぶわけではない.

    override nonisolated func responds(to selector: Selector!) -> Bool {
        if super.responds(to: selector) { return true }
        return MainActor.assumeIsolated { themeFrame?.responds(to: selector) ?? false }
    }

    override nonisolated func forwardingTarget(for selector: Selector!) -> Any? {
        MainActor.assumeIsolated { themeFrame } ?? super.forwardingTarget(for: selector)
    }

    /// 本物のタイトルバーの枠 (NSThemeFrame). 中身のビューの親が枠のビューになるので, 非公開のクラス名に頼らずに辿れる.
    private var themeFrame: NSView? {
        hostWindow?.contentView?.superview
    }

    /// フルスクリーンの間だけ, 元のウインドウを答える.
    ///
    /// 信号機のセルは, 囲んでいる枠のウインドウを見て記号を選ぶ. フルスクリーンでは付属ビューが覆いのウインドウへ
    /// 移されるので, この入れ物 (枠として扱われている) が素直に答えると覆いのウインドウを指し, フルスクリーンだと
    /// 気付けない. 純正のボタンは本物の枠に聞いて元のウインドウを得ているので, そこに揃える.
    override var window: NSWindow? {
        if let hostWindow, super.window !== hostWindow, hostWindow.styleMask.contains(.fullScreen) {
            return hostWindow
        }
        return super.window
    }

    // ボタンは標準の枠の外にあり, 枠が面倒を見てくれる描き直しが届かない. 見た目が変わる場面を自分で拾う.
    // アクティブかどうか (非アクティブで灰色になる), フルスクリーンの出入り, ⌥ の押し下げ (記号が + に変わる) の3つ.

    /// 見るべきウインドウが決まった時に, その状態を見張り始める.
    private func observeHostWindow() {
        NotificationCenter.default.removeObserver(self)
        guard let hostWindow else { return }
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(self, selector: #selector(windowStateDidChange(_:)), name: name, object: hostWindow)
        }
        updateMiniaturizeButtonEnabled()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let modifierMonitor {
            NSEvent.removeMonitor(modifierMonitor)
            self.modifierMonitor = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.redrawButtons() }
            return event
        }
    }

    @objc private func windowStateDidChange(_ notification: Notification) {
        updateMiniaturizeButtonEnabled()
        redrawButtons()
    }

    /// フルスクリーンの間は, しまう操作ができない (純正の信号機も黄が無効になる).
    private func updateMiniaturizeButtonEnabled() {
        miniaturizeButton?.isEnabled = !(hostWindow?.styleMask.contains(.fullScreen) ?? false)
    }

    private func redrawButtons() {
        subviews.forEach { $0.needsDisplay = true }
    }
}
