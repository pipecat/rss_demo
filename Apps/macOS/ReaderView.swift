import SwiftUI
import ReaderDomain
import ReaderAdapters

private let accent = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.57, green: 0.75, blue: 0.64, alpha: 1)
        : NSColor(srgbRed: 0.24, green: 0.43, blue: 0.34, alpha: 1)
})

struct ReaderView: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.colorScheme) private var scheme
    private var paper: Color { scheme == .dark ? Color(red: 0.106, green: 0.114, blue: 0.125) : Color(red: 0.988, green: 0.984, blue: 0.973) }
    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HSplitView {
                sidebar.frame(minWidth: 180, idealWidth: 210, maxWidth: 220)
                articleList.frame(minWidth: 260, idealWidth: 320, maxWidth: 360)
                reader.frame(minWidth: 380, maxWidth: .infinity)
            }
            if let message = model.message {
                HStack { Image(systemName: "exclamationmark.circle"); Text(message).font(.caption); Spacer(); Button("关闭") { model.message = nil } }
                    .padding(10).background(Color.orange.opacity(0.1))
            }
        }
        .tint(accent)
        .sheet(isPresented: $model.showSources) { sourcesSheet }
        .sheet(isPresented: $model.showAbout) { aboutSheet }
        .alert("清除本地阅读缓存？", isPresented: $model.confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { model.clearCache() }
        } message: { Text("会删除文章、阅读状态与收藏，并恢复示例入口。之后可以重新导入刷新。") }
    }
    private var topBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) { Image(systemName: "square.stack.3d.up.fill").foregroundStyle(accent); Text("Topic Reader").font(.system(size: 14, weight: .semibold)) }
            Text("/  阅读空间").font(.system(size: 12)).foregroundStyle(.tertiary)
            Spacer()
            HStack(spacing: 6) { Circle().fill(accent.opacity(0.7)).frame(width: 5, height: 5); Text("本地优先").font(.system(size: 11)) }.foregroundStyle(.secondary)
            Divider().frame(height: 15)
            Button { model.showSources = true } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(.plain).help("来源与刷新状态")
        }.padding(.leading, 86).padding(.trailing, 22).frame(height: 53).background(.bar)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("你的阅读空间").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).padding(.top, 27).padding(.bottom, 14).padding(.horizontal, 20)
            Button { model.chooseSource(nil) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.fill").font(.system(size: 14))
                    Text("LLM").font(.system(size: 14, weight: .semibold)); Spacer()
                    Text("\(model.unreadCount)").font(.system(size: 11, weight: .medium)).monospacedDigit()
                }.foregroundStyle(model.sourceID == nil && model.filter != "starred" ? accent : .secondary)
                    .padding(12).background(model.sourceID == nil && model.filter != "starred" ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).padding(.horizontal, 10)
            Button { model.sourceID = nil; model.filter = "starred"; model.selectedID = model.visibleArticles.first?.id } label: {
                Label("稍后细读", systemImage: "bookmark").font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(model.filter == "starred" ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).padding(.horizontal, 10).foregroundStyle(.secondary)
            HStack { Text("主题来源"); Spacer(); Text("\(model.library.sources.count)") }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 10)
            ForEach(model.library.sources) { source in
                Button { model.chooseSource(source.id) } label: {
                    HStack(spacing: 10) {
                        SourceBadge(source: source, size: 25)
                        VStack(alignment: .leading, spacing: 3) { Text(source.name).font(.system(size: 12, weight: .medium)).lineLimit(1); Text(source.category).font(.system(size: 10)).foregroundStyle(.tertiary) }
                        Spacer(minLength: 0)
                        if model.busySources.contains(source.id) { ProgressView().controlSize(.mini) }
                        else if source.error != nil { Image(systemName: "exclamationmark.circle").font(.system(size: 10)).foregroundStyle(.orange) }
                    }.padding(.horizontal, 10).padding(.vertical, 9).background(model.sourceID == source.id ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).padding(.horizontal, 10).help(source.error ?? source.feedURL.absoluteString)
            }
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) { Image(systemName: "leaf"); Text("留一点时间，认真阅读。") }.font(.system(size: 11)).foregroundStyle(.secondary)
                Text("6 个来源 · 设备直连 · 无需 AI").font(.system(size: 10)).foregroundStyle(.tertiary)
                HStack {
                    Button { model.showSources = true } label: { Label("管理来源", systemImage: "gearshape") }.buttonStyle(.plain)
                    Spacer()
                    Button { model.showAbout = true } label: { Image(systemName: "info.circle") }.buttonStyle(.plain).help("关于与开源许可")
                }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 10)
            }.padding(20)
        }.frame(maxHeight: .infinity).background(scheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color(red: 0.95, green: 0.955, blue: 0.94))
    }
    private var articleList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text(model.sourceID == nil ? "LLM" : model.sourceName(model.sourceID!)).font(.system(size: model.sourceID == nil ? 30 : 22, weight: .semibold, design: .serif)).lineLimit(1)
                    Spacer()
                    Button { model.isRefreshing ? model.cancelRefresh() : model.refresh() } label: {
                        Image(systemName: model.isRefreshing ? "stop.circle" : "arrow.clockwise").font(.system(size: 14)).frame(width: 26, height: 26)
                    }.buttonStyle(.plain).help(model.isRefreshing ? "取消刷新" : "刷新订阅 ⌘R").keyboardShortcut("r", modifiers: .command)
                }
                Text(model.sourceID == nil ? "模型、推理与系统，值得慢慢读。" : "\(model.visibleArticles.count) 篇文章 · 按发布时间排序")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 7) { Image(systemName: "magnifyingglass").foregroundStyle(.tertiary); TextField("搜索这个主题", text: $model.search).textFieldStyle(.plain).font(.system(size: 12)) }
                    .padding(9).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                HStack(spacing: 18) {
                    filterButton("全部", value: "all"); filterButton("未读", value: "unread"); filterButton("收藏", value: "starred")
                    Spacer(); Text("\(model.visibleArticles.count)").font(.system(size: 10)).foregroundStyle(.tertiary).monospacedDigit()
                }.padding(.top, 4)
            }.padding(22)
            Divider()
            if !model.library.imported && !model.isVisualCheck {
                VStack(alignment: .leading, spacing: 8) {
                    Text("从 6 个精选来源开始").font(.system(size: 12, weight: .medium))
                    Text("点击后直接访问这些来源；不会调用模型。") .font(.system(size: 10)).foregroundStyle(.secondary)
                    Button("导入并刷新") { model.refresh() }.buttonStyle(.borderedProminent).controlSize(.small)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.06))
                Divider()
            }
            if model.visibleArticles.isEmpty {
                VStack(spacing: 12) { Image(systemName: "text.page").font(.system(size: 28)).foregroundStyle(.tertiary); Text(model.isRefreshing ? "正在获取文章…" : "这里暂时没有文章").font(.system(size: 13)); Text("试试其他筛选，或刷新来源。") .font(.system(size: 11)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.visibleArticles) { article in
                                Button { model.select(article.id) } label: { articleRow(article) }.buttonStyle(.plain).id(article.id)
                                Divider().padding(.leading, 22)
                            }
                        }
                    }.onChange(of: model.selectedID) { _, id in if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } } }
                }
            }
            Divider()
            HStack(spacing: 6) {
                if model.isRefreshing { ProgressView().controlSize(.mini); Text("更新 \(model.busySources.count) 个来源…") }
                else { Image(systemName: "clock"); Text(lastUpdate) }
                Spacer()
                if model.library.sources.contains(where: { $0.error != nil }) { Button("查看错误") { model.showSources = true }.buttonStyle(.plain).foregroundStyle(.orange) }
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).frame(height: 34)
        }.background(scheme == .dark ? Color(nsColor: .textBackgroundColor) : .white)
    }
    private var lastUpdate: String {
        guard let date = model.library.sources.compactMap(\.lastSuccess).max() else { return "尚未刷新 · 可离线查看示例" }
        return "最近成功更新 " + date.formatted(date: .omitted, time: .shortened)
    }
    private func filterButton(_ title: String, value: String) -> some View {
        Button { model.filter = value; model.selectedID = model.visibleArticles.first?.id } label: {
            Text(title).font(.system(size: 11, weight: model.filter == value ? .semibold : .regular)).foregroundStyle(model.filter == value ? accent : .secondary)
                .padding(.bottom, 5).overlay(alignment: .bottom) { if model.filter == value { Capsule().fill(accent).frame(height: 2) } }
        }.buttonStyle(.plain)
    }
    private func articleRow(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Circle().fill(article.isRead ? Color.clear : accent).frame(width: 5, height: 5)
                Text(model.sourceName(article.sourceID)).font(.system(size: 10, weight: .medium)).lineLimit(1)
                Spacer()
                if article.isStarred { Image(systemName: "bookmark.fill").foregroundStyle(accent) }
                Text(article.date?.formatted(.dateTime.month(.twoDigits).day(.twoDigits)) ?? "示例").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.foregroundStyle(.secondary)
            Text(article.title).font(.system(size: 15, weight: .semibold)).lineSpacing(3).lineLimit(3).multilineTextAlignment(.leading).foregroundStyle(.primary)
            Text(article.excerpt).font(.system(size: 11)).lineSpacing(3).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.secondary)
            Text(article.state == .demo ? "离线排版示例" : article.state == .summary ? "订阅摘要" : "文章").font(.system(size: 9)).foregroundStyle(.tertiary)
        }.padding(.horizontal, 22).padding(.vertical, 18).frame(maxWidth: .infinity, alignment: .leading)
            .background(model.selectedID == article.id ? accent.opacity(scheme == .dark ? 0.20 : 0.075) : .clear)
            .overlay(alignment: .leading) { if model.selectedID == article.id { Rectangle().fill(accent).frame(width: 3) } }
            .contentShape(Rectangle())
    }
    private var reader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Text("原文阅读").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button { model.fontSize = max(14, model.fontSize - 1) } label: { Image(systemName: "textformat.size.smaller") }.help("缩小字号")
                Button { model.fontSize = min(26, model.fontSize + 1) } label: { Image(systemName: "textformat.size.larger") }.help("放大字号")
                Divider().frame(height: 14)
                Button { model.toggleRead() } label: { Image(systemName: model.selected?.isRead == true ? "envelope.open" : "envelope.badge") }.help("切换已读状态").disabled(model.selected == nil)
                Button { model.toggleStar() } label: { Image(systemName: model.selected?.isStarred == true ? "bookmark.fill" : "bookmark") }.help("收藏 / 取消收藏 ⌘D").keyboardShortcut("d", modifiers: .command).disabled(model.selected == nil)
                Button { model.openOriginal() } label: { Image(systemName: "arrow.up.right.square") }.help("在浏览器打开原文").disabled(model.selected == nil || model.selected?.state == .demo)
            }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal, 24).frame(height: 51)
            Divider()
            if let article = model.selected {
                if article.state != .demo {
                    HStack(spacing: 9) {
                        Image(systemName: "doc.text").foregroundStyle(accent)
                        Text(article.state.label).lineLimit(1)
                        Spacer()
                        if model.extracting.contains(article.id) { ProgressView().controlSize(.mini); Text("提取中…") }
                        else { Button(article.state == .extracted ? "重新提取" : "提取正文") { model.extract() }.buttonStyle(.plain).foregroundStyle(accent) }
                    }.font(.system(size: 10)).padding(.horizontal, 24).frame(height: 33).background(accent.opacity(0.045))
                    if let error = article.extractionError { Text(error).font(.caption).foregroundStyle(.orange).padding(10).frame(maxWidth: .infinity, alignment: .leading) }
                }
                ArticleWebView(html: ArticleHTML.page(article, source: model.sourceName(article.sourceID), fontSize: model.fontSize, dark: scheme == .dark), articleID: article.id, openLink: model.openExternal)
            } else {
                VStack(spacing: 14) { Image(systemName: "book.closed").font(.system(size: 36, weight: .light)).foregroundStyle(accent.opacity(0.6)); Text("选一篇，慢慢读。") .font(.system(size: 20, design: .serif)); Text("原文与生成内容分开，阅读始终无需 AI。") .font(.system(size: 12)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(paper)
    }
    private var sourcesSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("LLM · 主题来源").font(.title2.bold()); Spacer(); Button("完成") { model.showSources = false }.keyboardShortcut(.defaultAction) }
            Text("这些入口来自已有示例。历史验证与本次刷新结果分别记录；应用启动不会自动联网。") .font(.callout).foregroundStyle(.secondary)
            ForEach(model.library.sources) { source in
                HStack(alignment: .top, spacing: 12) {
                    SourceBadge(source: source, size: 32)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(source.name).font(.headline)
                        Text(source.feedURL.absoluteString).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(source.lastSuccess.map { "最后成功：" + $0.formatted(date: .abbreviated, time: .standard) } ?? "尚未成功刷新").font(.caption2).foregroundStyle(.secondary)
                        if let error = source.error { Text(error).font(.caption).foregroundStyle(.orange) }
                    }; Spacer()
                    if model.busySources.contains(source.id) { ProgressView().controlSize(.small) }
                    else { Image(systemName: source.error != nil ? "exclamationmark.circle" : source.lastSuccess == nil ? "circle.dashed" : "checkmark.circle.fill").foregroundStyle(source.error != nil ? .orange : accent) }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Picker("本机代理", selection: $model.proxyKind) { Text("HTTP").tag("http"); Text("SOCKS5").tag("socks5") }.frame(width: 170)
                    Text("127.0.0.1 :").font(.caption).foregroundStyle(.secondary)
                    TextField("端口（可留空）", text: $model.proxyPort).textFieldStyle(.roundedBorder).frame(width: 120)
                    Button("应用") { model.applyProxy() }.disabled(model.isRefreshing || !model.extracting.isEmpty)
                }
                Text(model.proxyStatus.isEmpty ? "留空使用系统网络设置。代理只用于订阅与正文请求，不修改系统设置。" : model.proxyStatus).font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                Button("导出主题…") { model.exportTopic() }
                Button("清除缓存…", role: .destructive) { model.showSources = false; model.confirmClear = true }.disabled(model.isRefreshing || !model.extracting.isEmpty)
                Spacer(); Button(model.isRefreshing ? "正在刷新…" : "刷新全部") { model.refresh() }.disabled(model.isRefreshing).buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(width: 580)
    }
    private var aboutSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Topic Reader").font(.largeTitle.bold())
            Text("LLM 阅读 Demo · 0.1.0").foregroundStyle(.secondary)
            Text("SwiftUI 原生界面，WebKit 隔离阅读。FeedKit 解析订阅，Mozilla Readability 在本机提取正文，SwiftSoup 清理 HTML。参考 NetNewsWire 的三栏阅读组织，未复制其源码或素材。")
            Text("FeedKit / SwiftSoup：MIT\nReadability：Apache-2.0\nJSDOMParser：MPL-2.0（源码随应用附带）").font(.callout)
            Text("当前不包含 AI、自动更新、图片下载、TeX 渲染或跨设备同步。提取结果不保证绕过截断或付费限制。") .font(.callout).foregroundStyle(.secondary)
            HStack { Button("查看开源许可") { if let url = Bundle.main.resourceURL?.appendingPathComponent("Licenses") { NSWorkspace.shared.open(url) } }; Spacer(); Button("完成") { model.showAbout = false }.keyboardShortcut(.defaultAction) }
        }.padding(32).frame(width: 510)
    }
}

struct SourceBadge: View {
    var source: Source
    var size: CGFloat
    private var color: Color {
        switch source.id { case "lequn-chen": return .brown; case "horace-he": return .indigo; case "nathan-lambert": return .orange; case "lilian-weng": return .teal; case "su-jianlin": return .purple; default: return accent }
    }
    var body: some View { Text(source.monogram).font(.system(size: size * 0.44, weight: .semibold, design: .serif)).foregroundStyle(color).frame(width: size, height: size).background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6)).accessibilityHidden(true) }
}
