import Foundation

public enum ClipboardKind: String, Codable, CaseIterable, Sendable {
    case text
    case url
    case image
}

public struct PixelSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct StoredImagePayload: Codable, Hashable, Sendable {
    public var fileURL: URL
    public var thumbnailURL: URL
    public var pixelSize: PixelSize
    public var byteCount: Int
    public var contentDigest: String

    public init(
        fileURL: URL,
        thumbnailURL: URL,
        pixelSize: PixelSize,
        byteCount: Int,
        contentDigest: String
    ) {
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.pixelSize = pixelSize
        self.byteCount = byteCount
        self.contentDigest = contentDigest
    }
}

public enum ClipboardPayload: Codable, Hashable, Sendable {
    case text(String)
    case url(URL, displayTitle: String?)
    case image(StoredImagePayload)

    public var kind: ClipboardKind {
        switch self {
        case .text:
            .text
        case .url:
            .url
        case .image:
            .image
        }
    }
}

public struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: ClipboardKind
    public var title: String
    public var previewText: String
    public var createdAt: Date
    public var lastUsedAt: Date?
    public var isPinned: Bool
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var contentHash: String
    public var payload: ClipboardPayload

    public init(
        id: UUID = UUID(),
        kind: ClipboardKind,
        title: String,
        previewText: String,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        contentHash: String,
        payload: ClipboardPayload
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.previewText = previewText
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = contentHash
        self.payload = payload
    }
}

public extension ClipboardItem {
    var searchableText: String {
        [
            title,
            previewText,
            sourceAppName ?? "",
            sourceAppBundleID ?? ""
        ]
        .joined(separator: " ")
    }
}
