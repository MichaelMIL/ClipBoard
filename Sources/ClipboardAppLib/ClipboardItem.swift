import Foundation

/// One snapshot from the general pasteboard: plain text or file references (e.g. Finder copy).
public struct ClipboardItem: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public let created: Date
    public let content: Content

    public enum Content: Equatable, Hashable, Codable {
        case text(String)
        /// Absolute paths as copied from the pasteboard (persistence / restore).
        case files([String])
    }

    public init(id: UUID = UUID(), created: Date = Date(), content: Content) {
        self.id = id
        self.created = created
        self.content = content
    }

    public init(text: String) {
        self.init(content: .text(text))
    }

    public init(filePaths: [String]) {
        self.init(content: .files(filePaths))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case created
        case text
        case filePaths
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        created = try c.decode(Date.self, forKey: .created)
        if let paths = try c.decodeIfPresent([String].self, forKey: .filePaths), !paths.isEmpty {
            content = .files(paths)
        } else if let t = try c.decodeIfPresent(String.self, forKey: .text) {
            content = .text(t)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: c.codingPath, debugDescription: "Missing text or filePaths")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(created, forKey: .created)
        switch content {
        case .text(let string):
            try c.encode(string, forKey: .text)
        case .files(let paths):
            try c.encode(paths, forKey: .filePaths)
        }
    }
}

extension ClipboardItem.Content {
    /// Short string for notifications and overlay (truncated).
    public func previewString(maxLength: Int = 400) -> String {
        switch self {
        case .text(let s):
            if s.count <= maxLength { return s }
            return String(s.prefix(maxLength)) + "…"
        case .files(let paths):
            let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }
            if names.count == 1 { return names[0] }
            let head = names.prefix(3).joined(separator: ", ")
            let extra = names.count - 3
            if extra > 0 { return head + " … +\(extra) more" }
            return head
        }
    }
}
