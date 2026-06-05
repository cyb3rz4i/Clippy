import ClippyCore
import XCTest

@MainActor
final class ClipboardStoreTests: XCTestCase {
    nonisolated(unsafe) private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    private func makeStore() -> ClipboardStore {
        ClipboardStore(storageDirectory: temporaryDirectory, historySaveDebounce: 60)
    }

    func testAddsTextItem() {
        let store = makeStore()

        let item = store.add(payload: .text("Hello Clippy"))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(item?.kind, .text)
        XCTAssertEqual(store.items.first?.title, "Hello Clippy")
    }

    func testTurnsURLTextIntoURLItem() {
        let store = makeStore()

        let item = store.add(payload: .text("https://example.com/path"))

        XCTAssertEqual(item?.kind, .url)
        XCTAssertEqual(item?.previewText, "https://example.com/path")
    }

    func testSuppressesDuplicatesAndMovesExistingItemToFront() {
        let store = makeStore()
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
        let store = makeStore()
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
        let store = makeStore()
        let ordinary = store.add(payload: .text("Quarterly roadmap"))
        let pinned = store.add(payload: .text("Quick reference"))
        if let pinned {
            store.setPinned(true, id: pinned.id)
        }

        let results = store.search("qr")

        XCTAssertEqual(results.first?.id, pinned?.id)
        XCTAssertTrue(results.contains { $0.id == ordinary?.id })
    }

    func testSearchUsesLastUsedAsRankingSignal() {
        let store = makeStore()
        let older = store.add(payload: .text("Reference note"), date: Date(timeIntervalSince1970: 10))
        let newer = store.add(payload: .text("Reference memo"), date: Date(timeIntervalSince1970: 20))

        if let older {
            store.markUsed(id: older.id, date: Date(timeIntervalSince1970: 30))
        }

        let results = store.search("reference")

        XCTAssertEqual(results.first?.id, older?.id)
        XCTAssertTrue(results.contains { $0.id == newer?.id })
    }

    func testDeleteAndClearHistory() {
        let store = makeStore()
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
        let firstStore = makeStore()
        firstStore.add(payload: .text("Persist me"))
        firstStore.flushPendingHistorySaves()
        firstStore.updatePreferences {
            $0.captureEnabled = true
            $0.autoPasteWhenAllowed = false
            $0.historyLimit = 50
        }

        let secondStore = makeStore()

        XCTAssertEqual(secondStore.items.first?.previewText, "Persist me")
        XCTAssertTrue(secondStore.preferences.captureEnabled)
        XCTAssertFalse(secondStore.preferences.autoPasteWhenAllowed)
        XCTAssertEqual(secondStore.preferences.historyLimit, 50)
    }

    func testHistoryPersistenceUsesCompactJSON() throws {
        let store = makeStore()
        store.add(payload: .text("Compact me"))
        store.flushPendingHistorySaves()

        let json = try String(contentsOf: store.historyURL, encoding: .utf8)

        XCTAssertFalse(json.contains("\n  "))
    }

    func testPreferenceUpdateDoesNotRewriteUnchangedHistory() throws {
        let store = makeStore()
        store.add(payload: .text("History stays put"))
        store.flushPendingHistorySaves()

        let before = try FileManager.default.attributesOfItem(atPath: store.historyURL.path)[.modificationDate] as? Date
        Thread.sleep(forTimeInterval: 1.1)

        store.updatePreferences {
            $0.captureEnabled = true
        }
        store.flushPendingHistorySaves()

        let after = try FileManager.default.attributesOfItem(atPath: store.historyURL.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after)
    }

    func testLaunchAtLoginDefaultsToUserOptIn() {
        let store = makeStore()

        XCTAssertFalse(store.preferences.launchAtLogin)
    }

    func testAutoPasteDefaultsToEnabledForOlderPreferences() throws {
        let preferencesURL = temporaryDirectory.appendingPathComponent("preferences.json")
        let olderPreferences = """
        {
          "captureEnabled" : true,
          "capturePaused" : true,
          "hasCompletedOnboarding" : true,
          "historyLimit" : 50,
          "launchAtLogin" : true,
          "automaticallyCopyScreenshots" : true,
          "wallpaperEnabled" : true,
          "wallpaperFolderURL" : "file:///tmp/wallpapers"
        }
        """
        try olderPreferences.write(to: preferencesURL, atomically: true, encoding: .utf8)

        let store = makeStore()

        XCTAssertTrue(store.preferences.captureEnabled)
        XCTAssertTrue(store.preferences.capturePaused)
        XCTAssertTrue(store.preferences.hasCompletedOnboarding)
        XCTAssertEqual(store.preferences.historyLimit, 50)
        XCTAssertTrue(store.preferences.launchAtLogin)
        XCTAssertTrue(store.preferences.autoPasteWhenAllowed)
    }

    func testImagePayloadCanBeStoredInHistory() {
        let store = makeStore()
        let payload = makeImagePayload(digest: "abc123")

        let item = store.add(payload: .image(payload))

        XCTAssertEqual(item?.kind, .image)
        XCTAssertEqual(item?.title, "Image")
        XCTAssertTrue(item?.previewText.contains("640 x 480") == true)
    }

    func testDeletingImagePayloadNotifiesCleanup() {
        let store = makeStore()
        var removedDigests: [String] = []
        store.onImagePayloadsRemoved = { removedDigests.append(contentsOf: $0.map(\.contentDigest)) }
        let payload = makeImagePayload(digest: "delete-me")
        let item = store.add(payload: .image(payload))

        if let item {
            store.delete(id: item.id)
        }

        XCTAssertEqual(removedDigests, ["delete-me"])
    }

    func testClearingImagePayloadsNotifiesCleanup() {
        let store = makeStore()
        var removedDigests: [String] = []
        store.onImagePayloadsRemoved = { removedDigests.append(contentsOf: $0.map(\.contentDigest)) }
        store.add(payload: .image(makeImagePayload(digest: "first")))
        store.add(payload: .image(makeImagePayload(digest: "second")))

        store.clearHistory()

        XCTAssertEqual(Set(removedDigests), ["first", "second"])
    }

    func testEvictingImagePayloadNotifiesCleanup() {
        let store = makeStore()
        store.updatePreferences {
            $0.historyLimit = 10
        }
        var removedDigests: [String] = []
        store.onImagePayloadsRemoved = { removedDigests.append(contentsOf: $0.map(\.contentDigest)) }
        store.add(payload: .image(makeImagePayload(digest: "evicted")), date: Date(timeIntervalSince1970: 0))

        for index in 1...10 {
            store.add(payload: .text("Item \(index)"), date: Date(timeIntervalSince1970: TimeInterval(index)))
        }

        XCTAssertEqual(removedDigests, ["evicted"])
    }

    private func makeImagePayload(digest: String) -> StoredImagePayload {
        StoredImagePayload(
            fileURL: temporaryDirectory.appendingPathComponent("\(digest).png"),
            thumbnailURL: temporaryDirectory.appendingPathComponent("\(digest)-thumb.png"),
            pixelSize: PixelSize(width: 640, height: 480),
            byteCount: 2048,
            contentDigest: digest
        )
    }
}
