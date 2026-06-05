import Combine
import Foundation

private struct ClipboardDatabase: Codable {
    var items: [ClipboardItem]
}

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = [] {
        didSet {
            itemsVersion += 1
            cachedSearch = nil
        }
    }
    @Published public private(set) var preferences: AppPreferences

    public let storageDirectory: URL
    public let historyURL: URL
    public let preferencesURL: URL
    public var onImagePayloadsRemoved: (([StoredImagePayload]) -> Void)?

    private let preferencesEncoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let historyQueue = DispatchQueue(label: "com.isaiahjohnson.Clippy.history-writer", qos: .utility)
    private let historySaveDebounce: TimeInterval
    private var pendingHistorySave: DispatchWorkItem?
    private var itemsVersion = 0
    private var cachedSearch: (query: String, version: Int, results: [ClipboardItem])?

    public init(
        storageDirectory: URL? = nil,
        fileManager: FileManager = .default,
        historySaveDebounce: TimeInterval = 0.25
    ) {
        self.fileManager = fileManager
        self.historySaveDebounce = historySaveDebounce

        let baseDirectory = storageDirectory ?? Self.defaultStorageDirectory(fileManager: fileManager)
        self.storageDirectory = baseDirectory
        self.historyURL = baseDirectory.appendingPathComponent("history.json")
        self.preferencesURL = baseDirectory.appendingPathComponent("preferences.json")

        let preferencesEncoder = JSONEncoder()
        preferencesEncoder.dateEncodingStrategy = .iso8601
        preferencesEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.preferencesEncoder = preferencesEncoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.preferences = Self.loadPreferences(
            from: preferencesURL,
            decoder: decoder
        )

        createStorageIfNeeded()
        loadHistory()
        _ = enforceHistoryLimit()
    }

    @discardableResult
    public func add(
        payload: ClipboardPayload,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        date: Date = Date()
    ) -> ClipboardItem? {
        let normalized = normalizedPayload(payload)
        guard let normalized else {
            return nil
        }

        let hash = ClipboardHasher.hash(payload: normalized)
        if let existingIndex = items.firstIndex(where: { $0.contentHash == hash }) {
            var existing = items.remove(at: existingIndex)
            existing.createdAt = date
            existing.sourceAppBundleID = sourceAppBundleID ?? existing.sourceAppBundleID
            existing.sourceAppName = sourceAppName ?? existing.sourceAppName
            items.insert(existing, at: 0)
            scheduleHistorySave()
            return existing
        }

        let item = makeItem(
            payload: normalized,
            hash: hash,
            sourceAppBundleID: sourceAppBundleID,
            sourceAppName: sourceAppName,
            date: date
        )

        items.insert(item, at: 0)
        _ = enforceHistoryLimit()
        scheduleHistorySave()
        return item
    }

    public func markUsed(id: UUID, date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].lastUsedAt = date
        scheduleHistorySave()
    }

    public func setPinned(_ isPinned: Bool, id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].isPinned = isPinned
        _ = enforceHistoryLimit()
        scheduleHistorySave()
    }

    public func delete(id: UUID) {
        let removed = items.filter { $0.id == id }
        items.removeAll { $0.id == id }
        notifyRemovedImagePayloads(from: removed)
        scheduleHistorySave()
    }

    public func clearHistory(keepingPinned: Bool = false) {
        let removed: [ClipboardItem]
        if keepingPinned {
            removed = items.filter { !$0.isPinned }
            items.removeAll { !$0.isPinned }
        } else {
            removed = items
            items.removeAll()
        }
        notifyRemovedImagePayloads(from: removed)
        scheduleHistorySave()
    }

    public func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        let previousLimit = preferences.historyLimit
        var next = preferences
        update(&next)
        next.historyLimit = max(10, min(next.historyLimit, 1_000))
        preferences = next
        let didShrinkLimit = preferences.historyLimit < previousLimit
        let didChangeItems = didShrinkLimit ? enforceHistoryLimit() : false
        savePreferences()
        if didChangeItems {
            scheduleHistorySave()
        }
    }

    public func search(_ query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cachedSearch,
           cachedSearch.query == trimmed,
           cachedSearch.version == itemsVersion {
            return cachedSearch.results
        }

        let ranked = items.enumerated().compactMap { index, item -> (ClipboardItem, Int, Date, Int, Date)? in
            let result = FuzzyMatcher.match(query: trimmed, candidate: item.searchableText)
            guard result.matched else {
                return nil
            }
            let pinBonus = item.isPinned ? 10_000 : 0
            return (
                item,
                result.score + pinBonus,
                item.lastUsedAt ?? .distantPast,
                index,
                item.createdAt
            )
        }

        let results = ranked
            .sorted {
                if $0.1 == $1.1 {
                    if $0.2 != $1.2 {
                        return $0.2 > $1.2
                    }
                    if $0.3 != $1.3 {
                        return $0.3 < $1.3
                    }
                    return $0.4 > $1.4
                }
                return $0.1 > $1.1
            }
            .map(\.0)
        cachedSearch = (trimmed, itemsVersion, results)
        return results
    }

    public func mostRecentUnpinnedAwareItem() -> ClipboardItem? {
        items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned
            }
            return $0.createdAt > $1.createdAt
        }
        .first
    }

    private func createStorageIfNeeded() {
        do {
            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            assertionFailure("Failed to create storage directory: \(error)")
        }
    }

    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyURL.path) else {
            items = []
            return
        }

        do {
            let data = try Data(contentsOf: historyURL)
            let database = try decoder.decode(ClipboardDatabase.self, from: data)
            items = database.items.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }
                return lhs.createdAt > rhs.createdAt
            }
        } catch {
            items = []
        }
    }

    public func flushPendingHistorySaves() {
        guard let pendingHistorySave else {
            return
        }
        pendingHistorySave.cancel()
        self.pendingHistorySave = nil
        let snapshot = items
        let url = historyURL
        historyQueue.sync {
            Self.writeHistory(snapshot, to: url)
        }
    }

    private func scheduleHistorySave() {
        createStorageIfNeeded()
        pendingHistorySave?.cancel()
        let snapshot = items
        let url = historyURL
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem {
            guard !workItem.isCancelled else {
                return
            }
            Self.writeHistory(snapshot, to: url)
        }
        pendingHistorySave = workItem
        historyQueue.asyncAfter(deadline: .now() + historySaveDebounce, execute: workItem)
    }

    private static func writeHistory(_ items: [ClipboardItem], to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(ClipboardDatabase(items: items))
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            FileHandle.standardError.write(Data("Failed to save clipboard history: \(error)\n".utf8))
            #endif
        }
    }

    private func savePreferences() {
        createStorageIfNeeded()
        do {
            let data = try preferencesEncoder.encode(preferences)
            try data.write(to: preferencesURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save preferences: \(error)")
        }
    }

    private static func loadPreferences(from url: URL, decoder: JSONDecoder) -> AppPreferences {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppPreferences()
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppPreferences.self, from: data)
        } catch {
            return AppPreferences()
        }
    }

    @discardableResult
    private func enforceHistoryLimit() -> Bool {
        let limit = max(10, preferences.historyLimit)
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > limit else {
            return false
        }

        let keptUnpinnedIDs = Set(unpinned
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map(\.id))

        var removed: [ClipboardItem] = []
        items.removeAll { item in
            let shouldRemove = !item.isPinned && !keptUnpinnedIDs.contains(item.id)
            if shouldRemove {
                removed.append(item)
            }
            return shouldRemove
        }
        notifyRemovedImagePayloads(from: removed)
        return !removed.isEmpty
    }

    private func notifyRemovedImagePayloads(from removedItems: [ClipboardItem]) {
        guard !removedItems.isEmpty else {
            return
        }

        let remainingImageDigests = Set(items.compactMap { item -> String? in
            if case .image(let payload) = item.payload {
                return payload.contentDigest
            }
            return nil
        })
        var seenDigests: Set<String> = []
        let payloads = removedItems.compactMap { item -> StoredImagePayload? in
            guard case .image(let payload) = item.payload,
                  !remainingImageDigests.contains(payload.contentDigest),
                  seenDigests.insert(payload.contentDigest).inserted else {
                return nil
            }
            return payload
        }

        if !payloads.isEmpty {
            onImagePayloadsRemoved?(payloads)
        }
    }

    private func normalizedPayload(_ payload: ClipboardPayload) -> ClipboardPayload? {
        switch payload {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
                return .url(url, displayTitle: nil)
            }
            return .text(text)
        case .url(let url, let displayTitle):
            guard url.scheme != nil else {
                return nil
            }
            return .url(url, displayTitle: displayTitle)
        case .image:
            return payload
        }
    }

    private func makeItem(
        payload: ClipboardPayload,
        hash: String,
        sourceAppBundleID: String?,
        sourceAppName: String?,
        date: Date
    ) -> ClipboardItem {
        switch payload {
        case .text(let text):
            let preview = clipped(text, limit: 400)
            return ClipboardItem(
                kind: .text,
                title: title(forText: text),
                previewText: preview,
                createdAt: date,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                contentHash: hash,
                payload: payload
            )
        case .url(let url, let displayTitle):
            return ClipboardItem(
                kind: .url,
                title: displayTitle ?? url.host ?? url.absoluteString,
                previewText: url.absoluteString,
                createdAt: date,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                contentHash: hash,
                payload: payload
            )
        case .image(let image):
            let size = "\(Int(image.pixelSize.width)) x \(Int(image.pixelSize.height))"
            return ClipboardItem(
                kind: .image,
                title: "Image",
                previewText: "\(size) • \(ByteCountFormatter.string(fromByteCount: Int64(image.byteCount), countStyle: .file))",
                createdAt: date,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName,
                contentHash: hash,
                payload: payload
            )
        }
    }

    private func title(forText text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? text
        return clipped(firstLine, limit: 72)
    }

    private func clipped(_ text: String, limit: Int) -> String {
        if text.count <= limit {
            return text
        }
        return String(text.prefix(limit - 1)) + "…"
    }

    private static func defaultStorageDirectory(fileManager: FileManager) -> URL {
        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return appSupport.appendingPathComponent("Clippy", isDirectory: true)
        }

        return fileManager.temporaryDirectory.appendingPathComponent("Clippy", isDirectory: true)
    }
}
