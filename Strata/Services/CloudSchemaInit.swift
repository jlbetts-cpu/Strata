#if DEBUG
import CoreData
import SwiftData
import UIKit

/// **Writes the store's whole CloudKit schema to Development, once** (found
/// 2026-10-08: the Development and Production schemas of
/// iCloud.JaydenBetts.Strata held the crews' types and not one `CD_` type, so
/// the wins' iCloud mirror has never been able to export from a TestFlight or
/// App Store build: Production refuses a record type it has never seen, and a
/// type only reaches Development when a debug build with an iCloud account
/// writes it).
///
/// Run a debug build ON A PHONE signed in to iCloud, with the launch argument
/// `-strataInitCloudSchema 1` (Xcode > Edit Scheme > Run > Arguments). It builds
/// a throwaway Core Data container over the same model as `SharedModelContainer`
/// and asks CloudKit to create every record type and field it would ever
/// write, including `WinPhoto`. Then, in the CloudKit Console, Deploy Schema
/// Changes moves them to Production. It never touches the real store.
enum CloudSchemaInit {
    static var isAsked: Bool { ProcessInfo.processInfo.arguments.contains("-strataInitCloudSchema") }

    /// The outcome, said in a line, for the alert and the console.
    static func run() async -> String {
        let types: [any PersistentModel.Type] = [Habit.self, HabitLog.self, MoodLog.self, Tower.self,
                                                 PlanFolder.self, PlanItem.self, WinPhoto.self]
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: types) else {
            return "Could not build the model."
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "cloud-schema-init-\(UUID().uuidString).sqlite")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: SharedModelContainer.cloudKitContainerID)
        let container = NSPersistentCloudKitContainer(name: "CloudSchemaInit", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        let loaded: Error? = await withCheckedContinuation { done in
            container.loadPersistentStores { _, error in done.resume(returning: error) }
        }
        if let loaded { return "The throwaway store did not open: \(loaded.localizedDescription)" }
        do {
            try container.initializeCloudKitSchema(options: [])
            return "Done. Every record type is in Development. Now deploy it to Production in the CloudKit Console."
        } catch {
            return "CloudKit refused: \(error.localizedDescription) (is this phone signed in to iCloud?)"
        }
    }

    /// Runs it and says the outcome on screen, so nobody has to read a console.
    @MainActor
    static func runAndShow() {
        Task {
            let line = await run()
            NSLog("[cloud-schema] %@", line)
            let alert = UIAlertController(title: "iCloud schema", message: line, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            let root = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController
            var top = root
            while let next = top?.presentedViewController { top = next }
            top?.present(alert, animated: true)
        }
    }
}
#endif
