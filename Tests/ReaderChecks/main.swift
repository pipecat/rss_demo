import Foundation
import ReaderDomain
import ReaderApplication
import ReaderAdapters

var checks = 0
func check(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
    guard try condition() else { throw ReaderError.message("FAIL: \(label)") }
    checks += 1; print("PASS: \(label)")
}
do {
    let source = DemoCatalog.sources[0]
    let rss = """
    <?xml version="1.0"?><rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel><title>Fixture</title><item><title>中文 &amp; English</title><link>https://le.qun.ch/test?utm_source=test</link><description>Summary</description><content:encoded><![CDATA[<h2>Code</h2><pre><code class="language-python">  x = 1\n    y = 2</code></pre><script>alert(1)</script>]]></content:encoded></item></channel></rss>
    """
    let articles = try FeedAdapter.parse(Data(rss.utf8), source: source)
    try check(articles.count == 1 && articles[0].title == "中文 & English", "RSS unicode and entities")
    try check(articles[0].state == .feedContent && articles[0].rawContent.contains("<script>"), "raw snapshot retained separately")
    try check(!articles[0].readingHTML.contains("<script") && articles[0].readingHTML.contains("    y = 2"), "script removal and code whitespace")
    let same = try FeedAdapter.parse(Data(rss.replacingOccurrences(of: "?utm_source=test", with: "").utf8), source: source)
    try check(same[0].id == articles[0].id, "tracking parameters excluded from stable IDs")
    let atom = """
    <feed xmlns="http://www.w3.org/2005/Atom"><title>Fixture</title><id>x</id><entry><id>one</id><title>Atom article</title><link href="https://le.qun.ch/atom"/><content type="html">&lt;p&gt;Hello world&lt;/p&gt;</content></entry></feed>
    """
    let atomArticles = try FeedAdapter.parse(Data(atom.utf8), source: source)
    try check(atomArticles.count == 1 && atomArticles[0].readingHTML.contains("Hello world"), "Atom content parsing")
    var rejected = false
    do { _ = try FeedAdapter.parse(Data("<!DOCTYPE rss [<!ENTITY x SYSTEM 'file:///etc/passwd'>]>\(rss)".utf8), source: source) } catch { rejected = true }
    try check(rejected, "DTD and external entity rejection")
    let dirty = """
    <base href="http://localhost"><meta http-equiv="refresh" content="0;url=http://localhost"><p onclick="x()">Text</p><a href="javascript:alert(1)">bad</a><a href="http://127.0.0.1/x">local</a><a href="/safe">good</a><img src="http://localhost/track" alt="An image"><iframe src="https://example.com"></iframe><pre><code> a\n  b</code></pre><math><mfrac><mi>x</mi><mi>y</mi></mfrac></math><table><tr><td colspan="2">Cell</td></tr></table><a href="#foot">Footnote</a><p id="foot">Note</p>
    """
    let clean = try ArticleHTML.clean(dirty, base: source.homepage)
    try check(!clean.contains("onclick") && !clean.contains("javascript:") && !clean.contains("localhost") && !clean.contains("127.0.0.1") && !clean.contains("<iframe") && !clean.contains("<img"), "hostile HTML and remote resources removed")
    try check(clean.contains("https://le.qun.ch/safe") && clean.contains("href=\"#foot\""), "relative links and footnotes retained")
    try check(clean.contains("<math") && clean.contains("colspan=\"2\"") && clean.contains("An image"), "MathML tables and image descriptions retained")
    for address in ["file:///etc/passwd", "http://localhost", "http://127.0.0.1", "http://2130706433", "http://[::1]", "https://user:pass@example.com", "http://router.local", "https://example.com:7890"] {
        try check(!URLPolicy.safePublicURL(URL(string: address)!), "URL policy: \(address)")
    }
    try check(!URLPolicy.isPublicIPv4(0x0a000001) && !URLPolicy.isPublicIPv4(0xc0a80101) && URLPolicy.isPublicIPv4(0x08080808), "private IPv4 ranges blocked")
    var old = articles[0]; old.isRead = true; old.isStarred = true; old.state = .extracted; old.readingHTML = "<p>Extracted</p>"
    let merged = ReaderService.merge(existing: [old], incoming: articles + articles)
    try check(merged.count == 1 && merged[0].isRead && merged[0].isStarred && merged[0].readingHTML == "<p>Extracted</p>", "refresh dedup preserves reading state and extraction")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LocalStore(directory: directory)
    var library = DemoCatalog.library; library.articles = merged
    try store.save(library)
    try check(try store.load()?.articles.first?.isStarred == true, "local storage round trip")
    try store.clear(); try check(try store.load() == nil, "cache deletion")
    let prose = String(repeating: "This synthetic research article examines inference systems, latency and throughput. Careful measurement matters because workloads change the bottleneck. ", count: 16)
    let extracted = try ReadabilityExtractor.extractHTML("<html><head><title>Research fixture</title></head><body><nav>Navigation</nav><article><h1>Research fixture</h1><p>\(prose)</p><pre><code>  preserved = True</code></pre><script>throw new Error('source script must not run')</script></article></body></html>", url: source.homepage)
    try check(extracted.contains("Careful measurement") && !extracted.contains("<script"), "bundled Readability extracts locally without source scripts")
    try check(ArticleHTML.page(DemoFixture.article, source: "Fixture").contains("script-src 'none'"), "reader CSP denies scripts and network resources")
    try await runPrefetchChecks()
    print("\n\(checks) offline checks passed.")
} catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
