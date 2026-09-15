//
//  TitlebarSamples.swift
//  CurlyInvention
//

#if DEBUG
import AppKit
import SwiftUI

/// 開発用: タイトルバーの様式を見比べるための見本のウインドウ. デバッグビルドの時だけ作る.
/// 利用者に見せないので, 文言は訳さない.
enum TitlebarSamples {
    static let entries: [(number: Int, style: TitlebarStyle)] = [
        (2, TitlebarStyle(orientation: .horizontal, density: .compact)),
        (3, TitlebarStyle(orientation: .vertical, density: .standard)),
        (4, TitlebarStyle(orientation: .vertical, density: .compact)),
    ]

    /// 見本のウインドウを作り, 最初のウインドウの真下から, 左端を揃えて縦一列に並べる.
    /// 見比べやすいように位置は記憶せず, 起動のたびに並べ直す.
    static func makeWindows(below firstWindow: NSWindow) -> [NSWindow] {
        // ウインドウ同士の間隔. 影が重ならないよう, 標準のタイトルバーの高さぶん離す.
        let gap = NSWindow.frameRect(forContentRect: .zero, styleMask: .titled).height
        var previousWindow = firstWindow
        return entries.map { number, style in
            let window = StyledTitlebar.makeWindow(
                title: "Sample \(number) (\(style.orientation), \(style.density))",
                frameAutosaveName: nil,
                style: style
            ) {
                TitlebarSampleView(number: number, style: style)
            }
            window.setFrameTopLeftPoint(NSPoint(x: previousWindow.frame.minX, y: previousWindow.frame.minY - gap))
            // 画面の下端を越えたら, タイトルバーが画面に残るよう AppKit に押し戻させる.
            if let screen = previousWindow.screen {
                window.setFrame(window.constrainFrameRect(window.frame, to: screen), display: false)
            }
            previousWindow = window
            return window
        }
    }
}

/// 見本の中身. 状況のウインドウと同じく, 横長の小さな表にする.
private struct TitlebarSampleView: View {
    let number: Int
    let style: TitlebarStyle

    @State private var pressCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // 縦向きの確認用: 見えないタイトルバーの範囲 (上端) に, 押せる部品と選択できるテキストを置く.
            if number == 3 {
                HStack {
                    Button {
                        pressCount += 1
                    } label: {
                        Text(verbatim: "Pressed \(pressCount)")
                    }
                    Text(verbatim: "selectable text")
                        .textSelection(.enabled)
                    Spacer()
                }
                .padding(.horizontal)
            }
            Form {
                row("Sample", "\(number)")
                row("Orientation", "\(style.orientation)")
                row("Density", "\(style.density)")
                row("Content", "http://127.0.0.1:3579/")
            }
            .formStyle(.grouped)
            .scrollBounceBehavior(.basedOnSize)
        }
        .fixedSize()
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
        } label: {
            Text(verbatim: label)
        }
    }
}
#endif
