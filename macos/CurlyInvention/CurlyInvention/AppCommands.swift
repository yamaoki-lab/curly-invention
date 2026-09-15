//
//  AppCommands.swift
//  CurlyInvention
//

import SwiftUI

struct AppCommands: Commands {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // 主ウインドウは閉じてもアプリが終わらないので, 開き直す項目を置く (メールの "メッセージビューア" と同じ).
        CommandGroup(after: .singleWindowList) {
            Button("Status") {
                openWindow(id: "main")
            }
            .keyboardShortcut("0")
        }

        CommandGroup(after: .newItem) {
            Menu("Open With") {
                ForEach(model.browsers) { browser in
                    Button {
                        model.openConsole(in: browser)
                    } label: {
                        Label {
                            if browser.showsVersion, let version = browser.version {
                                Text(verbatim: browser.name)
                                    + Text(verbatim: " (\(version))").foregroundStyle(.secondary)
                            } else {
                                Text(verbatim: browser.name)
                            }
                        } icon: {
                            Image(nsImage: browser.icon)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
            .disabled(model.consoleURL == nil)

            Divider()

            Button("Show in Finder") {
                model.revealStorageFolder()
            }
            .disabled(model.storageFolder == nil)
        }

        CommandGroup(after: .pasteboard) {
            Button("Copy Link") {
                model.copyConsoleURL()
            }
            .disabled(model.consoleURL == nil)
        }

        CommandMenu("Runtime") {
            Picker("Runtime", selection: $model.selectedRuntimeID) {
                ForEach(model.runtimes) { runtime in
                    Text(verbatim: runtime.name)
                        .tag(Optional(runtime.id))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            Divider()

            SettingsLink {
                Text("Runtime Settings…")
            }
        }
    }
}
