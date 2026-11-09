import Foundation

public struct Topic: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var sourceIDs: [String]
    public init(id: String, title: String, subtitle: String, sourceIDs: [String]) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.sourceIDs = sourceIDs
    }
}

public struct Source: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var feedURL: URL
    public var homepage: URL
    public var category: String
    public var monogram: String
    public var lastSuccess: Date?
    public var error: String?
    public init(id: String, name: String, feed: String, homepage: String, category: String, monogram: String) {
        self.id = id; self.name = name; self.feedURL = URL(string: feed)!; self.homepage = URL(string: homepage)!
        self.category = category; self.monogram = monogram
    }
}

public enum ContentState: String, Codable, Sendable {
    case summary, feedContent, extracted, failed, demo
    public var label: String {
        switch self {
        case .summary: return "订阅摘要"
        case .feedContent: return "订阅正文 · 完整性未确认"
        case .extracted: return "已提取正文 · 不保证完整"
        case .failed: return "提取失败 · 显示订阅内容"
        case .demo: return "本地演示文章"
        }
    }
}

public struct Article: Codable, Identifiable, Sendable {
    public var id: String
    public var sourceID: String
    public var title: String
    public var url: URL
    public var date: Date?
    public var author: String
    public var excerpt: String
    public var rawContent: String
    public var readingHTML: String
    public var fetchedPage: String?
    public var state: ContentState
    public var extractionError: String?
    public var isRead = false
    public var isStarred = false
    public init(id: String, sourceID: String, title: String, url: URL, date: Date?, author: String,
                excerpt: String, rawContent: String, readingHTML: String, state: ContentState) {
        self.id = id; self.sourceID = sourceID; self.title = title; self.url = url; self.date = date
        self.author = author; self.excerpt = excerpt; self.rawContent = rawContent; self.readingHTML = readingHTML; self.state = state
    }
}

public struct Library: Codable, Sendable {
    public var version = 1
    public var topic: Topic
    public var sources: [Source]
    public var articles: [Article]
    public var imported: Bool
    public init(topic: Topic, sources: [Source], articles: [Article] = [], imported: Bool = false) {
        self.topic = topic; self.sources = sources; self.articles = articles; self.imported = imported
    }
}

public enum DemoCatalog {
    public static let sources: [Source] = [
        Source(id: "lequn-chen", name: "Lequn Chen", feed: "https://le.qun.ch/en/blog/feed.xml", homepage: "https://le.qun.ch/en/blog/", category: "推理系统", monogram: "L"),
        Source(id: "horace-he", name: "Horace He", feed: "https://www.thonking.ai/feed", homepage: "https://www.thonking.ai/", category: "GPU · 性能", monogram: "H"),
        Source(id: "nathan-lambert", name: "Interconnects", feed: "https://www.interconnects.ai/feed", homepage: "https://www.interconnects.ai/", category: "后训练 · RL", monogram: "I"),
        Source(id: "lilian-weng", name: "Lilian Weng", feed: "https://lilianweng.github.io/index.xml", homepage: "https://lilianweng.github.io/", category: "研究综述", monogram: "W"),
        Source(id: "su-jianlin", name: "苏剑林 · 科学空间", feed: "https://spaces.ac.cn/feed", homepage: "https://spaces.ac.cn/", category: "数学 · 架构", monogram: "苏"),
        Source(id: "vllm", name: "vLLM Blog", feed: "https://vllm.ai/blog/rss.xml", homepage: "https://vllm.ai/blog", category: "推理引擎", monogram: "V")
    ]
    public static var library: Library {
        Library(topic: Topic(id: "llm", title: "LLM", subtitle: "模型、推理与系统，值得慢慢读。", sourceIDs: sources.map(\.id)), sources: sources)
    }
}
