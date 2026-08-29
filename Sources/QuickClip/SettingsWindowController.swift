import AppKit
import QuickClipCore

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?
    private let recorder = ShortcutRecorderButton()

    static func showWindow() {
        if shared == nil { shared = SettingsWindowController() }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        shared?.beginRecording()
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickClip 快捷键"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "设置截图快捷键")
        title.font = .boldSystemFont(ofSize: 16)
        let hint = NSTextField(wrappingLabelWithString: "窗口打开后，直接按下想使用的组合键即可保存。至少包含 Option、Control 或 Shift 之一；按 Esc 保留原快捷键。")
        hint.textColor = .secondaryLabelColor

        recorder.font = .systemFont(ofSize: 18, weight: .medium)
        recorder.bezelStyle = .rounded
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.onRecorded = { character, modifiers in
            let didUpdate = ShortcutManager.shared.update(character: character, modifiers: modifiers)
            if !didUpdate { ShortcutManager.shared.suspendCurrentShortcut() }
            return didUpdate
        }
        recorder.onCancelled = { [weak self] in
            self?.restoreCurrentShortcut()
        }

        let keyRow = NSStackView(views: [NSTextField(labelWithString: "按下组合键"), recorder])
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = 14
        recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let cancel = NSButton(title: "取消", target: self, action: #selector(closeWindow))
        let buttons = NSStackView(views: [cancel])
        buttons.alignment = .trailing

        let stack = NSStackView(views: [title, hint, keyRow, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
    }

    private func beginRecording() {
        recorder.displayedShortcut = ShortcutManager.shared.currentShortcutDescription
        ShortcutManager.shared.suspendCurrentShortcut()
        recorder.startRecording()
    }

    private func restoreCurrentShortcut() {
        ShortcutManager.shared.resumeCurrentShortcut()
    }

    func windowWillClose(_ notification: Notification) {
        guard recorder.isRecording else { return }
        recorder.stopRecording()
        restoreCurrentShortcut()
    }

    @objc private func closeWindow() { window?.close() }
}

private final class ShortcutRecorderButton: NSButton {
    var onRecorded: ((String, NSEvent.ModifierFlags) -> Bool)?
    var onCancelled: (() -> Void)?
    var displayedShortcut = "" {
        didSet {
            if !isRecording { title = displayedShortcut }
        }
    }

    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    func startRecording() {
        isRecording = true
        title = "请按下快捷键…"
        contentTintColor = .controlAccentColor
        window?.makeFirstResponder(self)
    }

    func stopRecording() {
        isRecording = false
        contentTintColor = .labelColor
        title = displayedShortcut
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            stopRecording()
            onCancelled?()
            return
        }

        guard let character = ShortcutKey.normalized(event.charactersIgnoringModifiers ?? "") else {
            NSSound.beep()
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers: NSEvent.ModifierFlags = [.option, .control, .shift]
        guard !modifiers.intersection(requiredModifiers).isEmpty else {
            title = "请加入 ⌥、⌃ 或 ⇧"
            NSSound.beep()
            return
        }

        let description = Self.description(for: character, modifiers: modifiers)
        guard onRecorded?(character, modifiers) == true else {
            title = "无法使用 \(description)，请再试一次"
            return
        }

        displayedShortcut = description
        stopRecording()
        window?.performClose(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    private static func description(for character: String, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + character.uppercased()
    }
}
