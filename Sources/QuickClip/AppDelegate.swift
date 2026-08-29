import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcutManager = ShortcutManager.shared
    private var statusItem: NSStatusItem!
    private var feedbackResetWorkItem: DispatchWorkItem?
    private let logger = Logger(subsystem: "com.local.quickclip", category: "app")
    private lazy var captureCoordinator = CaptureCoordinator { [weak self] event in
        self?.handleCaptureEvent(event)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenuBarItem()
        enableLaunchAtLoginByDefault()
        shortcutManager.onShortcutPressed = { [weak self] in
            self?.beginCapture()
        }
        shortcutManager.registerCurrentShortcut()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        logger.info("Reopen request: opening shortcut settings")
        openSettings()
        return true
    }

    private func buildMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = appIcon()
        statusItem.button?.toolTip = "QuickClip"

        let menu = NSMenu()
        let shortcutInfo = menu.addItem(withTitle: "当前快捷键：\(shortcutManager.currentShortcutDescription)", action: nil, keyEquivalent: "")
        shortcutInfo.isEnabled = false
        menu.addItem(withTitle: "框选截图并复制", action: #selector(beginCapture), keyEquivalent: "")
        menu.addItem(withTitle: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.items.last?.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(withTitle: "快捷键设置…", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 QuickClip", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func appIcon() -> NSImage? {
        if let path = Bundle.main.path(forResource: "QuickClipIcon", ofType: "png"), let icon = NSImage(contentsOfFile: path) {
            icon.size = NSSize(width: 18, height: 18)
            return icon
        }
        return NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "QuickClip")
    }

    @objc private func beginCapture() {
        logger.info("Capture requested")
        captureCoordinator.start()
    }

    private func handleCaptureEvent(_ event: CaptureCoordinator.Event) {
        switch event {
        case .copied:
            showCopiedFeedback()
        case .permissionDenied:
            showScreenRecordingPermissionAlert()
        case .failed:
            showCaptureFailure()
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.showWindow()
    }

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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

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

    private func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要“屏幕录制”权限"
        alert.informativeText = "QuickClip 需要读取屏幕内容才能截图。请在系统设置中允许后再试。"
        alert.addButton(withTitle: "前往系统设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    private func showCaptureFailure() {
        let alert = NSAlert()
        alert.messageText = "截图失败"
        alert.informativeText = "系统截图工具未能完成截图，请稍后重试。"
        alert.runModal()
    }

    private func enableLaunchAtLoginByDefault() {
        guard !LoginItemManager.isEnabled else { return }
        do {
            try LoginItemManager.install()
        } catch {
            logger.error("Could not install launch agent: \(error.localizedDescription, privacy: .public)")
        }
    }
}
