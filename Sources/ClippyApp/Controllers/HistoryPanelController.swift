import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController {
    private let model: AppModel
    private let panel: NSPanel

    var isVisible: Bool {
        panel.isVisible
    }

    init(model: AppModel) {
        self.model = model
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: true
        )
        configurePanel()
    }

    func show(relativeTo anchorWindow: NSWindow?) {
        position(relativeTo: anchorWindow)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func configurePanel() {
        panel.title = "Clippy"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let rootView = HistoryPanelView(model: model)
        panel.contentViewController = NSHostingController(rootView: rootView)
    }

    private func position(relativeTo anchorWindow: NSWindow?) {
        let size = NSSize(width: 720, height: 540)
        panel.setContentSize(size)

        guard let anchorFrame = anchorWindow?.frame,
              let screen = anchorWindow?.screen ?? NSScreen.main else {
            centerOnMainScreen(size: size)
            return
        }

        let visible = screen.visibleFrame
        let x = min(max(anchorFrame.midX - size.width + 48, visible.minX + 16), visible.maxX - size.width - 16)
        let y = min(max(anchorFrame.minY - size.height - 8, visible.minY + 16), visible.maxY - size.height - 16)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func centerOnMainScreen(size: NSSize) {
        guard let screen = NSScreen.main else {
            return
        }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        ))
    }
}
