import ClipboardAppLib
import SwiftUI

private struct RowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private enum OverlayPanelTab: String, CaseIterable, Identifiable {
    case history
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "History"
        case .favorites: return "Favorites"
        }
    }
}

struct OverlayContentView: View {
    @ObservedObject var store: ClipboardHistoryStore
    var onSelect: (ClipboardItem.Content) -> Void
    var onDismiss: () -> Void

    @State private var selectedTab: OverlayPanelTab = .history
    @State private var selection: UUID?
    @State private var searchText = ""
    /// Visible rows in scroll viewport, top-first: slot 1 … 9 then 0 for the 10th.
    @State private var slotByItemId: [UUID: Int] = [:]

    private enum OverlayKeyboardFocus: Hashable {
        case search
        case list
    }

    @FocusState private var overlayFocus: OverlayKeyboardFocus?

    private var filteredActiveItems: [ClipboardItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: [ClipboardItem] = {
            switch selectedTab {
            case .history: return store.items
            case .favorites: return store.favorites
            }
        }()
        guard !q.isEmpty else { return source }
        let needle = q.lowercased()
        return source.filter { Self.itemMatchesSearch($0, needle: needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Clipboard")
                        .font(.headline)
                    Spacer()
                    Text("↑↓ select · ↵ copy · 1–9 / 0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Section", selection: $selectedTab) {
                    ForEach(OverlayPanelTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Clipboard section")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(searchFieldPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($overlayFocus, equals: .search)
                    .accessibilityLabel(searchAccessibilityLabel)
                    .onKeyPress(.escape) {
                        overlayFocus = .list
                        return .handled
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            Divider()

            Group {
                if selectedTab == .history {
                    if store.items.isEmpty {
                        Text("No copies yet — copy text or files in Finder (⌘C).")
                            .foregroundStyle(.secondary)
                            .padding(16)
                    } else if filteredActiveItems.isEmpty {
                        Text("No items match your search.")
                            .foregroundStyle(.secondary)
                            .padding(16)
                    } else {
                        itemScrollList
                    }
                } else {
                    if store.favorites.isEmpty {
                        Text("No favorites yet — open History and tap the star on any row.")
                            .foregroundStyle(.secondary)
                            .padding(16)
                    } else if filteredActiveItems.isEmpty {
                        Text("No favorites match your search.")
                            .foregroundStyle(.secondary)
                            .padding(16)
                    } else {
                        itemScrollList
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focused($overlayFocus, equals: .list)
            .focusable()
            .onKeyPress(.return) {
                if let id = selection, let item = filteredActiveItems.first(where: { $0.id == id }) {
                    onSelect(item.content)
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                moveSelection(-1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(1)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "0123456789")) { press in
                guard let c = press.characters.first,
                      let slot = slotFromDigit(c),
                      let id = itemId(forVisibleSlot: slot),
                      let item = filteredActiveItems.first(where: { $0.id == id })
                else {
                    return .ignored
                }
                onSelect(item.content)
                return .handled
            }
        }
        .frame(minWidth: 380, minHeight: 280)
        .onAppear {
            selection = filteredActiveItems.first?.id
            DispatchQueue.main.async {
                overlayFocus = .list
            }
        }
        .onChange(of: store.items.map(\.id)) { _, _ in
            reconcileSelectionWithFilteredList()
        }
        .onChange(of: store.favorites.map(\.id)) { _, _ in
            reconcileSelectionWithFilteredList()
        }
        .onChange(of: searchText) { _, _ in
            reconcileSelectionWithFilteredList()
        }
        .onChange(of: selectedTab) { _, _ in
            reconcileSelectionWithFilteredList()
            DispatchQueue.main.async {
                overlayFocus = .list
            }
        }
        .onExitCommand {
            onDismiss()
        }
        .background(.ultraThinMaterial)
    }

    private var searchFieldPlaceholder: String {
        selectedTab == .history ? "Search history…" : "Search favorites…"
    }

    private var searchAccessibilityLabel: String {
        selectedTab == .history ? "Search clipboard history" : "Search favorites"
    }

    private var itemScrollList: some View {
        GeometryReader { viewportGeo in
            let viewportGlobal = viewportGeo.frame(in: .global)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredActiveItems.enumerated()), id: \.element.id) { index, item in
                            overlayRow(item: item)
                                .id(item.id)
                                .background(
                                    GeometryReader { rowGeo in
                                        Color.clear.preference(
                                            key: RowFramePreferenceKey.self,
                                            value: [item.id: rowGeo.frame(in: .global)]
                                        )
                                    }
                                )
                            if index < filteredActiveItems.count - 1 {
                                Divider()
                                    .padding(.leading, slotColumnWidth + 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onPreferenceChange(RowFramePreferenceKey.self) { frames in
                    updateSlots(frames: frames, viewportGlobal: viewportGlobal)
                }
                .onChange(of: selection) { _, newId in
                    guard let newId else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    private static func itemMatchesSearch(_ item: ClipboardItem, needle: String) -> Bool {
        switch item.content {
        case .text(let s):
            return s.lowercased().contains(needle)
        case .files(let paths):
            return paths.contains { path in
                path.lowercased().contains(needle)
                    || URL(fileURLWithPath: path).lastPathComponent.lowercased().contains(needle)
            }
        }
    }

    private func reconcileSelectionWithFilteredList() {
        let list = filteredActiveItems
        guard !list.isEmpty else {
            selection = nil
            return
        }
        if let sel = selection, list.contains(where: { $0.id == sel }) {
            return
        }
        selection = list.first?.id
    }

    private var slotColumnWidth: CGFloat { 18 }

    @ViewBuilder
    private func overlayRow(item: ClipboardItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let slot = slotByItemId[item.id] {
                Text(slotBadge(slot))
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: slotColumnWidth, alignment: .center)
                    .accessibilityLabel("Shortcut \(slotBadge(slot))")
            } else {
                Color.clear
                    .frame(width: slotColumnWidth)
            }

            Button {
                onSelect(item.content)
            } label: {
                rowLabel(for: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: store.isFavorite(id: item.id) ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(store.isFavorite(id: item.id) ? Color.yellow : Color.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(store.isFavorite(id: item.id) ? "Remove from favorites" : "Add to favorites")
            .accessibilityLabel(store.isFavorite(id: item.id) ? "Remove from favorites" : "Add to favorites")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selection == item.id ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    private func slotBadge(_ slot: Int) -> String {
        slot == 10 ? "0" : String(slot)
    }

    private func slotFromDigit(_ c: Character) -> Int? {
        switch c {
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        case "7": return 7
        case "8": return 8
        case "9": return 9
        case "0": return 10
        default: return nil
        }
    }

    private func itemId(forVisibleSlot slot: Int) -> UUID? {
        slotByItemId.first(where: { $0.value == slot })?.key
    }

    private func updateSlots(frames: [UUID: CGRect], viewportGlobal: CGRect) {
        let visible = frames.compactMap { id, rect -> (UUID, CGFloat)? in
            guard rect.intersects(viewportGlobal) else { return nil }
            return (id, rect.midY)
        }
        .sorted { $0.1 < $1.1 }
        .prefix(10)

        var next: [UUID: Int] = [:]
        for (idx, pair) in visible.enumerated() {
            next[pair.0] = idx + 1
        }
        if next != slotByItemId {
            slotByItemId = next
        }
    }

    @ViewBuilder
    private func rowLabel(for item: ClipboardItem) -> some View {
        switch item.content {
        case .text(let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(previewText(text))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        case .files(let paths):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: paths.count == 1 ? "doc" : "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(previewFiles(paths))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func moveSelection(_ delta: Int) {
        let list = filteredActiveItems
        guard !list.isEmpty else { return }
        guard let currentId = selection, let idx = list.firstIndex(where: { $0.id == currentId }) else {
            selection = list.first?.id
            return
        }
        let next = (idx + delta).clamped(to: 0...(list.count - 1))
        selection = list[next].id
    }

    private func previewText(_ s: String) -> String {
        let maxLen = 400
        if s.count <= maxLen { return s }
        return String(s.prefix(maxLen)) + "…"
    }

    private func previewFiles(_ paths: [String]) -> String {
        let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }
        if names.count == 1 {
            return names[0]
        }
        let head = names.prefix(3).joined(separator: ", ")
        let extra = names.count - 3
        if extra > 0 {
            return head + " … +\(extra) more"
        }
        return head
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
