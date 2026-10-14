import Foundation

public struct Note: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var rtf: Data
    public var plainText: String
    public var isCodeMode: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public var title: String {
        let line = plainText.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line.map { String($0.prefix(40)) } ?? "New Note"
    }
}

public struct NoteBook: Codable, Equatable, Sendable {
    public var notes: [Note] = []
    public init() {}

    @discardableResult
    public mutating func create(now: Date) -> Note {
        let n = Note(id: UUID(), rtf: Data(), plainText: "", isCodeMode: false, createdAt: now, updatedAt: now)
        notes.append(n)
        return n
    }

    public mutating func update(id: UUID, rtf: Data, plainText: String, now: Date) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].rtf = rtf
        notes[i].plainText = plainText
        notes[i].updatedAt = now
    }

    public mutating func delete(id: UUID) { notes.removeAll { $0.id == id } }

    public mutating func toggleCodeMode(id: UUID) {
        if let i = notes.firstIndex(where: { $0.id == id }) { notes[i].isCodeMode.toggle() }
    }

    public func sorted() -> [Note] { notes.sorted { $0.updatedAt > $1.updatedAt } }
}
