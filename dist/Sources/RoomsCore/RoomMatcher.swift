import CoreGraphics
import Foundation

/// Name matching and ordering of rooms for the palette.
public enum RoomMatcher {
    /// A name matches when every typed character appears in the name in the typed order, not necessarily adjacent, ignoring case.
    public static func matches(query: String, name: String) -> Bool {
        let q = Array(query.lowercased())
        guard !q.isEmpty else { return true }
        var index = 0
        for character in name.lowercased() {
            if character == q[index] {
                index += 1
                if index == q.count { return true }
            }
        }
        return false
    }

    /// 0 when the name starts with the query, 1 when the query starts a word of the name, 2 otherwise.
    public static func rank(query: String, name: String) -> Int {
        let q = query.lowercased()
        let n = name.lowercased()
        guard !q.isEmpty else { return 2 }
        if n.hasPrefix(q) { return 0 }
        let words = n.split(whereSeparator: { $0.isWhitespace })
        if words.contains(where: { $0.hasPrefix(q) }) { return 1 }
        return 2
    }

    /// Most recently shown first, then rooms never shown in creation order.
    public static func defaultOrder(_ rooms: [Room]) -> [Room] {
        let shown = rooms.filter { $0.lastShown != nil }.sorted { a, b in
            if a.lastShown! != b.lastShown! { return a.lastShown! > b.lastShown! }
            return a.createdAt < b.createdAt
        }
        let neverShown = rooms.filter { $0.lastShown == nil }.sorted { $0.createdAt < $1.createdAt }
        return shown + neverShown
    }

    /// Filters rooms (given in default order) by the query and orders matches by rank, keeping the incoming order for ties.
    public static func filter(_ orderedRooms: [Room], query: String) -> [Room] {
        guard !query.isEmpty else { return orderedRooms }
        let matching = orderedRooms.filter { matches(query: query, name: $0.name) }
        return matching.enumerated().sorted { a, b in
            let ra = rank(query: query, name: a.element.name)
            let rb = rank(query: query, name: b.element.name)
            if ra != rb { return ra < rb }
            return a.offset < b.offset
        }.map { $0.element }
    }

    /// True when a room's name equals the text, ignoring case.
    public static func hasRoom(named text: String, in rooms: [Room], excluding excludedID: UUID? = nil) -> Bool {
        let t = text.lowercased()
        return rooms.contains { $0.id != excludedID && $0.name.lowercased() == t }
    }
}
