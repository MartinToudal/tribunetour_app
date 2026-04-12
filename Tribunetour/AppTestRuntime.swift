import Foundation

enum AppTestRuntime {
    static var isRunningAutomatedTests: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("--uitesting") ||
            processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
