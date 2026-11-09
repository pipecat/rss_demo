import SwiftUI
import AppKit
import ReaderDomain
import ReaderApplication
import ReaderAdapters

@MainActor
final class ReaderModel: ObservableObject {
    @Published var library: Library
    @Published var selectedID: String?
    @Published var sourceID: String?
    @Published var filter = "all"
    @Published var search = ""
    @Published var busySources: Set<String> = []
    @Published var extracting: Set<String> = []
    @Published var message: String?
    @Published var fontSize = 18
    @Published var showSources = false
    @Published var showAbout = false
    @Published var confirmClear = false
    @Published var proxyPort = NetworkSettings.localProxyPort.map(String.init) ?? ""
    @Published var proxyKind = NetworkSettings.localProxyKind
    @Published var proxyStatus = ""
    var refreshTask: Task<Void, Never>?
    let service: ReaderService
    let isVisualCheck: Bool

    init(service: ReaderService, visualCheck: Bool = false, livePreview: Bool = false) {
        self.service = service; self.isVisualCheck = visualCheck
        if visualCheck {
            library = livePreview ? ((try? service.load()) ?? DemoCatalog.library) : DemoCatalog.library
            if library.articles.isEmpty { library.articles = [DemoFixture.article] }
        } else {
            do { library = try service.load() ?? DemoCatalog.library }
            catch { library = DemoCatalog.library; message = "缓存读取失败：\(error.localizedDescription)。原文件未覆盖；请先备份或清除缓存。"; loadFailed = true }
            if library.articles.isEmpty { library.articles = [DemoFixture.article] }
        }
        selectedID = library.articles.first?.id
    }
    private var loadFailed = false
    func applyProxy() {
        do { try NetworkSettings.setLocalProxyPort(proxyPort, kind: proxyKind); proxyStatus = proxyPort.isEmpty ? "已恢复系统网络设置" : "已启用本机代理，下一次刷新生效" }
        catch { proxyStatus = error.localizedDescription }
    }
    var visibleArticles: [Article] {
        library.articles.filter { article in
            (sourceID == nil || article.sourceID == sourceID) &&
            (filter != "unread" || !article.isRead) && (filter != "starred" || article.isStarred) &&
            (search.isEmpty || (article.title + article.excerpt + sourceName(article.sourceID)).localizedCaseInsensitiveContains(search))
        }
    }
    var selected: Article? { library.articles.first { $0.id == selectedID } }
    var unreadCount: Int { library.articles.filter { !$0.isRead && $0.state != .demo }.count }
    var isRefreshing: Bool { refreshTask != nil }
    func sourceName(_ id: String) -> String { library.sources.first { $0.id == id }?.name ?? "本地阅读示例" }
    func select(_ id: String?) {
        selectedID = id
        if let index = library.articles.firstIndex(where: { $0.id == id }), !library.articles[index].isRead {
            library.articles[index].isRead = true; persist()
        }
    }
    func chooseSource(_ id: String?) { sourceID = id; filter = "all"; selectedID = visibleArticles.first?.id }
    func persist() {
        guard !isVisualCheck, !loadFailed else { return }
        do { try service.save(library) } catch { message = "保存失败：\(error.localizedDescription)" }
    }
    func toggleStar() {
        guard let index = library.articles.firstIndex(where: { $0.id == selectedID }) else { return }
        library.articles[index].isStarred.toggle(); persist()
    }
    func toggleRead() {
        guard let index = library.articles.firstIndex(where: { $0.id == selectedID }) else { return }
        library.articles[index].isRead.toggle(); persist()
    }
    func next(_ offset: Int) {
        let articles = visibleArticles
        guard !articles.isEmpty else { return }
        let index = articles.firstIndex { $0.id == selectedID } ?? 0
        select(articles[max(0, min(articles.count - 1, index + offset))].id)
    }
    func refresh() {
        guard refreshTask == nil, !isVisualCheck, !loadFailed else { return }
        library.imported = true; message = nil
        let sources = library.sources
        busySources = Set(sources.map(\.id))
        refreshTask = Task {
            await withTaskGroup(of: (String, [Article]?, String?).self) { group in
                for source in sources {
                    group.addTask { [service] in
                        do { return (source.id, try await service.fetch(source), nil) }
                        catch { return (source.id, nil, error.localizedDescription) }
                    }
                }
                for await (id, articles, error) in group {
                    busySources.remove(id)
                    guard !Task.isCancelled else { continue }
                    if let index = library.sources.firstIndex(where: { $0.id == id }) {
                        library.sources[index].error = error
                        if let articles {
                            library.sources[index].lastSuccess = Date()
                            library.articles.removeAll { $0.state == .demo }
                            library.articles = ReaderService.merge(existing: library.articles, incoming: articles)
                            if selected == nil { selectedID = visibleArticles.first?.id }
                        }
                    }
                }
            }
            busySources = []; refreshTask = nil; persist()
            if library.articles.isEmpty { selectedID = nil }
        }
    }
    func cancelRefresh() { refreshTask?.cancel() }
    func extract() {
        guard let article = selected, article.state != .demo, !extracting.contains(article.id) else { return }
        extracting.insert(article.id)
        Task {
            do {
                let result = try await service.extract(article)
                if let index = library.articles.firstIndex(where: { $0.id == article.id }) {
                    library.articles[index].readingHTML = result.clean; library.articles[index].fetchedPage = result.raw
                    library.articles[index].state = .extracted; library.articles[index].extractionError = nil
                }
            } catch {
                if let index = library.articles.firstIndex(where: { $0.id == article.id }) {
                    if library.articles[index].state != .extracted { library.articles[index].state = .failed }
                    library.articles[index].extractionError = error.localizedDescription
                }
            }
            extracting.remove(article.id); persist()
        }
    }
    func openOriginal() {
        guard let article = selected, article.state != .demo else { return }
        openExternal(article.url)
    }
    func openExternal(_ url: URL) {
        Task {
            do {
                try await Task.detached { try URLPolicy.validateDNS(url) }.value
                NSWorkspace.shared.open(url)
            } catch { message = error.localizedDescription }
        }
    }
    func clearCache() {
        guard refreshTask == nil, extracting.isEmpty else { return }
        do {
            try service.clear(); library = DemoCatalog.library; library.articles = [DemoFixture.article]
            sourceID = nil; filter = "all"; search = ""; selectedID = DemoFixture.article.id; message = nil; loadFailed = false
        } catch { message = "清除失败：\(error.localizedDescription)" }
    }
    func exportTopic() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "LLM-topic.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let cleanSources = DemoCatalog.sources
            let export = Library(topic: library.topic, sources: cleanSources, imported: false)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(export).write(to: url, options: .atomic)
        } catch { message = "导出失败：\(error.localizedDescription)" }
    }
}
