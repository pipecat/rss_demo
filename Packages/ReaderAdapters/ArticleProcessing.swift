import Foundation
import JavaScriptCore
import SwiftSoup
import ReaderDomain
import ReaderApplication

public enum ArticleHTML {
    public static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    public static func plain(_ html: String) -> String { (try? SwiftSoup.parse(html).text()) ?? "" }
    public static func clean(_ html: String, base: URL) throws -> String {
        guard html.utf8.count <= 6_000_000 else { throw ReaderError.message("文章过大，暂不能处理。") }
        let doc = try SwiftSoup.parse(html, base.absoluteString)
        doc.outputSettings().prettyPrint(pretty: false)
        try doc.select("script, style, iframe, frame, object, embed, form, input, button, textarea, select, link, meta, base, svg, video, audio, source, template").remove()
        for img in try doc.select("img").array() {
            let alt = try img.attr("alt")
            try img.before("<aside class=\"image-placeholder\">▧　\(escape(alt.isEmpty ? "文章图片" : alt))<small>远程图片未加载 · 可在原文中查看</small></aside>")
            try img.remove()
        }
        for link in try doc.select("a[href]").array() {
            let href = try link.attr("href")
            if href.hasPrefix("#") { continue }
            if let absolute = URL(string: href, relativeTo: base)?.absoluteURL, URLPolicy.safePublicURL(absolute) {
                try link.attr("href", absolute.absoluteString)
            } else { try link.removeAttr("href") }
        }
        let whitelist = Whitelist.none()
        try whitelist.addTags("p", "div", "span", "section", "article", "header", "footer", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "dl", "dt", "dd", "blockquote", "pre", "code", "kbd", "samp", "table", "thead", "tbody", "tfoot", "tr", "th", "td", "caption", "figure", "figcaption", "a", "b", "strong", "i", "em", "u", "s", "del", "mark", "sup", "sub", "br", "hr", "small", "aside", "details", "summary", "math", "mrow", "mi", "mn", "mo", "ms", "mtext", "mfrac", "msqrt", "mroot", "msup", "msub", "msubsup", "munder", "mover", "munderover", "mtable", "mtr", "mtd", "semantics", "annotation")
        try whitelist.addAttributes(":all", "id", "lang", "dir")
        try whitelist.addAttributes("a", "href", "title")
        try whitelist.addAttributes("code", "class")
        try whitelist.addAttributes("aside", "class")
        try whitelist.addAttributes("th", "colspan", "rowspan", "scope")
        try whitelist.addAttributes("td", "colspan", "rowspan")
        try whitelist.addAttributes("ol", "start")
        try whitelist.addAttributes("math", "display", "xmlns")
        try whitelist.addAttributes("annotation", "encoding")
        let settings = OutputSettings().prettyPrint(pretty: false)
        return try SwiftSoup.clean(doc.body()?.html() ?? "", base.absoluteString, whitelist, settings) ?? ""
    }

