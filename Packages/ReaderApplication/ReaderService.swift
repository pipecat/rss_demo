import Foundation
import ReaderDomain

public protocol FeedLoading: Sendable {
    func fetch(_ source: Source) async throws -> [Article]
}
public protocol ArticleExtracting: Sendable {
    func extract(_ article: Article) async throws -> (raw: String, clean: String)
}
public protocol LibraryStoring: Sendable {
    func load() throws -> Library?
    func save(_ library: Library) throws
    func clear() throws
}

public struct ReaderService: Sendable {
    private let feeds: any FeedLoading
    private let extractor: any ArticleExtracting
    private let storage: any LibraryStoring
    public init(feeds: any FeedLoading, extractor: any ArticleExtracting, storage: any LibraryStoring) {
        self.feeds = feeds; self.extractor = extractor; self.storage = storage
    }
    public func load() throws -> Library? { try storage.load() }
    public func save(_ library: Library) throws { try storage.save(library) }
    public func clear() throws { try storage.clear() }
    public func fetch(_ source: Source) async throws -> [Article] { try await feeds.fetch(source) }
    public func extract(_ article: Article) async throws -> (raw: String, clean: String) { try await extractor.extract(article) }

    public static func merge(existing: [Article], incoming: [Article]) -> [Article] {
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for var article in incoming {
            if let previous = byID[article.id] {
                article.isRead = previous.isRead; article.isStarred = previous.isStarred
                if previous.state == .extracted {
                    article.readingHTML = previous.readingHTML; article.fetchedPage = previous.fetchedPage; article.state = previous.state
                }
            }
            byID[article.id] = article
        }
        return byID.values.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}
