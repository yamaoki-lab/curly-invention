//
//  SettingsView.swift
//  CurlyInvention
//

import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("Runtimes", systemImage: "shippingbox") {
                // 行の数に合わせて伸びる. ランタイムが大きく増えたら, 高さの上限を付けてスクロールさせる.
                Form {
                    ForEach(model.runtimes) { runtime in
                        LabeledContent {
                            Text(verbatim: runtime.version)
                        } label: {
                            Text(verbatim: runtime.name)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollBounceBehavior(.basedOnSize)
                .fixedSize()
            }
        }
    }
}

#Preview {
    SettingsView(model: AppModel())
}
