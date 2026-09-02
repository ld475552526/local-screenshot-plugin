import XCTest
@testable import QuickClipCore

final class ShortcutEditorStateTests: XCTestCase {
    func testRecordingShowsPreviewAndEnablesSave() {
        var state = ShortcutEditorState(currentShortcut: "⌥⇧A")

        state.beginRecording()
        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.canSave)

        state.record(shortcut: "⌃⌘A")
        XCTAssertEqual(state.previewShortcut, "⌃⌘A")
        XCTAssertTrue(state.canSave)
    }

    func testCancelRecordingKeepsVisiblePendingPreview() {
        var state = ShortcutEditorState(currentShortcut: "⌥⇧A")
        state.record(shortcut: "⌃⌘A")

        state.beginRecording()
        state.cancelRecording()

        XCTAssertEqual(state.previewShortcut, "⌃⌘A")
        XCTAssertTrue(state.canSave)
    }

    func testSaveConfirmsPreviewAsCurrentShortcut() {
        var state = ShortcutEditorState(currentShortcut: "⌥⇧A")
        state.record(shortcut: "⌃⌘A")

        state.saveSucceeded()

        XCTAssertEqual(state.currentShortcut, "⌃⌘A")
        XCTAssertEqual(state.previewShortcut, "⌃⌘A")
        XCTAssertFalse(state.canSave)
    }

    func testReopenResetsDraftToSavedShortcut() {
        var state = ShortcutEditorState(currentShortcut: "⌥⇧A")
        state.record(shortcut: "⌃⌘A")

        state.reset(currentShortcut: "⌃⌥S")

        XCTAssertEqual(state.currentShortcut, "⌃⌥S")
        XCTAssertEqual(state.previewShortcut, "⌃⌥S")
        XCTAssertFalse(state.hasPendingChange)
    }
}
