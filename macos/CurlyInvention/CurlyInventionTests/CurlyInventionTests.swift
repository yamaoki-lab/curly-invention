//
//  CurlyInventionTests.swift
//  CurlyInventionTests
//
//  Created by KN on R 8/09/10.
//

import Foundation
import Testing
@testable import CurlyInvention

struct CurlyInventionTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

@MainActor
struct OpenLocationSheetTests {

    @Test("scheme を書かなければ http を補う")
    func addsHTTPScheme() {
        #expect(OpenLocationSheet.url(from: "example.com")?.absoluteString == "http://example.com")
        #expect(OpenLocationSheet.url(from: "example.com:8080/path")?.absoluteString == "http://example.com:8080/path")
        #expect(OpenLocationSheet.url(from: "127.0.0.1:3579")?.absoluteString == "http://127.0.0.1:3579")
    }

    /// URL(string:) は localhost:5173 を scheme が localhost の URL として読む. そのまま渡すと
    /// WKWebView が扱えず, 開くアプリケーションを選ぶダイアログが出てしまう.
    @Test("宛先と番号の組を scheme と読み違えない")
    func doesNotMistakeHostPortForScheme() {
        #expect(OpenLocationSheet.url(from: "localhost:5173")?.absoluteString == "http://localhost:5173")
        #expect(OpenLocationSheet.url(from: "localhost:5173/results/")?.absoluteString == "http://localhost:5173/results/")
    }

    @Test("scheme があればそのまま使う")
    func keepsExistingScheme() {
        #expect(OpenLocationSheet.url(from: "http://localhost:5173")?.absoluteString == "http://localhost:5173")
        #expect(OpenLocationSheet.url(from: "https://example.com/a?b=c")?.absoluteString == "https://example.com/a?b=c")
        #expect(OpenLocationSheet.url(from: "file:///tmp/page.html")?.absoluteString == "file:///tmp/page.html")
    }

    @Test("/ で始まればファイルのパスとして扱う")
    func treatsLeadingSlashAsFilePath() {
        let url = OpenLocationSheet.url(from: "/tmp/does-not-exist.html")
        #expect(url?.isFileURL == true)
        #expect(url?.path == "/tmp/does-not-exist.html")
    }

    @Test("~ を自分のホームに開く")
    func expandsTilde() {
        let url = OpenLocationSheet.url(from: "~/does-not-exist.html")
        #expect(url?.isFileURL == true)
        #expect(url?.path == NSHomeDirectory() + "/does-not-exist.html")
    }

    @Test("前後の空白を落とし, 空なら作らない")
    func trimsAndRejectsEmpty() {
        #expect(OpenLocationSheet.url(from: "  localhost:5173  ")?.absoluteString == "http://localhost:5173")
        #expect(OpenLocationSheet.url(from: "") == nil)
        #expect(OpenLocationSheet.url(from: "   ") == nil)
    }

}
