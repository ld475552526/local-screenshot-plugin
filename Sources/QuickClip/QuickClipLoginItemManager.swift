import Foundation

enum LoginItemManager {
    private static let label = "com.local.quickclip"

    private static var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents", directoryHint: .isDirectory)
    }

    private static var launchAgentURL: URL {
        launchAgentsDirectory.appending(path: "\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    static func install() throws {
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let definition: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-gj", Bundle.main.bundleURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: definition, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)

        // Loading it once makes the setting visible immediately. `open -gj` reuses
        // the already-running app, so this does not create a second QuickClip process.
        try runLaunchctl(["bootstrap", "gui/\(getuid())", launchAgentURL.path])
    }

    static func uninstall() throws {
        try? runLaunchctl(["bootout", "gui/\(getuid())", launchAgentURL.path])
        guard FileManager.default.fileExists(atPath: launchAgentURL.path) else { return }
        try FileManager.default.removeItem(at: launchAgentURL)
    }

    private static func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "QuickClip.LoginItem",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "launchctl 未能更新开机启动配置。"]
            )
        }
    }
}
