import XCTest
@testable import FolioCore

final class MarkdownRendererTests: XCTestCase {
    func html(_ md: String) -> String { MarkdownRenderer.html(from: md) }

    func testCommonMark() {
        XCTAssertTrue(html("# Title").contains("<h1>Title</h1>"))
        XCTAssertTrue(html("**b** _i_").contains("<strong>b</strong> <em>i</em>"))
        XCTAssertTrue(html("```swift\nlet x = 1\n```").contains("<code class=\"language-swift\">"))
    }

    func testGFMExtensions() {
        let t = html("| a | b |\n|:--|--:|\n| 1 | 2 |")
        XCTAssertTrue(t.contains("<table>") && t.contains("<td align=\"right\">2</td>"))
        XCTAssertTrue(html("~~gone~~").contains("<del>gone</del>"))
        XCTAssertTrue(html("- [x] done\n- [ ] todo").contains("checked=\"\" disabled=\"\""))
        XCTAssertTrue(html("see https://example.com now").contains("<a href=\"https://example.com\">"))
        let fn = html("Text[^1]\n\n[^1]: Note.")
        XCTAssertTrue(fn.contains("class=\"footnotes\"") && fn.contains("fnref-1"))
    }

    func testRawHTMLAndTagFilter() {
        XCTAssertTrue(html("<details><summary>s</summary>x</details>").contains("<details>"))
        XCTAssertTrue(html("<script>alert(1)</script>").contains("&lt;script>"))
    }

    func testInlineAndDisplayMath() {
        let h = html("Euler: $e^{i\\pi}+1=0$ and $a_1 * b_2$.\n\n$$\n\\int_0^1 x_i\\,dx\n$$")
        XCTAssertTrue(h.contains("<span class=\"math inline\">e^{i\\pi}+1=0</span>"))
        XCTAssertTrue(h.contains("<span class=\"math inline\">a_1 * b_2</span>"), h)
        XCTAssertTrue(h.contains("<span class=\"math display\">\\int_0^1 x_i\\,dx</span>"))
        XCTAssertFalse(h.contains("<em>"))
    }

    func testDollarsThatAreNotMath() {
        let h = html("It costs $5 and $10 total. Escaped \\$x\\$.")
        XCTAssertFalse(h.contains("class=\"math"), h)
        XCTAssertTrue(h.contains("$5 and $10"))
    }

    func testMathIgnoredInCode() {
        let h = html("`$x$` and\n\n```\n$y$\n```")
        XCTAssertFalse(h.contains("class=\"math"), h)
        XCTAssertTrue(h.contains("<code>$x$</code>"))
    }

    func testFrontMatter() {
        let h = html("---\ntitle: Hi\n---\n# Body")
        XCTAssertTrue(h.contains("class=\"front-matter\"") && h.contains("title: Hi") && h.contains("<h1>Body</h1>"))
        XCTAssertTrue(html("---\n\ntext").contains("<hr />"))   // a rule, not front matter
    }

    func testDecoding() {
        XCTAssertEqual(TextDecoding.decode(Data([0xEF, 0xBB, 0xBF, 0x41])), "A")
        XCTAssertEqual(TextDecoding.decode(Data([0x63, 0x61, 0x66, 0xE9])), "café")   // Latin-1 fallback
    }

    func testLargeDocumentIsFast() {
        let block = "## Section\n\nSome *text* with `code` and a [link](x.md) and $x^2$.\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n"
        let doc = String(repeating: block, count: 5000)   // ~ 0.5 MB
        measure { _ = MarkdownRenderer.html(from: doc) }
    }
}
