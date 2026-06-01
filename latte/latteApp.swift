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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupFloatingPanel()
        setupNotifications()
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

    @objc func statusBarClicked() {
        togglePanel()
    }

    func togglePanel() {
        if floatingPanel.isVisible { hidePanel() } else { showPanel() }
    }

    func showPanel() {
        if !floatingPanel.isMovableByWindowBackground {
            let screenRect = NSScreen.main?.visibleFrame ?? .zero
            var frame = floatingPanel.frame

            if let button = statusItem?.button, let buttonWindow = button.window {
                let buttonFrame = buttonWindow.convertToScreen(button.bounds)
                frame.origin.x = buttonFrame.midX - frame.width / 2
            } else {
                frame.origin.x = screenRect.maxX - frame.width - 10
            }

            frame.origin.x = max(10, frame.origin.x)
            frame.origin.y = screenRect.maxY - frame.height

            floatingPanel.setFrame(frame, display: true)
        }

        floatingPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        floatingPanel.orderOut(nil)
    }
}
