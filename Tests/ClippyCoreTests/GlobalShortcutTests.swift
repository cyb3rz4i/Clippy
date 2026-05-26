import ClippyCore
import XCTest

final class GlobalShortcutTests: XCTestCase {
    func testDefaultShortcutsAreDistinct() {
        let defaults: Set<GlobalShortcut> = [
            .showHistoryDefault,
            .pasteLatestDefault,
            .pauseCaptureDefault
        ]

        XCTAssertEqual(defaults.count, 3)
    }

    func testPrimaryModifierValidationRejectsShiftOnly() {
        let shiftOnly = GlobalShortcut(
            keyCode: 9,
            carbonModifiers: GlobalShortcutModifier.shift,
            displayName: "Shift V"
        )

        XCTAssertFalse(shiftOnly.hasPrimaryModifier)
    }

    func testPrimaryModifierValidationAcceptsControlOption() {
        let shortcut = GlobalShortcut(
            keyCode: 9,
            carbonModifiers: GlobalShortcutModifier.control | GlobalShortcutModifier.option,
            displayName: "Control Option V"
        )

        XCTAssertTrue(shortcut.hasPrimaryModifier)
    }

    func testMatchingKeyCombinationsIgnoreDisplayName() {
        let first = GlobalShortcut(
            keyCode: 9,
            carbonModifiers: GlobalShortcutModifier.command | GlobalShortcutModifier.option,
            displayName: "Command Option V"
        )
        let second = GlobalShortcut(
            keyCode: 9,
            carbonModifiers: GlobalShortcutModifier.command | GlobalShortcutModifier.option,
            displayName: "Cmd Opt V"
        )

        XCTAssertTrue(first.hasSameKeyCombination(as: second))
    }
}
