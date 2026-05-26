import ClippyCore
import XCTest

final class ClipboardStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testAddsTextItem() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)

        let item = store.add(payload: .text("Hello Clippy"))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(item?.kind, .text)
        XCTAssertEqual(store.items.first?.title, "Hello Clippy")
    }

    func testTurnsURLTextIntoURLItem() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)

        let item = store.add(payload: .text("https://example.com/path"))

        XCTAssertEqual(item?.kind, .url)
        XCTAssertEqual(item?.previewText, "https://example.com/path")
    }

    func testSuppressesDuplicatesAndMovesExistingItemToFront() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)
        let firstDate = Date(timeIntervalSince1970: 10)
        let secondDate = Date(timeIntervalSince1970: 20)

        let first = store.add(payload: .text("Same"), date: firstDate)
        _ = store.add(payload: .text("Different"), date: Date(timeIntervalSince1970: 15))
        let second = store.add(payload: .text("Same"), date: secondDate)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(store.items.first?.previewText, "Same")
        XCTAssertEqual(store.items.first?.createdAt, secondDate)
    }

    func testHistoryLimitPreservesPinnedItems() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)
        store.updatePreferences {
            $0.historyLimit = 10
        }

        var pinnedID: UUID?
        for index in 0..<15 {
            let item = store.add(
                payload: .text("Item \(index)"),
                date: Date(timeIntervalSince1970: TimeInterval(index))
            )
            if index == 0, let id = item?.id {
                pinnedID = id
                store.setPinned(true, id: id)
            }
        }

        XCTAssertEqual(store.items.filter { !$0.isPinned }.count, 10)
        XCTAssertTrue(store.items.contains { $0.id == pinnedID && $0.isPinned })
    }

    func testSearchFindsFuzzyMatchesAndRanksPinnedItems() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)
        let ordinary = store.add(payload: .text("Quarterly roadmap"))
        let pinned = store.add(payload: .text("Quick reference"))
        if let pinned {
            store.setPinned(true, id: pinned.id)
        }

        let results = store.search("qr")

        XCTAssertEqual(results.first?.id, pinned?.id)
        XCTAssertTrue(results.contains { $0.id == ordinary?.id })
    }

    func testDeleteAndClearHistory() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)
        let first = store.add(payload: .text("One"))
        _ = store.add(payload: .text("Two"))

        if let first {
            store.delete(id: first.id)
        }

        XCTAssertEqual(store.items.count, 1)

        store.clearHistory()

        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistenceRoundTrip() {
        let firstStore = ClipboardStore(storageDirectory: temporaryDirectory)
        firstStore.add(payload: .text("Persist me"))
        firstStore.updatePreferences {
            $0.captureEnabled = true
            $0.historyLimit = 50
        }

        let secondStore = ClipboardStore(storageDirectory: temporaryDirectory)

        XCTAssertEqual(secondStore.items.first?.previewText, "Persist me")
        XCTAssertTrue(secondStore.preferences.captureEnabled)
        XCTAssertEqual(secondStore.preferences.historyLimit, 50)
    }

    func testImagePayloadCanBeStoredInHistory() {
        let store = ClipboardStore(storageDirectory: temporaryDirectory)
        let imageURL = temporaryDirectory.appendingPathComponent("image.png")
        let thumbnailURL = temporaryDirectory.appendingPathComponent("thumb.png")
        let payload = StoredImagePayload(
            fileURL: imageURL,
            thumbnailURL: thumbnailURL,
            pixelSize: PixelSize(width: 640, height: 480),
            byteCount: 2048,
            contentDigest: "abc123"
        )

        let item = store.add(payload: .image(payload))

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(item?.title, "Image")
        XCTAssertTrue(item?.previewText.contains("640 x 480") == true)
    }
}
