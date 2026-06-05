import Foundation

public struct GlobalShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayName = displayName
    }
}

public enum GlobalShortcutModifier {
    public static let command: UInt32 = 0x00000100
    public static let shift: UInt32 = 0x00000200
    public static let option: UInt32 = 0x00000800
    public static let control: UInt32 = 0x00001000
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var hasCompletedOnboarding: Bool
    public var captureEnabled: Bool
    public var capturePaused: Bool
    public var historyLimit: Int
    public var launchAtLogin: Bool
    public var autoPasteWhenAllowed: Bool
    public var excludedBundleIDs: Set<String>
    public var showHistoryShortcut: GlobalShortcut
    public var pasteLatestShortcut: GlobalShortcut
    public var pauseCaptureShortcut: GlobalShortcut

    public init(
        hasCompletedOnboarding: Bool = false,
        captureEnabled: Bool = false,
        capturePaused: Bool = false,
        historyLimit: Int = 100,
        launchAtLogin: Bool = false,
        autoPasteWhenAllowed: Bool = true,
        excludedBundleIDs: Set<String> = [],
        showHistoryShortcut: GlobalShortcut = .showHistoryDefault,
        pasteLatestShortcut: GlobalShortcut = .pasteLatestDefault,
        pauseCaptureShortcut: GlobalShortcut = .pauseCaptureDefault
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.captureEnabled = captureEnabled
        self.capturePaused = capturePaused
        self.historyLimit = historyLimit
        self.launchAtLogin = launchAtLogin
        self.autoPasteWhenAllowed = autoPasteWhenAllowed
        self.excludedBundleIDs = excludedBundleIDs
        self.showHistoryShortcut = showHistoryShortcut
        self.pasteLatestShortcut = pasteLatestShortcut
        self.pauseCaptureShortcut = pauseCaptureShortcut
    }

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case captureEnabled
        case capturePaused
        case historyLimit
        case launchAtLogin
        case autoPasteWhenAllowed
        case excludedBundleIDs
        case showHistoryShortcut
        case pasteLatestShortcut
        case pauseCaptureShortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hasCompletedOnboarding: try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false,
            captureEnabled: try container.decodeIfPresent(Bool.self, forKey: .captureEnabled) ?? false,
            capturePaused: try container.decodeIfPresent(Bool.self, forKey: .capturePaused) ?? false,
            historyLimit: try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 100,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
            autoPasteWhenAllowed: try container.decodeIfPresent(Bool.self, forKey: .autoPasteWhenAllowed) ?? true,
            excludedBundleIDs: try container.decodeIfPresent(Set<String>.self, forKey: .excludedBundleIDs) ?? [],
            showHistoryShortcut: try container.decodeIfPresent(GlobalShortcut.self, forKey: .showHistoryShortcut) ?? .showHistoryDefault,
            pasteLatestShortcut: try container.decodeIfPresent(GlobalShortcut.self, forKey: .pasteLatestShortcut) ?? .pasteLatestDefault,
            pauseCaptureShortcut: try container.decodeIfPresent(GlobalShortcut.self, forKey: .pauseCaptureShortcut) ?? .pauseCaptureDefault
        )
    }
}

public extension GlobalShortcut {
    var hasPrimaryModifier: Bool {
        carbonModifiers & (GlobalShortcutModifier.command | GlobalShortcutModifier.option | GlobalShortcutModifier.control) != 0
    }

    func hasSameKeyCombination(as other: GlobalShortcut) -> Bool {
        keyCode == other.keyCode && carbonModifiers == other.carbonModifiers
    }

    static let showHistoryDefault = GlobalShortcut(
        keyCode: 9,
        carbonModifiers: GlobalShortcutModifier.control | GlobalShortcutModifier.option,
        displayName: "Control Option V"
    )

    static let pasteLatestDefault = GlobalShortcut(
        keyCode: 9,
        carbonModifiers: GlobalShortcutModifier.command | GlobalShortcutModifier.control | GlobalShortcutModifier.option,
        displayName: "Command Control Option V"
    )

    static let pauseCaptureDefault = GlobalShortcut(
        keyCode: 35,
        carbonModifiers: GlobalShortcutModifier.control | GlobalShortcutModifier.option,
        displayName: "Control Option P"
    )
}
