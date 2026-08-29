import QuickClipCore
import os

@MainActor
final class CaptureCoordinator {
    enum Event {
        case copied
        case permissionDenied
        case failed
    }

    private let authorizer: any ScreenCaptureAuthorizing
    private let onEvent: (Event) -> Void
    private let logger = Logger(subsystem: "com.local.quickclip", category: "capture")
    private var workflow = CaptureWorkflow()
    private var capture: NativeScreenshotCapture?

    init(
        authorizer: any ScreenCaptureAuthorizing = SystemScreenCaptureAuthorizer(),
        onEvent: @escaping (Event) -> Void
    ) {
        self.authorizer = authorizer
        self.onEvent = onEvent
    }

    func start() {
        let isGranted = authorizer.isGranted()
        logger.info("Screen capture permission available: \(isGranted, privacy: .public)")

        switch workflow.begin(hasScreenCapturePermission: isGranted) {
        case .ignoredAlreadyCapturing:
            logger.info("Capture request ignored while a selection is active")

        case .requestPermission:
            let wasGranted = authorizer.requestAccess()
            logger.info("Screen capture permission request result: \(wasGranted, privacy: .public)")
            guard wasGranted else {
                onEvent(.permissionDenied)
                return
            }
            start()

        case .startNativeCapture:
            let capture = NativeScreenshotCapture { [weak self] outcome in
                self?.complete(outcome)
            }
            self.capture = capture
            capture.start()
        }
    }

    private func complete(_ outcome: NativeScreenshotCapture.Outcome) {
        capture = nil

        switch outcome {
        case .copied:
            if workflow.finish(succeeded: true, wasCancelled: false) == .copied {
                onEvent(.copied)
            }

        case .cancelled:
            _ = workflow.finish(succeeded: false, wasCancelled: true)

        case .failed:
            if workflow.finish(succeeded: false, wasCancelled: false) == .failed {
                onEvent(.failed)
            }
        }
    }
}
