import Foundation

/// The crews your last win went to, which is what the next one goes to.
///
/// **Sticky, and never asked.** Recording a win must stay the fastest thing in
/// the app, so there is no "share with?" step: the checkboxes start where you
/// left them, and a one-tap win simply uses them (the owner, 2026-10-02).
nonisolated enum CrewChoice {
    static let key = "crews.lastChoice"

    static func load(_ defaults: UserDefaults = .standard) -> Set<CrewID> {
        Set((defaults.stringArray(forKey: key) ?? []).map(CrewID.init(rawValue:)))
    }

    static func save(_ choice: Set<CrewID>, _ defaults: UserDefaults = .standard) {
        defaults.set(choice.map(\.rawValue).sorted(), forKey: key)
    }

    /// A crew you left drops out, so a later win cannot be aimed at it.
    static func forget(_ crew: CrewID, _ defaults: UserDefaults = .standard) {
        var choice = load(defaults)
        choice.remove(crew)
        save(choice, defaults)
    }
}
