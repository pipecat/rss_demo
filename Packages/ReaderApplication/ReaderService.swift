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
    /// A user-initiated refresh prepares readable bodies before publishing each article.
    /// Sources may refresh concurrently; articles within a source are fetched sequentially.
    public func fetch(_ source: Source, existing: [Article] = [],
                      onArticle: @Sendable (Article) async -> Void = { _ in }) async throws -> [Article] {
        try Task.checkCancellation()
        let incoming = try await feeds.fetch(source)
        let articles = Self.merge(existing: existing.filter { $0.sourceID == source.id && $0.state != .demo }, incoming: incoming)
        var prepared: [Article] = []
        for var article in articles {
            try Task.checkCancellation()
            if article.state != .extracted || article.readingHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    let result = try await extractor.extract(article)
                    guard !result.clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw BodyPreparationError.emptyContent
                    }
                    article.fetchedPage = result.raw
                    article.readingHTML = result.clean
                    article.state = .extracted
                    article.extractionError = nil
                } catch {
                    if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                        throw CancellationError()
                    }
                    article.state = .failed
                    article.extractionError = error.localizedDescription
                }
            }
            try Task.checkCancellation()
            prepared.append(article)
            await onArticle(article)
            try Task.checkCancellation()
        }
        return prepared
    }
    public func extract(_ article: Article) async throws -> (raw: String, clean: String) { try await extractor.extract(article) }

    public static func merge(existing: [Article], incoming: [Article]) -> [Article] {
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for var article in incoming {
            if let previous = byID[article.id] {
                article.isRead = previous.isRead; article.isStarred = previous.isStarred
                if previous.state == .extracted && !previous.readingHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && article.state != .extracted {
                    article.readingHTML = previous.readingHTML; article.fetchedPage = previous.fetchedPage; article.state = previous.state
                    article.extractionError = previous.extractionError
                }
            }
            byID[article.id] = article
        }
        return byID.values.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}

private enum BodyPreparationError: LocalizedError {
    case emptyContent
    var errorDescription: String? { "未取得可阅读的正文，已保留订阅内容。" }
}
