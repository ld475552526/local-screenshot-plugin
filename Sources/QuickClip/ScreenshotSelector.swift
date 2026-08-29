import AppKit
import os

/// Delegates the interactive selection and pixel capture to macOS's native
/// screenshot engine. This avoids using a potentially stale WindowServer image.
@MainActor
final class ScreenshotSelector {
    private var process: Process?
    private let completion: (Result<Void, Error>) -> Void
    private let logger = Logger(subsystem: "com.local.quickclip", category: "capture")

    init(completion: @escaping (Result<Void, Error>) -> Void) {
        self.completion = completion
    }

    func show() {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: native area/window selector; -c: always copy the resulting image.
        process.arguments = ["-i", "-c"]
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                if process.terminationStatus == 0 {
                    self.logger.info("Native interactive capture copied to clipboard")
                    self.completion(.success(()))
                } else {
                    // Escape is a normal cancellation path for screencapture -i.
                    self.logger.info("Native interactive capture ended without an image: status=\(process.terminationStatus, privacy: .public)")
                    self.completion(.failure(SelectionError.cancelled))
                }
            }
        }

        do {
            try process.run()
            self.process = process
            logger.info("Native interactive capture started")
        } catch {
            completion(.failure(error))
        }
    }

    enum SelectionError: Error { case cancelled }
}
