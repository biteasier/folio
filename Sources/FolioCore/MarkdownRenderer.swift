import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Turns Markdown into HTML with cmark-gfm, the C parser GitHub itself uses.
///
/// On top of GitHub Flavored Markdown (tables, task lists, strikethrough,
/// autolinks, footnotes, raw HTML) it adds two things cmark does not know:
/// YAML front matter and `$…$` / `$$…$$` math. Math is lifted out before
/// parsing so that `_` and `*` inside formulas are not read as emphasis.
public enum MarkdownRenderer {
    private static let registerExtensions: Void = { cmark_gfm_core_extensions_ensure_registered() }()
    private static let extensionNames = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]
    private static let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_VALIDATE_UTF8

    public static func html(from markdown: String) -> String {
        _ = registerExtensions
        var source = Array(markdown.utf8)

        var prefix = ""
        if let (yaml, rest) = FrontMatter.split(source) {
            prefix = "<details class=\"front-matter\"><summary>Front matter</summary>"
                + "<pre><code class=\"language-yaml\">\(HTML.escape(yaml))</code></pre></details>\n"
            source = rest
        }

        let (protected, formulas) = MathExtractor.extract(source)
        var html = prefix + cmark(protected)
        if !formulas.isEmpty { html = MathExtractor.restore(html, formulas) }
        return html
    }

    private static func cmark(_ bytes: [UInt8]) -> String {
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }
        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) { cmark_parser_attach_syntax_extension(parser, ext) }
        }
        bytes.withUnsafeBufferPointer { buf in
            buf.baseAddress.map { cmark_parser_feed(parser, UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self), buf.count) }
        }
        guard let doc = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(doc) }
        guard let out = cmark_render_html(doc, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(out) }
        return String(cString: out)
    }
}

enum HTML {
    static func escape(_ s: String) -> String {
        var r = ""
        r.reserveCapacity(s.utf8.count)
        for c in s.unicodeScalars {
            switch c {
            case "&": r += "&amp;"
            case "<": r += "&lt;"
            case ">": r += "&gt;"
            case "\"": r += "&quot;"
            default: r.unicodeScalars.append(c)
            }
        }
        return r
    }
}

/// `---` YAML front matter at the very top of the file.
enum FrontMatter {
    static func split(_ s: [UInt8]) -> (yaml: String, rest: [UInt8])? {
        guard s.count >= 4, s[0] == 0x2D, s[1] == 0x2D, s[2] == 0x2D, s[3] == 0x0A || s[3] == 0x0D else { return nil }
        var i = s[3] == 0x0D && s.count > 4 && s[4] == 0x0A ? 5 : 4
        let bodyStart = i
        while i < s.count {
            var end = i
            while end < s.count, s[end] != 0x0A { end += 1 }
            var line = s[i..<end]
            if line.last == 0x0D { line = line.dropLast() }
            if line.elementsEqual("---".utf8) || line.elementsEqual("...".utf8) {
                let yaml = String(decoding: s[bodyStart..<i], as: UTF8.self)
                let rest = end < s.count ? Array(s[(end + 1)...]) : []
                return (yaml.trimmingCharacters(in: .newlines), rest)
            }
            i = end + 1
        }
        return nil
    }
}

/// Finds `$inline$` and `$$display$$` math outside code and swaps each for an
/// alphanumeric placeholder that the Markdown parser passes through untouched.
enum MathExtractor {
    struct Formula { let tex: String; let display: Bool }
    static let marker = "FOLIOMATH"

    static func extract(_ s: [UInt8]) -> ([UInt8], [Formula]) {
        guard s.contains(0x24) else { return (s, []) }   // no '$' at all: fast path
        var out: [UInt8] = []
        out.reserveCapacity(s.count)
        var formulas: [Formula] = []
        var fence: (char: UInt8, count: Int)? = nil
        var text: [UInt8] = []   // run of non-code lines, scanned for math as one block

        func flush() {
            guard !text.isEmpty else { return }
            scanInline(text, into: &out, formulas: &formulas)
            text.removeAll(keepingCapacity: true)
        }

        var i = 0
        while i < s.count {
            var end = i
            while end < s.count, s[end] != 0x0A { end += 1 }
            let lineEnd = end < s.count ? end + 1 : end
            let line = s[i..<end]

            if let f = fence {
                out.append(contentsOf: s[i..<lineEnd])
                if closesFence(line, f) { fence = nil }
            } else if let f = opensFence(line) {
                flush()
                fence = f
                out.append(contentsOf: s[i..<lineEnd])
            } else {
                text.append(contentsOf: s[i..<lineEnd])
            }
            i = lineEnd
        }
        flush()
        return (out, formulas)
    }

