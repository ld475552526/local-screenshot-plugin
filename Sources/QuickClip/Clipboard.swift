import AppKit

enum Clipboard {
    static func copy(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}
