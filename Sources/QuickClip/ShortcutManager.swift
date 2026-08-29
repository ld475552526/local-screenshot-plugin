import AppKit
import Carbon.HIToolbox
import QuickClipCore
import os

@MainActor
final class ShortcutManager {
    static let shared = ShortcutManager()

    static let defaultCharacter = "a"
    static let defaultModifiers: NSEvent.ModifierFlags = [.option, .shift]

    var onShortcutPressed: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.local.quickclip", category: "shortcut")

    private enum Key {
        static let character = "shortcut.character"
        static let modifiers = "shortcut.modifiers"
    }

    var character: String {
        ShortcutKey.normalized(defaults.string(forKey: Key.character) ?? "") ?? Self.defaultCharacter
    }

    var modifiers: NSEvent.ModifierFlags {
        let flags = storedModifiers
        return isSafeGlobalShortcut(character: character, modifiers: flags) ? flags : Self.defaultModifiers
    }

    var currentShortcutDescription: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + character.uppercased()
    }

    private var storedModifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Key.modifiers)))
            .intersection(.deviceIndependentFlagsMask)
    }

    private init() {
        repairStoredShortcutIfNeeded()
        installEventHandler()
    }

    @discardableResult
    func update(character: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let character = ShortcutKey.normalized(character), isSafeGlobalShortcut(character: character, modifiers: modifiers) else {
            presentShortcutError(message: "请至少使用 Option、Control 或 Shift 之一；单独使用 Command 容易与前台应用快捷键冲突。")
            return false
        }

        let previousCharacter = self.character
        let previousModifiers = self.modifiers
        unregisterCurrentShortcut()

        guard register(character: character, modifiers: modifiers) else {
            _ = register(character: previousCharacter, modifiers: previousModifiers)
            presentShortcutError(message: "该组合键可能正被其他应用占用。原快捷键仍可继续使用。")
            return false
        }

        defaults.set(character, forKey: Key.character)
        defaults.set(Int(modifiers.rawValue), forKey: Key.modifiers)
        return true
    }

    @discardableResult
    func registerCurrentShortcut() -> Bool {
        unregisterCurrentShortcut()
        guard register(character: character, modifiers: modifiers) else {
            presentShortcutError(message: "无法注册 \(currentShortcutDescription)。请在“快捷键设置”中换一个组合。")
            return false
        }
        return true
    }

    func suspendCurrentShortcut() {
        unregisterCurrentShortcut()
    }

    func resumeCurrentShortcut() {
        _ = registerCurrentShortcut()
    }

    private func repairStoredShortcutIfNeeded() {
        guard isSafeGlobalShortcut(character: character, modifiers: storedModifiers) else {
            defaults.set(Self.defaultCharacter, forKey: Key.character)
            defaults.set(Int(Self.defaultModifiers.rawValue), forKey: Key.modifiers)
            return
        }
    }

    private func isSafeGlobalShortcut(character: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard ShortcutKey.normalized(character) != nil else { return false }
        let nonCommandModifiers: NSEvent.ModifierFlags = [.option, .control, .shift]
        return !modifiers.intersection(nonCommandModifiers).isEmpty
    }

    private func unregisterCurrentShortcut() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func register(character: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let keyCode = ShortcutKey.keyCode(for: character) else { return false }
        let hotKeyID = EventHotKeyID(signature: OSType(0x51434C50), id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers(from: modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            hotKeyRef = nil
            logger.error("Global shortcut registration failed: status=\(status, privacy: .public)")
            return false
        }
        logger.info("Global shortcut registered: \(Self.shortcutDescription(character: character, modifiers: modifiers), privacy: .public)")
        return true
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            if id.signature == OSType(0x51434C50) {
                let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.logger.info("Global shortcut event received")
                    manager.onShortcutPressed?()
                }
            }
            return noErr
        }, 1, &eventType, userData, &eventHandler)
    }

    private static func shortcutDescription(character: String, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + character.uppercased()
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private func presentShortcutError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "无法注册快捷键"
            alert.informativeText = message
            alert.runModal()
        }
    }
}