    private static func fenceInfo(_ line: ArraySlice<UInt8>) -> (UInt8, Int, ArraySlice<UInt8>)? {
        var j = line.startIndex, spaces = 0
        while j < line.endIndex, line[j] == 0x20, spaces < 4 { j += 1; spaces += 1 }
        guard spaces < 4, j < line.endIndex, line[j] == 0x60 || line[j] == 0x7E else { return nil }
        let c = line[j]
        var n = 0
        while j < line.endIndex, line[j] == c { j += 1; n += 1 }
        guard n >= 3 else { return nil }
        return (c, n, line[j...])
    }

    private static func opensFence(_ line: ArraySlice<UInt8>) -> (char: UInt8, count: Int)? {
        guard let (c, n, rest) = fenceInfo(line) else { return nil }
        if c == 0x60, rest.contains(0x60) { return nil }
        return (c, n)
    }

    private static func closesFence(_ line: ArraySlice<UInt8>, _ f: (char: UInt8, count: Int)) -> Bool {
        guard let (c, n, rest) = fenceInfo(line), c == f.char, n >= f.count else { return false }
        return rest.allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }
    }

    private static func isSpace(_ c: UInt8) -> Bool { c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D }

    private static func scanInline(_ s: [UInt8], into out: inout [UInt8], formulas: inout [Formula]) {
        var i = 0
        let n = s.count
        while i < n {
            let c = s[i]
            if c == 0x5C, i + 1 < n {                       // backslash escape
                out.append(c); out.append(s[i + 1]); i += 2; continue
            }
            if c == 0x60 {                                   // code span: copy verbatim
                var run = 0
                while i + run < n, s[i + run] == 0x60 { run += 1 }
                var j = i + run
                var close = -1
                while j < n {
                    if s[j] == 0x60 {
                        var r = 0
                        while j + r < n, s[j + r] == 0x60 { r += 1 }
                        if r == run { close = j + r; break }
                        j += r
                    } else { j += 1 }
                }
                let stop = close >= 0 ? close : i + run
                out.append(contentsOf: s[i..<stop]); i = stop; continue
            }
            if c == 0x24 {
                if i + 1 < n, s[i + 1] == 0x24 {             // $$ display $$
                    var j = i + 2
                    while j + 1 < n, !(s[j] == 0x24 && s[j + 1] == 0x24 && s[j - 1] != 0x5C) { j += 1 }
                    if j + 1 < n {
                        let tex = String(decoding: s[(i + 2)..<j], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !tex.isEmpty {
                            emit(Formula(tex: tex, display: true), &out, &formulas)
                            i = j + 2; continue
                        }
                    }
                } else if i + 1 < n, !isSpace(s[i + 1]) {    // $inline$ on one line
                    var j = i + 1
                    while j < n, s[j] != 0x0A {
                        if s[j] == 0x5C { j += 2; continue }
                        if s[j] == 0x24 { break }
                        j += 1
                    }
                    if j < n, s[j] == 0x24, !isSpace(s[j - 1]),
                       !(j + 1 < n && s[j + 1] >= 0x30 && s[j + 1] <= 0x39) {
                        let tex = String(decoding: s[(i + 1)..<j], as: UTF8.self)
                        emit(Formula(tex: tex, display: false), &out, &formulas)
                        i = j + 1; continue
                    }
                }
            }
            out.append(c); i += 1
        }
    }

    private static func emit(_ f: Formula, _ out: inout [UInt8], _ formulas: inout [Formula]) {
        out.append(contentsOf: "\(marker)\(formulas.count)Z".utf8)
        formulas.append(f)
    }

    /// Single pass over the HTML bytes, swapping each placeholder for its formula.
    static func restore(_ html: String, _ formulas: [Formula]) -> String {
        let src = Array(html.utf8)
        let m = Array(marker.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(src.count + formulas.count * 32)
        var i = 0
        while i < src.count {
            if src[i] == m[0], i + m.count < src.count, src[i..<(i + m.count)].elementsEqual(m) {
                var k = i + m.count, idx = 0, digits = 0
                while k < src.count, src[k] >= 0x30, src[k] <= 0x39, digits < 9 {
                    idx = idx * 10 + Int(src[k] - 0x30); k += 1; digits += 1
                }
                if digits > 0, k < src.count, src[k] == 0x5A, idx < formulas.count {   // "Z"
                    let f = formulas[idx]
                    out.append(contentsOf: (f.display ? "<span class=\"math display\">" : "<span class=\"math inline\">").utf8)
                    out.append(contentsOf: HTML.escape(f.tex).utf8)
                    out.append(contentsOf: "</span>".utf8)
                    i = k + 1
                    continue
                }
            }
            out.append(src[i]); i += 1
        }
        return String(decoding: out, as: UTF8.self)
    }
}

/// Reads a text file whatever its encoding.
public enum TextDecoding {
    public static func decode(_ data: Data) -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return String(decoding: data.dropFirst(3), as: UTF8.self) }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data, encoding: .utf16) { return s }
        }
        if let s = String(data: data, encoding: .utf8) { return s }
        return String(data: data, encoding: .windowsCP1252) ?? String(decoding: data, as: UTF8.self)
    }

    public static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdtxt", "mdtext", "mdx", "rmd", "qmd",
    ]
}
