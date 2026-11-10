import Foundation
import ReaderDomain
import ReaderApplication
import ReaderAdapters

private struct FixtureFeeds: FeedLoading {
    var articles: [Article]
    var fails = false
    func fetch(_ source: Source) async throws -> [Article] {
        if fails { throw URLError(.notConnectedToInternet) }
        return articles
    }
}

private actor FixtureExtractor: ArticleExtracting {
    var events: [String] = []
    let failures: Set<String>
    let empty: Set<String>
    let cancelled: Set<String>
    init(failures: Set<String> = [], empty: Set<String> = [], cancelled: Set<String> = []) {
        self.failures = failures; self.empty = empty; self.cancelled = cancelled
    }
    func extract(_ article: Article) async throws -> (raw: String, clean: String) {
        events.append("extract:\(article.id)")
        if cancelled.contains(article.id) { throw CancellationError() }
        if failures.contains(article.id) { throw URLError(.timedOut) }
        return ("<html>fetched page \(article.id)</html>", empty.contains(article.id) ? " \n" : "<p>Full body \(article.id)</p>")
    }
    func published(_ article: Article) { events.append("publish:\(article.id)") }
}

func runPrefetchChecks() async throws {
    let source = DemoCatalog.sources[0]
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LocalStore(directory: directory)
    func article(_ id: String, _ date: TimeInterval, state: ContentState = .summary) -> Article {
        Article(id: id, sourceID: source.id, title: id, url: source.homepage.appendingPathComponent(id),
                date: Date(timeIntervalSince1970: date), author: "Fixture", excerpt: "Short preview",
                rawContent: "<p>Original feed \(id)</p>", readingHTML: "<p>Feed fallback \(id)</p>", state: state)
    }
    let first = article("first", 3)
    let second = article("second", 2, state: .feedContent)
    var old = article("old", 1); old.isRead = true; old.isStarred = true
    let extractor = FixtureExtractor()
    let service = ReaderService(feeds: FixtureFeeds(articles: [first, second, first]), extractor: extractor, storage: store)
    let prepared = try await service.fetch(source, existing: [old]) { await extractor.published($0) }
    try check(prepared.count == 3 && prepared.allSatisfy { $0.state == .extracted }, "refresh prefetches both summary and feed content, including older cached articles")
    try check(prepared[0].rawContent == first.rawContent && prepared[0].fetchedPage == "<html>fetched page first</html>" && prepared[0].readingHTML == "<p>Full body first</p>", "feed snapshot, fetched page and rendered body remain separate")
    let events = await extractor.events
    try check(events == ["extract:first", "publish:first", "extract:second", "publish:second", "extract:old", "publish:old"], "deduplicated bodies publish sequentially before the next fetch")
    try check(prepared[2].isRead && prepared[2].isStarred, "older article prefetch preserves read and starred flags")
    let cached = try await service.fetch(source, existing: prepared)
    let cachedEvents = await extractor.events
    try check(cachedEvents == events && cached.allSatisfy { $0.state == .extracted }, "repeat refresh reuses cached bodies without extracting again")

    let failingExtractor = FixtureExtractor(failures: ["first"], empty: ["second"])
    let fallbackService = ReaderService(feeds: FixtureFeeds(articles: [first, second, old]), extractor: failingExtractor, storage: store)
    let fallbacks = try await fallbackService.fetch(source)
    try check(fallbacks[0].state == .failed && fallbacks[0].readingHTML == first.readingHTML && fallbacks[0].rawContent == first.rawContent && fallbacks[0].extractionError != nil, "body fetch failure keeps subscription content and records an error")
    try check(fallbacks[1].state == .failed && fallbacks[1].readingHTML == second.readingHTML && fallbacks[1].extractionError != nil && fallbacks[2].state == .extracted, "empty extraction falls back without stopping remaining articles")
    var emptyCache = first; emptyCache.state = .extracted; emptyCache.readingHTML = ""
    let repaired = try await fallbackService.fetch(source, existing: [emptyCache])
    try check(repaired[0].state == .failed && repaired[0].readingHTML == first.readingHTML, "empty cached body cannot hide subscription fallback when prefetch fails")
    let retryExtractor = FixtureExtractor()
    let retryService = ReaderService(feeds: FixtureFeeds(articles: []), extractor: retryExtractor, storage: store)
    let retried = try await retryService.fetch(source, existing: fallbacks)
    let retries = await retryExtractor.events
    try check(retries == ["extract:first", "extract:second"] && retried.allSatisfy { $0.state == .extracted && $0.extractionError == nil }, "refresh retries failed cached articles and clears errors after recovery")

    var replacement = prepared[2]; replacement.readingHTML = "<p>New complete body</p>"; replacement.isRead = false; replacement.isStarred = false
    let replaced = ReaderService.merge(existing: [prepared[2]], incoming: [replacement])
    try check(replaced[0].readingHTML == replacement.readingHTML && replaced[0].isRead && replaced[0].isStarred, "newly extracted body replaces older body while preserving current reading flags")
    let retained = ReaderService.merge(existing: [prepared[0]], incoming: [fallbacks[0]])
    try check(retained[0].state == .extracted && retained[0].readingHTML == prepared[0].readingHTML && retained[0].extractionError == nil, "fallback result cannot overwrite a successful cached body")

    let cancelledExtractor = FixtureExtractor(cancelled: ["second"])
    let cancelledService = ReaderService(feeds: FixtureFeeds(articles: [first, second, old]), extractor: cancelledExtractor, storage: store)
    var cancelled = false
    do { _ = try await cancelledService.fetch(source) { await cancelledExtractor.published($0) } }
    catch is CancellationError { cancelled = true }
    let cancellationEvents = await cancelledExtractor.events
    try check(cancelled && cancellationEvents == ["extract:first", "publish:first", "extract:second"], "cancellation keeps published successes and never publishes a false failure")

    let beforeExtractor = FixtureExtractor()
    let beforeService = ReaderService(feeds: FixtureFeeds(articles: [first]), extractor: beforeExtractor, storage: store)
    let beforeCancelled = await Task {
        withUnsafeCurrentTask { $0?.cancel() }
        do { _ = try await beforeService.fetch(source); return false }
        catch is CancellationError { return true }
        catch { return false }
    }.value
    let beforeEvents = await beforeExtractor.events
    try check(beforeCancelled && beforeEvents.isEmpty, "already cancelled refresh does not start extraction")
    let afterCancelled = await Task {
        do {
            _ = try await beforeService.fetch(source) { _ in withUnsafeCurrentTask { $0?.cancel() } }
            return false
        } catch is CancellationError { return true }
        catch { return false }
    }.value
    try check(afterCancelled, "cancellation after the final publish still cancels the refresh")

    let offlineExtractor = FixtureExtractor()
    let offlineService = ReaderService(feeds: FixtureFeeds(articles: [], fails: true), extractor: offlineExtractor, storage: store)
    var offline = false
    do { _ = try await offlineService.fetch(source, existing: prepared) }
    catch { offline = true }
    let offlineEvents = await offlineExtractor.events
    try check(offline && offlineEvents.isEmpty, "feed failure propagates without fetching or replacing cached articles")
    var library = DemoCatalog.library; library.articles = [prepared[0], fallbacks[1]]
    try service.save(library)
    let restored = try service.load()!
    try check(restored.articles[0].fetchedPage == prepared[0].fetchedPage && restored.articles[0].rawContent == first.rawContent && restored.articles[0].readingHTML == prepared[0].readingHTML && restored.articles.last?.extractionError != nil, "prefetched bodies and fallback errors survive local storage")

    let fixture = try DemoFixture.prefetchedArticle
    let rendered = ArticleHTML.page(fixture, source: "Synthetic source")
    try check(rendered.contains("本文由项目提供，仅用于离线阅读验收。") && rendered.contains("tokens_per_second") && rendered.contains("<table") && rendered.contains("<math") && fixture.readingHTML.contains("image-placeholder") && !rendered.contains("订阅只提供这段摘要"), "reader renders extracted body through its final footnote instead of the feed preview")
}