    public static func page(_ article: Article, source: String, fontSize: Int = 18, dark: Bool = false) -> String {
        let background = dark ? "#1b1d20" : "#fcfbf8"
        let ink = dark ? "#e0e0dc" : "#292c2d"
        let muted = dark ? "#a2a8a8" : "#7c8282"
        let date = article.date?.formatted(date: .abbreviated, time: .omitted) ?? "无发布日期"
        return """
        <!doctype html><html lang="zh"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src 'none'; font-src 'none'; media-src 'none'; connect-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'">
        <style>
        :root { color-scheme: \(dark ? "dark" : "light"); } * { box-sizing: border-box; }
        body { margin: 0; background: \(background); color: \(ink); font: \(fontSize)px/1.85 -apple-system, 'PingFang SC', sans-serif; overflow-wrap: anywhere; }
        main { max-width: 790px; margin: auto; padding: 48px 48px 80px; }
        .eyebrow { color:#56816f; font-size:11px; font-weight:700; letter-spacing:2.2px; margin-bottom:24px; }
        h1 { font-family: Georgia, 'Songti SC', serif; font-size:36px; line-height:1.25; letter-spacing:-.6px; font-weight:600; margin:0 0 24px; }
        .meta { font-size:12px; color:\(muted); padding-bottom:26px; border-bottom:1px solid \(dark ? "#35393b" : "#e5e5df"); margin-bottom:26px; }
        .status { display:inline-block; font-size:11px; border:1px solid \(dark ? "#454b47" : "#dce4db"); padding:2px 8px; border-radius:4px; color:#6d8b79; margin-top:10px; }
        h2 { font-size:25px; line-height:1.4; margin:36px 0 16px; } h3 { font-size:21px; margin-top:30px; }
        p { margin:0 0 1.2em; } a { color:\(dark ? "#86ba9e" : "#397759"); text-decoration-thickness:1px; text-underline-offset:3px; }
        blockquote { border-left:3px solid #789a86; margin:24px 0; padding:10px 22px; background:\(dark ? "#242c28" : "#eff2ec"); }
        pre { overflow-x:auto; white-space:pre; padding:20px; border-radius:8px; background:\(dark ? "#121719" : "#edf0ed"); font:13px/1.7 ui-monospace, Menlo, monospace; tab-size:4; }
        code { font-family:ui-monospace, Menlo, monospace; font-size:.85em; } p code, li code { background:\(dark ? "#303632" : "#edf0ed"); padding:2px 5px; border-radius:4px; }
        table { display:block; overflow-x:auto; border-collapse:collapse; max-width:100%; font-size:14px; margin:24px 0; }
        th, td { border:1px solid \(dark ? "#414642" : "#dce0d9"); padding:9px 14px; min-width:100px; } th { background:\(dark ? "#29302b" : "#eff2ec"); }
        figure { margin:24px 0; } figcaption, small { color:\(muted); font-size:12px; }
        .image-placeholder { padding:22px; border:1px dashed \(dark ? "#48534b" : "#cdd6cd"); border-radius:6px; font-size:14px; color:\(muted); margin:22px 0; }
        .image-placeholder small { display:block; margin-top:6px; } hr { border:0; border-top:1px solid #adb6ad; margin:32px 0; }
        math { overflow-x:auto; max-width:100%; } :focus-visible { outline:2px solid #67977d; outline-offset:4px; }
        @media(max-width:520px) { main { padding:28px 24px 60px; } h1 { font-size:29px; } }
        </style></head><body><main>
        <div class="eyebrow">LLM / FIELD NOTES</div>
        <h1>\(escape(article.title))</h1>
        <div class="meta">\(escape(source))　·　\(escape(date))\(article.author.isEmpty ? "" : "　·　" + escape(article.author))<br><span class="status">\(escape(article.state.label))</span></div>
        <article>\(article.readingHTML.isEmpty ? "<p>订阅未提供正文，请尝试提取正文或打开原文。</p>" : article.readingHTML)</article>
        </main></body></html>
        """
    }
}

public struct ReadabilityExtractor: ArticleExtracting {
    public init() {}
    public func extract(_ article: Article) async throws -> (raw: String, clean: String) {
        let (data, url) = try await SafeHTTP().get(article.url)
        guard let html = String(data: data, encoding: .utf8) else { throw ReaderError.message("Demo 暂仅支持 UTF-8 正文。请在浏览器打开原文。") }
        let clean = try await Task.detached(priority: .userInitiated) { try Self.extractHTML(html, url: url) }.value
        return (html, clean)
    }
    public static func extractHTML(_ html: String, url: URL) throws -> String {
        guard html.utf8.count <= 6_000_000 else { throw ReaderError.message("正文超过处理限制。") }
        // Parsing in JavaScriptCore has no network, filesystem, browser, or native script bridge.
        // Source scripts are removed as data; only the two bundled upstream libraries execute.
        let doc = try SwiftSoup.parse(html, url.absoluteString)
        try doc.select("script, style, iframe, object, embed, template").remove()
        doc.outputSettings().syntax(syntax: .xml).escapeMode(Entities.EscapeMode.xhtml).prettyPrint(pretty: false)
        let normalized = try doc.outerHtml()
        guard let context = JSContext() else { throw ReaderError.message("无法启动正文提取器。") }
        for name in ["JSDOMParser", "Readability"] {
            let packaged = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("TopicReader_ReaderAdapters.bundle")) }
            let resourceBundle = packaged ?? Bundle.module
            guard let resource = resourceBundle.url(forResource: name, withExtension: "js", subdirectory: "Resources") else { throw ReaderError.message("缺少正文提取资源。") }
            context.evaluateScript(try String(contentsOf: resource, encoding: .utf8))
            if context.exception != nil { throw ReaderError.message("正文提取器初始化失败。") }
        }
        context.setObject(normalized, forKeyedSubscript: "inputHTML" as NSString)
        context.setObject(url.absoluteString, forKeyedSubscript: "inputURL" as NSString)
        let result = context.evaluateScript("""
        (function() {
          var doc = new JSDOMParser().parse(inputHTML);
          doc.documentURI = inputURL; doc.baseURI = inputURL;
          return new Readability(doc, {charThreshold: 100, maxElemsToParse: 30000}).parse();
        })()
        """)
        guard context.exception == nil, let content = result?.forProperty("content")?.toString(), content != "undefined", content != "null", !content.isEmpty else {
            throw ReaderError.message("未能识别正文，可能是动态页面或访问受限；已保留订阅内容。")
        }
        return try ArticleHTML.clean(content, base: url)
    }
}
