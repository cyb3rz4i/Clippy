import CryptoKit
import Foundation

public enum ClipboardHasher {
    public static func hash(payload: ClipboardPayload) -> String {
        switch payload {
        case .text(let value):
            digest("text:\(value)")
        case .url(let url, _):
            digest("url:\(url.absoluteString)")
        case .image(let image):
            "image:\(image.contentDigest)"
        }
    }

    public static func digest(_ value: String) -> String {
        let data = Data(value.utf8)
        return digest(data)
    }

    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
