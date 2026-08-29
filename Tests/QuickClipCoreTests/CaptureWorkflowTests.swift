import XCTest
@testable import QuickClipCore

final class CaptureWorkflowTests: XCTestCase {
    func testPermissionIsRequiredBeforeCaptureCanStart() {
        var workflow = CaptureWorkflow()

        XCTAssertEqual(workflow.begin(hasScreenCapturePermission: false), .requestPermission)
        XCTAssertEqual(workflow.state, .idle)
    }

    func testOnlyOneNativeCaptureCanRunAtATime() {
        var workflow = CaptureWorkflow()

        XCTAssertEqual(workflow.begin(hasScreenCapturePermission: true), .startNativeCapture)
        XCTAssertEqual(workflow.state, .selecting)
        XCTAssertEqual(workflow.begin(hasScreenCapturePermission: true), .ignoredAlreadyCapturing)
    }

    func testSuccessReturnsToIdleAndReportsClipboardOutcome() {
        var workflow = CaptureWorkflow()
        _ = workflow.begin(hasScreenCapturePermission: true)

        XCTAssertEqual(workflow.finish(succeeded: true, wasCancelled: false), .copied)
        XCTAssertEqual(workflow.state, .idle)
    }

    func testCancellationReturnsToIdleWithoutFailure() {
        var workflow = CaptureWorkflow()
        _ = workflow.begin(hasScreenCapturePermission: true)

        XCTAssertEqual(workflow.finish(succeeded: false, wasCancelled: true), .cancelled)
        XCTAssertEqual(workflow.state, .idle)
    }

    func testNativeCommandAlwaysUsesInteractiveClipboardCapture() {
        XCTAssertEqual(NativeCaptureCommand.executablePath, "/usr/sbin/screencapture")
        XCTAssertEqual(NativeCaptureCommand.arguments, ["-i", "-c"])
    }
}
