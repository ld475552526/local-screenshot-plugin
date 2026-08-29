import AppKit
import Carbon.HIToolbox
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcutManager = ShortcutManager.shared
    private var statusItem: NSStatusItem!
    private var selector: ScreenshotSelector?
    private var feedbackResetWorkItem: DispatchWorkItem?
    private let logger = Logger(subsystem: "com.local.quickclip", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenuBarItem()
        enableLaunchAtLoginByDefault()
        shortcutManager.onShortcutPressed = { [weak self] in
            self?.handleShortcutPressed()
        }
        shortcutManager.registerCurrentShortcut()
        logger.info("Screen capture preflight on launch: \(CGPreflightScreenCaptureAccess(), privacy: .public)")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        logger.info("Reopen request: opening shortcut settings")
        openSettings()
        return true
    }

    private func buildMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let iconPath = Bundle.main.path(forResource: "QuickClipIcon", ofType: "png"), let icon = NSImage(contentsOfFile: iconPath) {
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "QuickClip")
        }
        statusItem.button?.toolTip = "QuickClip"

        let menu = NSMenu()
        let shortcutInfo = menu.addItem(withTitle: "当前快捷键：\(shortcutManager.currentShortcutDescription)", action: nil, keyEquivalent: "")
        shortcutInfo.isEnabled = false
        menu.addItem(withTitle: "框选截图并复制", action: #selector(beginSelection), keyEquivalent: "")
        menu.addItem(withTitle: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.items.last?.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(withTitle: "快捷键设置…", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 QuickClip", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func handleShortcutPressed() {
        NSLog("QuickClip global shortcut received: %@", shortcutManager.currentShortcutDescription)
        beginSelection()
    }

    @objc private func beginSelection() {
        let hasScreenCaptureAccess = CGPreflightScreenCaptureAccess()
        logger.info("Screen capture preflight on shortcut: \(hasScreenCaptureAccess, privacy: .public)")
        guard hasScreenCaptureAccess else {
            let requestedAccess = CGRequestScreenCaptureAccess()
            logger.info("Screen capture access request result: \(requestedAccess, privacy: .public)")
            if requestedAccess {
                beginSelection()
                return
            }
            let alert = NSAlert()
            alert.messageText = "需要“屏幕录制”权限"
            alert.informativeText = "QuickClip 需要读取屏幕内容才能截图。请在系统设置中允许后再试。"
            alert.addButton(withTitle: "前往系统设置")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn { openScreenRecordingSettings() }
            return
        }

        guard selector == nil else { return }
        selector = ScreenshotSelector { [weak self] result in
            self?.selector = nil
            switch result {
            case .success:
                self?.showCopiedFeedback()
            case .failure(let error):
                if case ScreenshotSelector.SelectionError.cancelled = error { return }
                self?.showCaptureFailure()
            }
        }
        selector?.show()
    }

    @objc private func openSettings() { SettingsWindowController.showWindow() }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if LoginItemManager.isEnabled {
                try LoginItemManager.uninstall()
                sender.state = .off
            } else {
                try LoginItemManager.install()
                sender.state = .on
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法更新开机启动设置"
            alert.informativeText = "请在“系统设置 → 通用 → 登录项”中允许 QuickClip 在后台运行。"
            alert.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func showCopiedFeedback() {
        feedbackResetWorkItem?.cancel()
        statusItem.button?.title = " ✓"
        statusItem.button?.toolTip = "截图已复制到剪贴板"
        let reset = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.title = ""
            self?.statusItem.button?.toolTip = "QuickClip"
        }
        feedbackResetWorkItem = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: reset)
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    private func showCaptureFailure() {
        let alert = NSAlert()
        alert.messageText = "截图失败"
        alert.informativeText = "无法获取所选区域。请确认已允许“屏幕录制”权限后重试。"
        alert.runModal()
    }

    private func enableLaunchAtLoginByDefault() {
        guard !LoginItemManager.isEnabled else { return }
        do {
            try LoginItemManager.install()
        } catch {
            NSLog("QuickClip could not install its launch agent: %@", error.localizedDescription)
        }
    }
}
