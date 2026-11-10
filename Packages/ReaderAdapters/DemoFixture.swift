import Foundation
import ReaderDomain

public enum DemoFixture {
    /// Offline visual fixture: a short feed excerpt and a separately extracted body.
    public static var prefetchedArticle: Article {
        get throws {
            var result = article
            result.id = "synthetic-prefetched"
            result.sourceID = DemoCatalog.sources[0].id
            result.title = "全文预抓取 · 本地合成验收"
            result.url = DemoCatalog.sources[0].homepage.appendingPathComponent("synthetic-prefetch")
            result.rawContent = "<p>订阅只提供这段摘要。</p>"
            result.excerpt = "订阅只提供这段摘要。阅读区应直接展示提取后的完整合成文章。"
            let body = article.readingHTML.replacingOccurrences(
                of: "<aside class=\"image-placeholder\">▧　实验结果示意图<small>远程图片默认不加载</small></aside>",
                with: "<img src=\"https://example.com/synthetic-figure.png\" alt=\"实验结果示意图\">")
            let raw = "<html><head><title>全文预抓取</title></head><body><article>\(body)</article></body></html>"
            result.fetchedPage = raw
            result.readingHTML = try ReadabilityExtractor.extractHTML(raw, url: result.url)
            result.state = .extracted
            return result
        }
    }
    public static var article: Article {
        let body = """
        <p>这里是你的 LLM 阅读空间。围绕同一个主题，收集模型研究、推理系统和后训练实践，让信息回到适合认真阅读的节奏。</p>
        <blockquote><p>这是一篇本地合成的排版示例，不是任何订阅作者的文章。点击「导入并刷新」获取真实更新。</p></blockquote>
        <h2>从一个问题开始阅读</h2>
        <p>为什么更大的 batch 不一定带来更好的端到端体验？阅读技术文章时，保留实验条件、代码和表格，往往比一句结论更有价值。</p>
        <ul><li><strong>模型与研究：</strong>理解方法、假设与适用范围。</li><li><strong>推理与系统：</strong>关注吞吐、延迟和资源消耗。</li><li><strong>后训练与 RL：</strong>把实验结果放回训练流程中。</li></ul>
        <h2>代码保持原来的结构</h2>
        <pre><code class="language-python"># Synthetic example · no model request is sent
        def tokens_per_second(tokens, elapsed):
            if elapsed &lt;= 0:
                return 0
            return tokens / elapsed

        print(tokens_per_second(2048, 8))</code></pre>
        <h2>对比需要上下文</h2>
        <table><caption>合成数据，仅用于验证表格排版</caption><thead><tr><th>场景</th><th>Batch</th><th>关注指标</th><th>阅读重点</th></tr></thead><tbody><tr><td>交互式问答</td><td>1</td><td>首 token 延迟</td><td>用户等待时间</td></tr><tr><td>离线生成</td><td>32</td><td>吞吐量</td><td>总处理成本</td></tr></tbody></table>
        <h2>保留公式、图片说明和脚注</h2>
        <p>MathML 示例：<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>r</mi><mo>=</mo><mfrac><mi>N</mi><mi>t</mi></mfrac></math>。来源中的 TeX 文本暂保持原样，不自动调用模型重写。</p>
        <figure><aside class="image-placeholder">▧　实验结果示意图<small>远程图片默认不加载</small></aside><figcaption>图 1：图片说明保留在原来的位置。</figcaption></figure>
        <p>中英文混排也应该自然：Prefill 与 Decode 的瓶颈不同，判断优化效果需要先定义 workload。<sup><a href="#note-1">1</a></sup></p>
        <hr><p id="note-1"><small>1. 本文由项目提供，仅用于离线阅读验收。</small></p>
        """
        return Article(id: "local-welcome", sourceID: "demo", title: "让值得读的内容，回到阅读本身。", url: URL(string: "https://example.com/reader-demo")!, date: nil, author: "Topic Reader", excerpt: "从模型研究到推理系统，建立你的 LLM 阅读空间。包含代码、表格、公式与脚注的本地排版示例。", rawContent: body, readingHTML: body, state: .demo)
    }
}
