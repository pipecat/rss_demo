import AppKit
import SwiftUI
import WebKit
import ReaderDomain
import ReaderApplication
import ReaderAdapters

@main
enum Launcher {
    @MainActor
    static func main() {
        let service = ReaderService(feeds: FeedAdapter(), extractor: ReadabilityExtractor(), storage: LocalStore())
        if CommandLine.arguments.contains("--refresh-demo") || CommandLine.arguments.contains("--extract-demo") {
            Task {
                do {
                    if CommandLine.arguments.contains("--use-environment-proxy") { try NetworkSettings.importEnvironmentProxy() }
                    var library = try service.load() ?? DemoCatalog.library
                    if CommandLine.arguments.contains("--extract-demo") {
                        guard let index = library.articles.firstIndex(where: { $0.sourceID == "lilian-weng" }) else { throw ReaderError.message("没有可验证的文章。") }
                        let result = try await service.extract(library.articles[index])
                        library.articles[index].fetchedPage = result.raw; library.articles[index].readingHTML = result.clean; library.articles[index].state = .extracted
                        try service.save(library)
                        print("Readability extraction verified: \(result.clean.utf8.count) bytes of sanitized HTML.")
                        exit(0)
                    }
                    library.imported = true
                    for index in library.sources.indices {
                        let source = library.sources[index]
                        do {
                            let articles = try await service.fetch(source, existing: library.articles)
                            library.articles.removeAll { $0.state == .demo }
                            library.articles = ReaderService.merge(existing: library.articles, incoming: articles)
                            library.sources[index].lastSuccess = Date(); library.sources[index].error = nil
                            let ready = articles.filter { $0.state == .extracted }.count
                            print("\(source.name): \(articles.count) articles, \(ready) extracted bodies, \(articles.count - ready) fallbacks")
                        } catch {
                            library.sources[index].error = error.localizedDescription
                            print("\(source.name): ERROR \(error.localizedDescription)")
                        }
                        try service.save(library)
                    }
                    print("Saved \(library.articles.count) articles to local Application Support.")
                    exit(library.articles.isEmpty ? 1 : 0)
                } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate(service: service)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let service: ReaderService
    var window: NSWindow!
    var model: ReaderModel!
    var observer: NSObjectProtocol?
    var snapshotStarted = false
    init(service: ReaderService) { self.service = service }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        let visual = arguments.contains("--visual-check")
        model = ReaderModel(service: service, visualCheck: visual, livePreview: arguments.contains("--live-data"), prefetchedPreview: arguments.contains("--prefetched"))
        let width: CGFloat = arguments.contains("--narrow") ? 1040 : 1360
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 860), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Topic Reader — LLM"
        window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 1000, height: 660)
        window.isReleasedWhenClosed = false
        if visual { window.appearance = NSAppearance(named: arguments.contains("--dark") ? .darkAqua : .aqua) }
        window.contentView = NSHostingView(rootView: ReaderView(model: model).ignoresSafeArea())
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        buildMenu()
        if visual {
            observer = NotificationCenter.default.addObserver(forName: .readerRendered, object: nil, queue: .main) { [weak self] note in
                guard let webView = note.object as? WKWebView else { return }
                Task { @MainActor in self?.snapshot(webView) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { if !self.snapshotStarted { fputs("Visual check timed out\n", stderr); exit(1) } }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    private func buildMenu() {
        let root = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Topic Reader", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "退出 Topic Reader", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; root.addItem(appItem)
        let editItem = NSMenuItem(); editItem.title = "编辑"; let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; root.addItem(editItem)
        let readItem = NSMenuItem(); readItem.title = "阅读"; let read = NSMenu(title: "阅读")
        read.addItem(withTitle: "下一篇", action: #selector(nextArticle), keyEquivalent: "j")
        read.addItem(withTitle: "上一篇", action: #selector(previousArticle), keyEquivalent: "k")
        read.addItem(withTitle: "打开原文", action: #selector(openOriginal), keyEquivalent: "o")
        readItem.submenu = read; root.addItem(readItem)
        NSApp.mainMenu = root
    }
    @objc private func about() { model.showAbout = true }
    @objc private func nextArticle() { model.next(1) }
    @objc private func previousArticle() { model.next(-1) }
    @objc private func openOriginal() { model.openOriginal() }

    private func snapshot(_ webView: WKWebView) {
        guard !snapshotStarted else { return }; snapshotStarted = true
        if CommandLine.arguments.contains("--lower") {
            // Fixed internal visual-test command, never derived from source content.
            webView.evaluateJavaScript("window.scrollTo(0, 1050)", completionHandler: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let path = ProcessInfo.processInfo.environment["READER_SNAPSHOT_DIR"] ?? "/tmp/topic-reader-visual"
            do { try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true) } catch { exit(1) }
            guard let view = self.window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            webView.takeSnapshot(with: nil) { image, error in
                guard let image else { fputs("WebKit snapshot failed: \(String(describing: error))\n", stderr); exit(1) }
                let composite = NSImage(size: view.bounds.size)
                composite.lockFocus()
                bitmap.draw(in: view.bounds)
                let webFrame = webView.convert(webView.bounds, to: view)
                // NSHostingView is flipped; NSImage drawing uses bottom-left coordinates.
                let dest = NSRect(x: webFrame.minX, y: view.isFlipped ? view.bounds.height - webFrame.maxY : webFrame.minY, width: webFrame.width, height: webFrame.height)
                image.draw(in: dest)
                composite.unlockFocus()
                func save(_ image: NSImage, _ name: String) {
                    if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path).appendingPathComponent(name)) }
                }
                save(composite, "window.png"); save(image, "reader.png")
                print("Visual snapshots saved: \(path)")
                exit(0)
            }
        }
    }
}
