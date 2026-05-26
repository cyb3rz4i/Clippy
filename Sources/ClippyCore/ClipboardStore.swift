import Combine
import Foundation

private struct ClipboardDatabase: Codable {
    var items: [ClipboardItem]
}

public final class ClipboardStore: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []
    @Published public private(set) var preferences: AppPreferences

    public let storageDirectory: URL
    public let historyURL: URL
    public let preferencesURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(
        storageDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        let baseDirectory = storageDirectory ?? Self.defaultStorageDirectory(fileManager: fileManager)
        self.storageDirectory = baseDirectory
        self.historyURL = baseDirectory.appendingPathComponent("history.json")
        self.preferencesURL = baseDirectory.appendingPathComponent("preferences.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.preferences = Self.loadPreferences(
            from: preferencesURL,
            decoder: decoder
        )

        createStorageIfNeeded()
        loadHistory()
        enforceHistoryLimit()
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
            saveHistory()
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
        enforceHistoryLimit()
        saveHistory()
        return item
    }

    public func markUsed(id: UUID, date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].lastUsedAt = date
        saveHistory()
    }

    public func setPinned(_ isPinned: Bool, id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].isPinned = isPinned
        enforceHistoryLimit()
        saveHistory()
    }

    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        saveHistory()
    }

    public func clearHistory(keepingPinned: Bool = false) {
        if keepingPinned {
            items.removeAll { !$0.isPinned }
        } else {
            items.removeAll()
        }
        saveHistory()
    }

    public func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        var next = preferences
        update(&next)
        next.historyLimit = max(10, min(next.historyLimit, 1_000))
        preferences = next
        enforceHistoryLimit()
        savePreferences()
        saveHistory()
    }

    public func search(_ query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ranked = items.compactMap { item -> (ClipboardItem, Int)? in
            let result = FuzzyMatcher.match(query: trimmed, candidate: item.searchableText)
            guard result.matched else {
                return nil
            }
            let pinBonus = item.isPinned ? 10_000 : 0
            let recencyBonus = max(0, 1_000 - items.firstIndex(of: item).defaulting(to: 1_000))
            return (item, result.score + pinBonus + recencyBonus)
        }

        return ranked
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.createdAt > $1.0.createdAt
                }
                return $0.1 > $1.1
            }
            .map(\.0)
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

    private func saveHistory() {
        createStorageIfNeeded()
        do {
            let data = try encoder.encode(ClipboardDatabase(items: items))
            try data.write(to: historyURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save clipboard history: \(error)")
        }
    }

    private func savePreferences() {
        createStorageIfNeeded()
        do {
            let data = try encoder.encode(preferences)
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

    private func enforceHistoryLimit() {
        let limit = max(10, preferences.historyLimit)
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
        items = (pinned + unpinned)
            .sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned
                }
                return $0.createdAt > $1.createdAt
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

private extension Optional where Wrapped == Int {
    func defaulting(to value: Int) -> Int {
        self ?? value
    }
}
