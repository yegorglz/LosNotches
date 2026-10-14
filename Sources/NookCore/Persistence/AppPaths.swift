import Foundation

public enum AppPaths {
    /// `<base or ~/Library/Application Support>/LosNotches`, created if missing.
    public static func supportDirectory(base: URL? = nil) -> URL {
        let root = base ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = root.appendingPathComponent("LosNotches", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
