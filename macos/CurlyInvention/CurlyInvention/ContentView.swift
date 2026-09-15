//
//  ContentView.swift
//  CurlyInvention
//
//  Created by KN on R 8/09/10.
//

import SwiftUI

struct ContentView: View {
    let model: AppModel

    var body: some View {
        Form {
            LabeledContent("Runtime") {
                Text(verbatim: model.selectedRuntime?.name ?? "—")
            }
            LabeledContent("URL") {
                Text(verbatim: model.consoleURL?.absoluteString ?? "—")
                    .textSelection(.enabled)
            }
            LabeledContent("Server") {
                Text(verbatim: model.selectedRuntime?.serverAddress ?? "—")
                    .textSelection(.enabled)
            }
            LabeledContent("Used Space") {
                if let bytes = model.storageUsedBytes {
                    Text(bytes, format: .byteCount(style: .file))
                } else {
                    Text(verbatim: "—")
                }
            }
        }
        .formStyle(.grouped)
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize()
    }
}

#Preview {
    ContentView(model: AppModel())
}
