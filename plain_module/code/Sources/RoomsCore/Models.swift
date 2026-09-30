import CoreGraphics
import Foundation

/// Identity of a window of a running application: bundle identifier, process identifier, and CGWindowID.
public struct WindowIdentity: Codable, Hashable {
    public var bundleIdentifier: String
    public var processIdentifier: Int32
    public var windowID: UInt32

    public init(bundleIdentifier: String, processIdentifier: Int32, windowID: UInt32) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.windowID = windowID
    }
}

/// A window of a running application on the Mac.
public struct AppWindow: Codable, Hashable {
    public var identity: WindowIdentity
    public var applicationName: String
    public var title: String
    /// Position and size on screen, in AppKit screen coordinates (points, origin bottom-left).
    public var frame: CGRect
    /// The smallest width and height the application allows for this window, measured when the room is saved.
    public var minimumSize: CGSize

    public init(identity: WindowIdentity, applicationName: String, title: String, frame: CGRect, minimumSize: CGSize = .zero) {
        self.identity = identity
        self.applicationName = applicationName
        self.title = title
        self.frame = frame
        self.minimumSize = minimumSize
    }

    public var bundleIdentifier: String { identity.bundleIdentifier }
    public var processIdentifier: Int32 { identity.processIdentifier }
}

/// A named arrangement of the windows of a room on one screen.
public enum Layout: String, Codable, CaseIterable {
    case auto
    case focus
    case columns
    case grid
    case stack

    /// `myLayout`, stored by an earlier version, loads as Auto.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if raw == "myLayout" {
            self = .auto
        } else if let layout = Layout(rawValue: raw) {
            self = layout
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown layout \(raw)"))
        }
    }

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .focus: return "Focus"
        case .columns: return "Columns"
        case .grid: return "Grid"
        case .stack: return "Stack"
        }
    }

    /// The order used when cycling layouts with ⇥ / ⇧⇥.
    public static let cycleOrder: [Layout] = [.auto, .focus, .columns, .grid, .stack]

    /// The tidy layouts Auto tries, in order.
    public static let tidyLayouts: [Layout] = [.focus, .columns, .grid]
}

/// A named set of windows with the layout they are shown in.
public struct Room: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// Ordered list of windows; position 1 (index 0) is the main window.
    public var windows: [AppWindow]
    public var layout: Layout
    /// A number 1 to 9, unique among rooms.
    public var directKey: Int?
    public var createdAt: Date
    /// The time the room was last shown.
    public var lastShown: Date?

    public init(id: UUID = UUID(), name: String, windows: [AppWindow], layout: Layout = .auto, directKey: Int? = nil, createdAt: Date = Date(), lastShown: Date? = nil) {
        self.id = id
        self.name = name
        self.windows = windows
        self.layout = layout
        self.directKey = directKey
        self.createdAt = createdAt
        self.lastShown = lastShown
    }
}
