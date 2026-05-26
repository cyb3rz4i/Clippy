import AppKit
import ClippyCore
import Foundation

enum ImageStorageError: Error {
    case cannotCreateRepresentation
}

final class ImageStorage {
    let baseDirectory: URL
    private let originalsDirectory: URL
    private let thumbnailsDirectory: URL
    private let fileManager: FileManager

    init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.originalsDirectory = baseDirectory.appendingPathComponent("Originals", isDirectory: true)
        self.thumbnailsDirectory = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        self.fileManager = fileManager
        createDirectories()
    }

    func store(image: NSImage) throws -> StoredImagePayload {
        let originalData = try pngData(for: image)
        let digest = ClipboardHasher.digest(originalData)
        let originalURL = originalsDirectory.appendingPathComponent("\(digest).png")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(digest).png")

        if !fileManager.fileExists(atPath: originalURL.path) {
            try originalData.write(to: originalURL, options: [.atomic])
        }

        if !fileManager.fileExists(atPath: thumbnailURL.path) {
            let thumbnail = thumbnailImage(from: image, maxSide: 180)
            let thumbnailData = try pngData(for: thumbnail)
            try thumbnailData.write(to: thumbnailURL, options: [.atomic])
        }

        let pixelSize = pixelSize(for: image)
        return StoredImagePayload(
            fileURL: originalURL,
            thumbnailURL: thumbnailURL,
            pixelSize: pixelSize,
            byteCount: originalData.count,
            contentDigest: digest
        )
    }

    private func createDirectories() {
        try? fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    private func pixelSize(for image: NSImage) -> PixelSize {
        if let representation = image.representations.first {
            return PixelSize(width: Double(representation.pixelsWide), height: Double(representation.pixelsHigh))
        }
        return PixelSize(width: Double(image.size.width), height: Double(image.size.height))
    }

    private func thumbnailImage(from image: NSImage, maxSide: CGFloat) -> NSImage {
        let ratio = image.size.width > 0 && image.size.height > 0
            ? min(maxSide / image.size.width, maxSide / image.size.height)
            : 1
        let targetSize = NSSize(
            width: max(1, image.size.width * ratio),
            height: max(1, image.size.height * ratio)
        )

        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        thumbnail.unlockFocus()
        return thumbnail
    }

    private func pngData(for image: NSImage) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageStorageError.cannotCreateRepresentation
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageStorageError.cannotCreateRepresentation
        }
        return data
    }
}
