import XCTest
@testable import QuickClipCore

final class ShortcutKeyTests: XCTestCase {
    func testNormalizesSupportedKeys() {
        XCTAssertEqual(ShortcutKey.normalized("A"), "a")
        XCTAssertEqual(ShortcutKey.normalized("]"), "]")
        XCTAssertEqual(ShortcutKey.normalized(" "), " ")
    }

    func testRejectsUnsupportedOrMultipleKeys() {
        XCTAssertNil(ShortcutKey.normalized("`"))
        XCTAssertNil(ShortcutKey.normalized("ab"))
        XCTAssertNil(ShortcutKey.normalized(""))
    }

    func testUsesExpectedMacVirtualKeyCodes() {
        XCTAssertEqual(ShortcutKey.keyCode(for: "a"), 0)
        XCTAssertEqual(ShortcutKey.keyCode(for: "]"), 30)
        XCTAssertEqual(ShortcutKey.keyCode(for: " "), 49)
    }
}
