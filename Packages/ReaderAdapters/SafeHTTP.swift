import Foundation
import Darwin

public enum URLPolicy {
    public static func safePublicURL(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil,
              let host = url.host?.lowercased(), !host.isEmpty, url.port == nil || [80, 443].contains(url.port!),
              !host.hasSuffix("."), !host.hasSuffix(".local"), !host.hasSuffix(".localhost"),
              !host.hasSuffix(".internal"), !host.hasSuffix(".home"), host != "localhost", host.contains("."),
              !host.contains(":"), !host.contains("%"), host.range(of: "^[0-9.]+$", options: .regularExpression) == nil
        else { return false }
        return true
    }
    public static func isPublicIPv4(_ value: UInt32) -> Bool {
        let a = value >> 24; let b = (value >> 16) & 255
        return !(a == 0 || a == 10 || a == 127 || a >= 224 || (a == 169 && b == 254) ||
                 (a == 172 && (16...31).contains(b)) || (a == 192 && b == 168) ||
                 (a == 100 && (64...127).contains(b)) || (a == 198 && (18...19).contains(b)) ||
                 (a == 192 && b == 0))
    }
    public static func validateDNS(_ url: URL) throws {
        guard safePublicURL(url), let host = url.host else { throw ReaderError.message("已阻止不安全或本地网络地址。") }
        var hints = addrinfo(); hints.ai_socktype = SOCK_STREAM; hints.ai_family = AF_UNSPEC
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { throw ReaderError.message("无法解析来源主机，请检查网络后重试。") }
        defer { freeaddrinfo(first) }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let entry = cursor {
            let info = entry.pointee
            if info.ai_family == AF_INET {
                let ip = UnsafeRawPointer(info.ai_addr).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr.s_addr.bigEndian
                guard isPublicIPv4(ip) else { throw ReaderError.message("已阻止解析到私网的内容链接。") }
            } else if info.ai_family == AF_INET6 {
                var ip = UnsafeRawPointer(info.ai_addr).assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr
                let bytes = withUnsafeBytes(of: &ip) { Array($0) }
                guard bytes[0] & 0xe0 == 0x20 else { throw ReaderError.message("已阻止非公网 IPv6 地址。") }
            } else { throw ReaderError.message("不支持的网络地址。") }
            cursor = info.ai_next
        }
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

public struct SafeHTTP: Sendable {
    public init() {}
    public func get(_ initial: URL, limit: Int = 6_000_000) async throws -> (Data, URL) {
        let allowedHosts = Set(DemoCatalogHosts.hosts)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 40
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        if let port = NetworkSettings.localProxyPort {
            // Explicit loopback HTTP CONNECT proxy; content URL permissions remain unchanged.
            if NetworkSettings.localProxyKind == "socks5" {
                config.connectionProxyDictionary = ["SOCKSEnable": 1, "SOCKSProxy": "127.0.0.1", "SOCKSPort": port, "HTTPEnable": 0, "HTTPSEnable": 0]
            } else {
                config.connectionProxyDictionary = ["HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": port,
                                                    "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": port, "SOCKSEnable": 0]
            }
        }
        let delegate = NoRedirect()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var url = initial
        for _ in 0..<5 {
            try Task.checkCancellation()
            guard url.scheme == "https", let host = url.host?.lowercased(), allowedHosts.contains(host) else {
                throw ReaderError.message("Demo 仅允许已配置来源的 HTTPS 主机；该链接或跳转未获允许。")
            }
            try URLPolicy.validateDNS(url)
            var request = URLRequest(url: url)
            request.setValue("TopicReaderDemo/0.1", forHTTPHeaderField: "User-Agent")
            request.setValue("application/atom+xml, application/rss+xml, application/xml, text/html;q=0.9, */*;q=0.5", forHTTPHeaderField: "Accept")
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw ReaderError.message("来源没有返回有效 HTTP 响应。") }
            if (300..<400).contains(http.statusCode), let location = http.value(forHTTPHeaderField: "Location"), let next = URL(string: location, relativeTo: url)?.absoluteURL {
                url = next; continue
            }
            guard (200..<300).contains(http.statusCode) else { throw ReaderError.message("来源返回 HTTP \(http.statusCode)。") }
            guard response.expectedContentLength <= limit else { throw ReaderError.message("响应超过 Demo 的 6 MB 限制。") }
            var data = Data(); data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
            for try await byte in bytes {
                if data.count >= limit { throw ReaderError.message("解压后的响应超过大小限制。") }
                data.append(byte)
            }
            return (data, url)
        }
        throw ReaderError.message("来源重定向次数过多。")
    }
}

private enum DemoCatalogHosts {
    static let hosts = ["le.qun.ch", "www.thonking.ai", "thonking.ai", "www.interconnects.ai", "interconnects.ai", "lilianweng.github.io", "spaces.ac.cn", "www.spaces.ac.cn", "vllm.ai", "blog.vllm.ai", "www.vllm.ai"]
}
