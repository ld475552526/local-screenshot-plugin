public struct CaptureWorkflow {
    public enum State: Equatable {
        case idle
        case selecting
    }

    public enum StartDecision: Equatable {
        case requestPermission
        case startNativeCapture
        case ignoredAlreadyCapturing
    }

    public enum FinishDecision: Equatable {
        case copied
        case cancelled
        case failed
        case ignored
    }

    public private(set) var state: State = .idle

    public init() {}

    public mutating func begin(hasScreenCapturePermission: Bool) -> StartDecision {
        guard state == .idle else { return .ignoredAlreadyCapturing }
        guard hasScreenCapturePermission else { return .requestPermission }

        state = .selecting
        return .startNativeCapture
    }

    public mutating func finish(succeeded: Bool, wasCancelled: Bool) -> FinishDecision {
        guard state == .selecting else { return .ignored }
        state = .idle

        if succeeded { return .copied }
        return wasCancelled ? .cancelled : .failed
    }
}

public enum NativeCaptureCommand {
    public static let executablePath = "/usr/sbin/screencapture"
    public static let arguments = ["-i", "-c"]
}
