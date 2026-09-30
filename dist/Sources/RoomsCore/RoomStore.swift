import CoreGraphics
import Foundation

/// JSON persistence of the room list. Writes are atomic: a temporary file in the same folder replaces the previous file.
public final class RoomStore {
    public let fileURL: URL

    /// `~/Library/Application Support/Rooms/rooms.json`
    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Rooms", isDirectory: true).appendingPathComponent("rooms.json")
    }

    public init(fileURL: URL = RoomStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Loads the room list. A missing file is an empty list; an unreadable file is kept as `rooms.json.corrupt` and treated as empty.
    public func load() -> [Room] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try RoomStore.makeDecoder().decode([Room].self, from: data)
        } catch {
            let corruptURL = fileURL.deletingLastPathComponent().appendingPathComponent(fileURL.lastPathComponent + ".corrupt")
            try? fm.removeItem(at: corruptURL)
            try? fm.moveItem(at: fileURL, to: corruptURL)
            return []
        }
    }

    /// Writes the room list atomically.
    public func save(_ rooms: [Room]) throws {
        let fm = FileManager.default
        let folder = fileURL.deletingLastPathComponent()
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try RoomStore.makeEncoder().encode(rooms)
        let temporaryURL = folder.appendingPathComponent(".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL, options: [])
        if fm.fileExists(atPath: fileURL.path) {
            _ = try fm.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try fm.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}
