//
//  FloatingPanel.swift
//  latte
//
//  Created on 22/05/2026.
//

import Cocoa

class FloatingPanel: NSPanel {
    var keepTopEdgeFixed: Bool = true
    private var isSettingFrame = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior.insert(.fullScreenAuxiliary)
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
    }

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    override func cancelOperation(_ sender: Any?) {
        // Post a notification so AppDelegate.hidePanel() runs its full teardown
        // (setting contentView = nil to drop CPU, posting panelVisibilityChanged
        // to stop the ambient animation). Calling orderOut directly here would
        // bypass both of those.
        NotificationCenter.default.post(name: .panelDismissRequested, object: nil)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        guard !isSettingFrame else {
            super.setFrame(frameRect, display: flag)
            return
        }
        isSettingFrame = true
        defer { isSettingFrame = false }

        var newFrame = frameRect
        if keepTopEdgeFixed && newFrame.height != self.frame.height {
            let topY = self.frame.maxY
            newFrame.origin.y = topY - newFrame.height
        }

        super.setFrame(newFrame, display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        guard !isSettingFrame else {
            super.setFrame(frameRect, display: flag, animate: animateFlag)
            return
        }
        isSettingFrame = true
        defer { isSettingFrame = false }

        var newFrame = frameRect
        if keepTopEdgeFixed && newFrame.height != self.frame.height {
            let topY = self.frame.maxY
            newFrame.origin.y = topY - newFrame.height
        }

        super.setFrame(newFrame, display: flag, animate: animateFlag)
    }
}
