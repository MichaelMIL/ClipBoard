import AppKit
import Combine
import Foundation

/// Polls `NSPasteboard.general` and maintains bounded history (text and file copies).
public final class ClipboardHistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []
    /// Saved independently of history size limits; persisted to `favorites.json`.
    @Published public private(set) var favorites: [ClipboardItem] = []

    /// Preferences (history limits, notifications, etc.).
    public let appSettings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?

    private var lastChangeCount: Int
    private var lastFingerprint: String?
    private var pollTimer: Timer?

    private let pollInterval: TimeInterval = 0.35

    private static var supportDirectoryURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ClipboardApp", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var persistenceURL: URL {
        supportDirectoryURL.appendingPathComponent("history.json", isDirectory: false)
    }

    static var favoritesPersistenceURL: URL {
        supportDirectoryURL.appendingPathComponent("favorites.json", isDirectory: false)
    }

    public init(settings: AppSettings) {
        appSettings = settings
        lastChangeCount = NSPasteboard.general.changeCount
        loadFromDisk()
        loadFavoritesFromDisk()

        appSettings.$maxHistoryItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] max in
                self?.trimToMax(max)
            }
            .store(in: &cancellables)
    }

    public func start() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
        pollPasteboard()
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        saveWorkItem?.cancel()
        saveToDisk()
        saveFavoritesToDisk()
    }

    private var maxItems: Int {
        AppSettings.clampHistoryCount(appSettings.maxHistoryItems)
    }

    private func trimToMax(_ raw: Int) {
        let m = AppSettings.clampHistoryCount(raw)
        guard items.count > m else { return }
        items = Array(items.prefix(m))
        scheduleSave()
    }

    private func pollPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let fileURLs = Self.fileURLs(from: pb), !fileURLs.isEmpty {
            let paths = fileURLs.map { $0.standardizedFileURL.path }
            let fp = Self.fingerprintFiles(paths)
            if fp == lastFingerprint { return }
            lastFingerprint = fp
            let content = ClipboardItem.Content.files(paths)
            if matchesFirst(content) { return }
            items.insert(ClipboardItem(content: content), at: 0)
            ClipboardCopyNotifier.notifyIfNeeded(content: content, settings: appSettings)
            trimAndSave()
            return
        }

        guard let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return }

        let fp = Self.fingerprintText(text)
        if fp == lastFingerprint { return }
        lastFingerprint = fp

        let content = ClipboardItem.Content.text(text)
        if matchesFirst(content) { return }

        items.insert(ClipboardItem(content: content), at: 0)
        ClipboardCopyNotifier.notifyIfNeeded(content: content, settings: appSettings)
        trimAndSave()
    }

    private func matchesFirst(_ content: ClipboardItem.Content) -> Bool {
        guard let first = items.first else { return false }
        return first.content == content
    }

    private func trimAndSave() {
        let limit = maxItems
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        scheduleSave()
    }

    private static func fingerprintText(_ s: String) -> String {
        "t:\(s.count)::\(s.hashValue)"
    }

    private static func fingerprintFiles(_ paths: [String]) -> String {
        let sorted = paths.sorted().joined(separator: "\u{1e}")
        return "f:\(sorted.hashValue)::\(sorted.count)"
    }

    private static func fileURLs(from pb: NSPasteboard) -> [URL]? {
        guard let objects = pb.readObjects(forClasses: [NSURL.self], options: nil), !objects.isEmpty else {
            return nil
        }
        var urls: [URL] = []
        for obj in objects {
            let url: URL?
            if let u = obj as? URL {
                url = u
            } else if let ns = obj as? NSURL {
                url = ns as URL
            } else {
                url = nil
            }
            guard let url, url.isFileURL else { continue }
            urls.append(url)
        }
        return urls.isEmpty ? nil : urls
    }

    /// Restores the chosen entry onto the general pasteboard for the next **⌘V** (text or files in Finder-compatible form).
    public func copyContentToPasteboard(_ content: ClipboardItem.Content) {
        let pb = NSPasteboard.general
        switch content {
        case .text(let text):
            pb.clearContents()
            pb.setString(text, forType: .string)
            if let data = text.data(using: .utf8) {
                pb.setData(data, forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
            }
            lastFingerprint = Self.fingerprintText(text)
            lastChangeCount = pb.changeCount
        case .files(let paths):
            let fm = FileManager.default
            let urls = paths.compactMap { path -> URL? in
                guard fm.fileExists(atPath: path) else { return nil }
                return URL(fileURLWithPath: path)
            }
            guard !urls.isEmpty else { return }
            pb.clearContents()
            pb.writeObjects(urls.map { $0 as NSURL })
            let pathStrings = urls.map(\.path)
            pb.setPropertyList(pathStrings, forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
            lastFingerprint = Self.fingerprintFiles(paths)
            lastChangeCount = pb.changeCount
        }
    }

    /// Restores a full history row (same as ``copyContentToPasteboard(_:)`` with `item.content`).
    public func copyItemToPasteboard(_ item: ClipboardItem) {
        copyContentToPasteboard(item.content)
    }

    public func isFavorite(id: UUID) -> Bool {
        favorites.contains { $0.id == id }
    }

    /// Reads the general pasteboard as ``ClipboardItem/Content-swift.enum`` (files if present, otherwise trimmed plain text).
    public static func contentFromGeneralPasteboard() -> ClipboardItem.Content? {
        let pb = NSPasteboard.general
        if let fileURLs = fileURLs(from: pb), !fileURLs.isEmpty {
            return .files(fileURLs.map { $0.standardizedFileURL.path })
        }
        guard let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        return .text(text)
    }

    /// Inserts a new favorite from captured content, or returns an existing favorite with the same content.
    @discardableResult
    public func addFavoriteFromCapturedContent(_ content: ClipboardItem.Content) -> ClipboardItem {
        if let existing = favorites.first(where: { $0.content == content }) {
            return existing
        }
        let item = ClipboardItem(content: content)
        favorites.insert(item, at: 0)
        saveFavoritesToDisk()
        return item
    }

    /// Stars match history rows by id. Tapping again removes from favorites.
    public func toggleFavorite(_ item: ClipboardItem) {
        if let idx = favorites.firstIndex(where: { $0.id == item.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(item, at: 0)
        }
        saveFavoritesToDisk()
    }

    private func loadFavoritesFromDisk() {
        let url = Self.favoritesPersistenceURL
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([ClipboardItem].self, from: data) else { return }
        favorites = decoded
    }

    private func saveFavoritesToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(favorites) else { return }
        try? data.write(to: Self.favoritesPersistenceURL, options: [.atomic])
    }

    private func loadFromDisk() {
        let url = Self.persistenceURL
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([ClipboardItem].self, from: data) else { return }
        items = Array(decoded.prefix(maxItems))
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: Self.persistenceURL, options: [.atomic])
    }
}
