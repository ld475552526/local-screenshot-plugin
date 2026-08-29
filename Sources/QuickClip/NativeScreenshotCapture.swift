import Foundation
import QuickClipCore
import os

@MainActor
final class NativeScreenshotCapture {
    enum Outcome {
        case copied
        case cancelled
        case failed(Error)
    }

    private var process: Process?
    private let onFinish: (Outcome) -> Void
    private let logger = Logger(subsystem: "com.local.quickclip", category: "capture")

    init(onFinish: @escaping (Outcome) -> Void) {
        self.onFinish = onFinish
    }

    func start() {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: NativeCaptureCommand.executablePath)
        process.arguments = NativeCaptureCommand.arguments
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                if process.terminationStatus == 0 {
                    self.logger.info("Native capture copied to clipboard")
                    self.onFinish(.copied)
                } else {
                    self.logger.info("Native capture cancelled: status=\(process.terminationStatus, privacy: .public)")
                    self.onFinish(.cancelled)
                }
            }
        }

        self.process = process
        do {
            try process.run()
            logger.info("Native capture started")
        } catch {
            self.process = nil
            onFinish(.failed(error))
        }
    }
}
