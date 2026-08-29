import AppKit

protocol ScreenCaptureAuthorizing {
    func isGranted() -> Bool
    func requestAccess() -> Bool
}

struct SystemScreenCaptureAuthorizer: ScreenCaptureAuthorizing {
    func isGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
