import AppKit
import QuickClipCore

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?

    private let recorder = ShortcutRecorderButton()
    private let saveButton = NSButton(title: "保存快捷键", target: nil, action: nil)
    private let recordAgainButton = NSButton(title: "重新录制", target: nil, action: nil)
    private var editorState: ShortcutEditorState
    private var pendingShortcut: (character: String, modifiers: NSEvent.ModifierFlags)?
    private var didCommit = false

    static func showWindow() {
        if shared == nil { shared = SettingsWindowController() }
        shared?.prepareForPresentation()
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        shared?.beginRecording()
    }

    init() {
        editorState = ShortcutEditorState(currentShortcut: ShortcutManager.shared.currentShortcutDescription)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 230),
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
        let hint = NSTextField(wrappingLabelWithString: "直接按下组合键后，会先显示在下方。确认无误后点击“保存快捷键”才会生效。按 Esc 取消本次录制。")
        hint.textColor = .secondaryLabelColor

        recorder.font = .systemFont(ofSize: 18, weight: .medium)
        recorder.bezelStyle = .rounded
        recorder.target = self
        recorder.action = #selector(beginRecording)
        recorder.onRecorded = { [weak self] character, modifiers, description in
            self?.record(shortcut: character, modifiers: modifiers, description: description)
        }
        recorder.onCancelled = { [weak self] in
            self?.cancelRecording()
        }

        let keyRow = NSStackView(views: [NSTextField(labelWithString: "候选快捷键"), recorder])
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = 14
        recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        recordAgainButton.target = self
        recordAgainButton.action = #selector(beginRecording)
        saveButton.target = self
        saveButton.action = #selector(saveShortcut)
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = false
        let cancel = NSButton(title: "取消", target: self, action: #selector(closeWindow))
        let buttons = NSStackView(views: [cancel, recordAgainButton, saveButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10

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

    private func prepareForPresentation() {
        didCommit = false
        pendingShortcut = nil
        editorState.reset(currentShortcut: ShortcutManager.shared.currentShortcutDescription)
        recorder.displayedShortcut = editorState.previewShortcut
        recorder.stopRecording()
        refreshControls()
    }

    @objc private func beginRecording() {
        editorState.beginRecording()
        ShortcutManager.shared.suspendCurrentShortcut()
        recorder.startRecording()
        refreshControls()
    }

    private func record(shortcut: String, modifiers: NSEvent.ModifierFlags, description: String) {
        pendingShortcut = (shortcut, modifiers)
        editorState.record(shortcut: description)
        recorder.displayedShortcut = editorState.previewShortcut
        refreshControls()
    }

    private func cancelRecording() {
        editorState.cancelRecording()
        recorder.displayedShortcut = editorState.previewShortcut
        ShortcutManager.shared.resumeCurrentShortcut()
        refreshControls()
    }

    @objc private func saveShortcut() {
        guard let pendingShortcut else { return }

        guard ShortcutManager.shared.update(character: pendingShortcut.character, modifiers: pendingShortcut.modifiers) else {
            ShortcutManager.shared.suspendCurrentShortcut()
            return
        }

        editorState.saveSucceeded()
        didCommit = true
        closeWindow()
    }

    private func refreshControls() {
        saveButton.isEnabled = editorState.canSave
        recordAgainButton.isEnabled = !editorState.isRecording
    }

    func windowWillClose(_ notification: Notification) {
        recorder.stopRecording()
        if !didCommit {
            ShortcutManager.shared.resumeCurrentShortcut()
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }
}

private final class ShortcutRecorderButton: NSButton {
    var onRecorded: ((String, NSEvent.ModifierFlags, String) -> Void)?
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
        displayedShortcut = description
        stopRecording()
        onRecorded?(character, modifiers, description)
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
