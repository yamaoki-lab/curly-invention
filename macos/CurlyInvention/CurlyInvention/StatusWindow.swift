//
//  StatusWindow.swift
//  CurlyInvention
//

import AppKit
import SwiftUI

/// 主ウインドウ "状況".
/// 折りたたみとタイトルバーの様式を使うために, SwiftUI のシーンではなく StyledTitlebar で作る. 中身は SwiftUI の ContentView.
enum StatusWindow {
    static func make(model: AppModel) -> NSWindow {
        StyledTitlebar.makeWindow(
            title: String(localized: "Status"),
            frameAutosaveName: "StatusWindow",
            style: TitlebarStyle(density: .standard)
        ) {
            ContentView(model: model)
        }
    }
}
