//
//  latteApp.swift
//  latte
//
//  Created on 22/05/2026.
//

import SwiftUI

@main
struct latte: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

extension Notification.Name {
    static let windowMovableChanged = Notification.Name("windowMovableChanged")
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingPanel: FloatingPanel!
    var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupFloatingPanel()
        setupNotifications()
        setupEventMonitor()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let iconName = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "arrow.down.circle.fill"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Latte")
            button.action = #selector(statusBarClicked)
        }
    }

    func setupFloatingPanel() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let panelWidth: CGFloat = 380
        let initialHeight: CGFloat = 80

        let panelX = screenRect.maxX - panelWidth - 10
        let panelY = screenRect.maxY - initialHeight

        let panelRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: initialHeight)

        floatingPanel = FloatingPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let contentView = LatteView(onClose: { [weak self] in
            self?.hidePanel()
        })

        floatingPanel.contentView = NSHostingView(rootView: contentView)
    }

    func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .windowMovableChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isMovable = notification.userInfo?["value"] as? Bool ?? false
            self?.floatingPanel.isMovableByWindowBackground = isMovable
        }

        NotificationCenter.default.addObserver(
            forName: .menuBarIconChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let icon = notification.userInfo?["icon"] as? String {
                self?.statusItem?.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Latte")
            }
        }
    }

    func setupEventMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let panel = self.floatingPanel, panel.isVisible else { return }
            
            let keepOpen = UserDefaults.standard.bool(forKey: "keepPanelOpen")
            if keepOpen { return }
            
            // Do not force-close if standard dialog boxes (like OpenPanel/SavePanel) are currently running
            if NSApp.modalWindow != nil { return }
            
            let mouseLocation = NSEvent.mouseLocation
            if !panel.frame.contains(mouseLocation) {
                // Also prevent hiding if they literally clicked the status bar icon (handled by statusBarClicked toggle)
                if let button = self.statusItem?.button, let window = button.window {
                    if window.frame.contains(mouseLocation) { return }
                }
                self.hidePanel()
            }
        }
    }

    @objc func statusBarClicked() {
        togglePanel()
    }

    func togglePanel() {
        if floatingPanel.isVisible { hidePanel() } else { showPanel() }
    }

    func showPanel() {
        if !floatingPanel.isMovableByWindowBackground {
            // Anchor to whichever screen the menu bar icon was clicked on,
            // not always the main display (fixes multi-monitor placement).
            let targetScreen = screenForStatusItem()
            let screenRect = targetScreen.visibleFrame
            var frame = floatingPanel.frame

            if let button = statusItem?.button, let buttonWindow = button.window {
                let buttonFrame = buttonWindow.convertToScreen(button.bounds)
                frame.origin.x = buttonFrame.midX - frame.width / 2
            } else {
                frame.origin.x = screenRect.maxX - frame.width - 10
            }

            // Clamp within the target screen's bounds rather than the global origin.
            let minX = screenRect.minX + 10
            let maxX = screenRect.maxX - frame.width - 10
            frame.origin.x = min(max(minX, frame.origin.x), maxX)
            frame.origin.y = screenRect.maxY - frame.height

            floatingPanel.setFrame(frame, display: true)
        }

        floatingPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// The screen the status bar icon currently lives on. With "Displays have
    /// separate Spaces" enabled the icon appears on every menu bar, so we use
    /// the mouse location at click time (and the icon's own window as a
    /// fallback) to find the display the user actually interacted with.
    private func screenForStatusItem() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return screen
        }
        if let window = statusItem?.button?.window,
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(window.frame) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    func hidePanel() {
        floatingPanel.orderOut(nil)
    }
}
