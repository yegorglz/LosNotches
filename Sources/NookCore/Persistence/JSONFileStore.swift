import Foundation

/// Codable value persisted as one JSON file. Missing → default; corrupt → backed up, then default.
public struct JSONFileStore<Value: Codable> {
    public let url: URL
    private let defaultValue: () -> Value

    public init(url: URL, defaultValue: @escaping () -> Value) {
        self.url = url
        self.defaultValue = defaultValue
    }

    public func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return defaultValue() }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: backup)
            return defaultValue()
        }
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
