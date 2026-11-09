import Foundation

public enum NetworkSettings {
    private static let defaults = UserDefaults.standard
    public static var localProxyKind: String { defaults.string(forKey: "localProxyKind") ?? "http" }
    public static var localProxyPort: Int? {
        let port = defaults.integer(forKey: "localHTTPProxyPort")
        return (1...65535).contains(port) ? port : nil
    }
    public static func setLocalProxyPort(_ value: String, kind: String = "http") throws {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { defaults.removeObject(forKey: "localHTTPProxyPort"); return }
        guard let port = Int(text), (1...65535).contains(port) else { throw ReaderError.message("请输入 1–65535 的端口，或留空使用系统网络设置。") }
        guard ["http", "socks5"].contains(kind) else { throw ReaderError.message("不支持的代理协议。") }
        defaults.set(kind, forKey: "localProxyKind")
        defaults.set(port, forKey: "localHTTPProxyPort")
    }
    public static func importEnvironmentProxy() throws {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["https_proxy"] ?? env["HTTPS_PROXY"], let url = URL(string: raw),
              ["http", "socks5", "socks5h"].contains(url.scheme ?? ""), ["127.0.0.1", "localhost"].contains(url.host ?? ""),
              url.user == nil, url.password == nil, let port = url.port else {
            throw ReaderError.message("没有可沿用的无认证本机 HTTP / SOCKS5 代理。")
        }
        try setLocalProxyPort(String(port), kind: url.scheme == "http" ? "http" : "socks5")
    }
}
