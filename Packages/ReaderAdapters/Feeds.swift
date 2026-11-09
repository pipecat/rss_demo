import Foundation
import CryptoKit
import FeedKit
import ReaderDomain
import ReaderApplication

public struct FeedAdapter: FeedLoading {
    public init() {}
    public func fetch(_ source: Source) async throws -> [Article] {
        let (data, _) = try await SafeHTTP().get(source.feedURL)
        return try await Task.detached(priority: .utility) { try Self.parse(data, source: source) }.value
    }
    public static func parse(_ data: Data, source: Source) throws -> [Article] {
        guard data.count <= 6_000_000, let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
            throw ReaderError.message("订阅过大或不是支持的 UTF-8 编码。")
        }
        // FeedKit uses Foundation XMLParser (external entity resolution defaults off).
        // Reject DTD/entity declarations before invoking it, including internal expansion bombs.
        let lower = text.lowercased()
        guard !lower.contains("<!doctype"), !lower.contains("<!entity") else { throw ReaderError.message("已拒绝包含 DTD 或实体声明的订阅。") }
        let feed = try Feed(data: data)
        switch feed {
        case .rss(let rss):
            var results: [Article] = []
            for item in (rss.channel?.items ?? []).prefix(40) {
                let content: String = item.content?.encoded ?? item.description ?? ""
                let result = try article(source: source, title: item.title, link: item.link, date: item.pubDate,
                                         author: item.author ?? "", html: content, full: item.content?.encoded != nil)
                if let result { results.append(result) }
            }
            return results
        case .atom(let atom):
            return try (atom.entries ?? []).prefix(40).compactMap { entry in
                let link = entry.links?.first(where: { $0.attributes?.rel == "alternate" || $0.attributes?.rel == nil })?.attributes?.href
                let content = entry.content?.text ?? entry.summary?.text ?? ""
                let kind = entry.content != nil ? entry.content?.attributes?.type : entry.summary?.attributes?.type
                return try article(source: source, title: entry.title, link: link, date: entry.published ?? entry.updated,
                                   author: entry.authors?.first?.name ?? "", html: kind == nil || kind == "text" ? "<p>\(ArticleHTML.escape(content))</p>" : content,
                                   full: entry.content?.text != nil)
            }
        default: throw ReaderError.message("此 Demo 暂支持 RSS 2.0 与 Atom。")
        }
    }
    private static func article(source: Source, title: String?, link: String?, date: Date?, author: String, html: String, full: Bool) throws -> Article? {
        guard let link, let url = URL(string: link, relativeTo: source.homepage)?.absoluteURL, URLPolicy.safePublicURL(url) else { return nil }
        guard html.utf8.count <= 1_500_000 else { return nil }
        let clean = try ArticleHTML.clean(html, base: url)
        var canonical = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        canonical.fragment = nil
        canonical.queryItems = canonical.queryItems?.filter { !$0.name.lowercased().hasPrefix("utm_") && !["fbclid", "gclid"].contains($0.name.lowercased()) }
        if canonical.queryItems?.isEmpty == true { canonical.queryItems = nil }
        let digest = SHA256.hash(data: Data((source.id + "|" + (canonical.string ?? url.absoluteString)).utf8)).map { String(format: "%02x", $0) }.joined()
        return Article(id: digest, sourceID: source.id, title: ArticleHTML.plain(title ?? "未命名文章"), url: url, date: date,
                       author: author, excerpt: String(ArticleHTML.plain(clean).prefix(220)), rawContent: html,
                       readingHTML: clean, state: full ? .feedContent : .summary)
    }
}
