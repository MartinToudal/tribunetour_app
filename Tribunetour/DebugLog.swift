import Foundation

/// Debug-only logging helper.
/// - In DEBUG builds: prints the message.
/// - In Release/TestFlight/App Store: compiled out.
@inline(__always)
func dlog(_ message: @autoclosure () -> String) {
#if DEBUG
    print(message())
#endif
}

@inline(__always)
func dlogFixturesLoad(source: FixturesLoadResult.Source, version: String?, reason: String? = nil) {
#if DEBUG
    var message = "📦 Fixtures load source=\(source.rawValue)"
    if let version {
        message += ", version=\(version)"
    }
    if let reason, !reason.isEmpty {
        message += ", reason=\(reason)"
    }
    print(message)
#endif
}
