import Foundation

/// Splits a byte stream into newline-terminated UTF-8 lines; partial lines wait for the next chunk.
public struct LineBuffer {
    private var buffer = Data()
    public init() {}

    public mutating func append(_ chunk: Data) -> [String] {
        buffer.append(chunk)
        var lines: [String] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            lines.append(String(decoding: line, as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...nl)
        }
        return lines
    }
}
