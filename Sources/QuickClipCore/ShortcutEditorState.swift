public struct ShortcutEditorState: Equatable {
    public private(set) var currentShortcut: String
    public private(set) var previewShortcut: String
    public private(set) var isRecording = false
    public private(set) var hasPendingChange = false

    public init(currentShortcut: String) {
        self.currentShortcut = currentShortcut
        self.previewShortcut = currentShortcut
    }

    public var canSave: Bool {
        hasPendingChange && !isRecording
    }

    public mutating func beginRecording() {
        isRecording = true
    }

    public mutating func record(shortcut: String) {
        previewShortcut = shortcut
        hasPendingChange = true
        isRecording = false
    }

    public mutating func cancelRecording() {
        isRecording = false
    }

    public mutating func saveSucceeded() {
        currentShortcut = previewShortcut
        hasPendingChange = false
    }

    public mutating func reset(currentShortcut: String) {
        self.currentShortcut = currentShortcut
        previewShortcut = currentShortcut
        isRecording = false
        hasPendingChange = false
    }
}
