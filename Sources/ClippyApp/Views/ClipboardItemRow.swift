import AppKit
import ClippyCore
import SwiftUI

struct ClipboardItemRow: View {
    var item: ClipboardItem
    var index: Int
    var isSelected: Bool
    var onChoose: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            preview

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if index < 9 {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.createdAt, style: .relative)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(item.previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(item.kind == .text ? 2 : 1)

                HStack(spacing: 6) {
                    Label(labelText, systemImage: labelIcon)
                        .labelStyle(.titleAndIcon)

                    if let source = item.sourceAppName {
                        Text("•")
                        Text(source)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                Button(action: onPin) {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                }
                .buttonStyle(.borderless)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Delete")
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(12)
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onChoose)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case .image(let imagePayload):
            Thumbnail(url: imagePayload.thumbnailURL)
                .frame(width: 64, height: 64)
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                Image(systemName: labelIcon)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)
        }
    }

    private var backgroundFill: some ShapeStyle {
        isSelected ? AnyShapeStyle(Color.primary.opacity(0.12)) : AnyShapeStyle(Color.primary.opacity(0.045))
    }

    private var labelIcon: String {
        switch item.kind {
        case .text:
            "doc.plaintext"
        case .url:
            "link"
        case .image:
            "photo"
        }
    }

    private var labelText: String {
        switch item.kind {
        case .text:
            "Text"
        case .url:
            "Link"
        case .image:
            "Image"
        }
    }
}

private struct Thumbnail: View {
    var url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .task(id: url) {
            image = await ThumbnailImageLoader.shared.image(for: url)
        }
    }
}

@MainActor
private final class ThumbnailImageLoader {
    static let shared = ThumbnailImageLoader()

    private let cache = NSCache<NSURL, NSImage>()

    func image(for url: URL) async -> NSImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value

        guard let data,
              let image = NSImage(data: data) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }
}
