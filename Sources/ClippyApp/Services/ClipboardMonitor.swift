import AppKit
import ClippyCore
import Foundation

@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private let imageStorage: ImageStorage
    private var timer: Timer?
    private var lastChangeCount: Int
    private var internalChangeCounts: Set<Int> = []
    private let maxTextCharacters = 60_000

    init(store: ClipboardStore, imageStorage: ImageStorage) {
        self.store = store
        self.imageStorage = imageStorage
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func markInternalChange(_ changeCount: Int) {
        internalChangeCounts.insert(changeCount)
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount

        guard changeCount != lastChangeCount else {
            return
        }
        lastChangeCount = changeCount

        if internalChangeCounts.remove(changeCount) != nil {
            return
        }

        guard store.preferences.captureEnabled,
              store.preferences.hasCompletedOnboarding,
              !store.preferences.capturePaused else {
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication
        let bundleID = sourceApp?.bundleIdentifier
        if let bundleID, store.preferences.excludedBundleIDs.contains(bundleID) {
            return
        }

        guard bundleID != Bundle.main.bundleIdentifier else {
            return
        }

        guard let payload = readPayload(from: pasteboard) else {
            return
        }

        store.add(
            payload: payload,
            sourceAppBundleID: bundleID,
            sourceAppName: sourceApp?.localizedName
        )
    }

    private func readPayload(from pasteboard: NSPasteboard) -> ClipboardPayload? {
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let image = NSImage(pasteboard: pasteboard),
           let storedImage = try? imageStorage.store(image: image) {
            return .image(storedImage)
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           url.scheme != nil {
            return .url(url, displayTitle: url.host)
        }

        if let string = pasteboard.string(forType: .string) {
            guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  string.count <= maxTextCharacters else {
                return nil
            }

            if let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
               url.scheme != nil,
               url.host != nil {
                return .url(url, displayTitle: url.host)
            }

            return .text(string)
        }

        return nil
    }
}
