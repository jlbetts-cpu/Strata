import Foundation
import CoreData
import SwiftData

/// CloudKit's rules on a schema, checked by reading the schema.
///
/// **Why this exists when the real validator exists.** The real one is inside
/// `NSPersistentCloudKitContainer`, it only runs when a mirroring container
/// loads, and loading one needs the iCloud entitlement and a container that
/// exists. So the only place it can run is on a signed build on a device or
/// simulator, which means the answer arrives at the end of a build and install
/// rather than in a test. Worse, SwiftData throws its own
/// `loadIssueModelContainer` with the reason stripped out, so "it threw" is all
/// you get: a missing entitlement and a broken schema look identical.
/// `CloudKitValidatorProbe` in the test suite goes around that by driving Core
/// Data directly, and it is opt in for exactly those reasons.
///
/// This reads the same managed object model the mirroring container would have
/// read, and applies the same rules, in a plain unit test, with no entitlement,
/// no container and no network. It is not a replacement for the validator. It
/// is the thing that fails in eight seconds instead of eight minutes, and it
/// names the property.
///
/// The rules are Apple's, and every one of them has already bitten this schema
/// once: thirty one attributes had no default, and four to-many relationships
/// were not optional because a Swift array with a default looks optional and to
/// Core Data is not.
enum StoreSchemaRules {

    /// One property that CloudKit would refuse, named well enough to fix
    /// without reading anything else.
    struct Violation: Equatable, Sendable, CustomStringConvertible {
        let entity: String
        let property: String
        let rule: String

        var description: String { "\(entity).\(property): \(rule)" }
    }

    /// Every rule, so a report can say what was checked rather than only what
    /// failed. A checker that silently checks nothing passes everything.
    enum Rule: String, CaseIterable, Sendable {
        case attributeNeedsDefault = "a non optional attribute must have a default value"
        case relationshipMustBeOptional = "a relationship must be optional"
        case relationshipNeedsInverse = "a relationship must have an inverse"
        case relationshipMustNotBeOrdered = "a relationship must not be ordered"
        case relationshipMustNotDeny = "a relationship must not use the deny delete rule"
        case entityMustNotBeUnique = "an entity must not have a unique constraint"
    }

    /// - Returns: every violation, sorted, so two runs read the same. Empty
    ///   means the schema satisfies all six rules.
    static func violations(in types: [any PersistentModel.Type]) -> [Violation] {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: types) else {
            return [Violation(entity: "the schema", property: "itself",
                              rule: "could not be turned into a managed object model at all")]
        }
        return violations(in: model)
    }

    static func violations(in model: NSManagedObjectModel) -> [Violation] {
        var found: [Violation] = []

        for entity in model.entities {
            let name = entity.name ?? "an unnamed entity"

            // A unique constraint is how Core Data would normally stop the
            // duplicate rows that a first sync creates, and mirroring refuses
            // it outright. `StoreDedupe` is this app's answer instead.
            if !entity.uniquenessConstraints.isEmpty {
                let described = entity.uniquenessConstraints
                    .map { $0.map { "\($0)" }.joined(separator: "+") }
                    .joined(separator: ", ")
                found.append(Violation(entity: name, property: described,
                                       rule: Rule.entityMustNotBeUnique.rawValue))
            }

            for (property, attribute) in entity.attributesByName {
                // The rule that broke thirty one properties on this schema:
                // when a record arrives from another device without a field,
                // mirroring has to put something in the column, and a non
                // optional attribute with no default leaves it nothing to put.
                if !attribute.isOptional, attribute.defaultValue == nil {
                    found.append(Violation(entity: name, property: property,
                                           rule: Rule.attributeNeedsDefault.rawValue))
                }
            }

            for (property, relationship) in entity.relationshipsByName {
                // A to-many written as `var logs: [HabitLog] = []` reads as
                // optional in Swift and is a MANDATORY relationship to Core
                // Data. That is why this rule is checked by machine.
                if !relationship.isOptional {
                    found.append(Violation(entity: name, property: property,
                                           rule: Rule.relationshipMustBeOptional.rawValue))
                }
                if relationship.inverseRelationship == nil {
                    found.append(Violation(entity: name, property: property,
                                           rule: Rule.relationshipNeedsInverse.rawValue))
                }
                if relationship.isOrdered {
                    found.append(Violation(entity: name, property: property,
                                           rule: Rule.relationshipMustNotBeOrdered.rawValue))
                }
                if relationship.deleteRule == .denyDeleteRule {
                    found.append(Violation(entity: name, property: property,
                                           rule: Rule.relationshipMustNotDeny.rawValue))
                }
            }
        }

        return found.sorted { $0.description < $1.description }
    }

    /// How many entities and properties were actually looked at.
    ///
    /// **So that a passing check cannot be a check of nothing.** If
    /// `makeManagedObjectModel` ever returns a model with no entities, or a
    /// model whose attributes are not where this code looks for them, every
    /// rule above passes and the schema is declared CloudKit legal without a
    /// single value having been read. The test asserts these counts.
    struct Coverage: Equatable, Sendable {
        var entities = 0
        var attributes = 0
        var relationships = 0
    }

    static func coverage(in types: [any PersistentModel.Type]) -> Coverage {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: types) else { return Coverage() }
        var counted = Coverage()
        for entity in model.entities {
            counted.entities += 1
            counted.attributes += entity.attributesByName.count
            counted.relationships += entity.relationshipsByName.count
        }
        return counted
    }
}
