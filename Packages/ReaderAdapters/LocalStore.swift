import Foundation
import ReaderDomain
import ReaderApplication

public struct LocalStore: LibraryStoring {
    public let directory: URL
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TopicReader", isDirectory: true)
    }
    public func load() throws -> Library? {
        let file = directory.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: file))
        guard library.version == 1 else { throw ReaderError.message("本地数据版本暂不支持，请保留缓存并升级应用。") }
        return library
    }
    public func save(_ library: Library) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent("library.json")
        try JSONEncoder().encode(library).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    public func clear() throws {
        let file = directory.appendingPathComponent("library.json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}

public enum ReaderError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}
