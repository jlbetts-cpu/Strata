import AppIntents

/// **Log a win from outside the app**: Control Center, the Lock Screen, the
/// Action button and the Log widget (the owner picked it from the 2026-10-05
/// research: forgetting and upkeep are why people stop tracking, and the
/// fastest log is the one that never opens the app).
///
/// **It runs in the APP's process, never the widget's.** The widget target
/// has no SwiftData schema and a few tens of megabytes (`StrataWidget`'s
/// founding note), so it cannot write a win. An intent that is in both
/// targets AND is a `LiveActivityIntent` is performed by the app, launched in
/// the background if it is not running; the widget only holds the button.
/// Nothing here starts a Live Activity: the protocol is Apple's route for an
/// intent that must reach the app without bringing it forward.
///
/// The app hands over the work at launch (`QuickLog.handler`), because the
/// code that logs a win lives in the app target and cannot be named here.
///
/// **One intent per size, with no parameters.** A widget button's intent
/// carried its size as a parameter and it arrived in the app as the default
/// every time (measured on the simulator, 2026-10-05: Deep and Regular both
/// logged Quick). Three types with the size built in leave nothing to lose
/// on the way.
protocol QuickLogIntent: LiveActivityIntent {
    static var size: QuickLogSize { get }
}

extension QuickLogIntent {
    static var description: IntentDescription { IntentDescription("Adds a win to today's tower.") }
    /// Shortcuts and Siri already have "Log a Win" with a name
    /// (`LogWinIntent`); these are the controls' and the widget's buttons.
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        try await QuickLog.run(Self.size)
        return .result()
    }
}

struct LogQuickWinIntent: QuickLogIntent {
    static let title: LocalizedStringResource = "Log a Quick Win"
    static let size = QuickLogSize.quick
    init() {}
}

struct LogRegularWinIntent: QuickLogIntent {
    static let title: LocalizedStringResource = "Log a Regular Win"
    static let size = QuickLogSize.regular
    init() {}
}

struct LogDeepWinIntent: QuickLogIntent {
    static let title: LocalizedStringResource = "Log a Deep Win"
    static let size = QuickLogSize.deep
    init() {}
}

/// A block's three sizes, by the names the app gives them.
enum QuickLogSize: String, Sendable {
    case quick, regular, deep
}

/// Where the app plugs in the logging. Nil in the widget's process, which
/// never performs the intent.
@MainActor
enum QuickLog {
    static var handler: ((QuickLogSize) async throws -> Void)?

    static func run(_ size: QuickLogSize) async throws {
        guard let handler else { throw QuickLogError.notReady }
        try await handler(size)
    }
}

enum QuickLogError: Error, CustomLocalizedStringResourceConvertible {
    case notReady
    var localizedStringResource: LocalizedStringResource { "Open Some Wins once, then try again." }
}
