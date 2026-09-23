import SwiftUI

/// **How one day's folder is dressed.**
///
/// The owner: "make sure the folders are customisable, you are able to change
/// the colour, add the various faces (face off by default)."
///
/// Two fields and nothing else, because those are the two he asked for and a
/// third would be a setting nobody opened. A face is stored as an expression
/// NAME rather than as a `FaceExpression`, so the rig is free to retune what
/// "delighted" looks like without every folder already wearing it turning
/// into a different feeling overnight.
struct FolderStyle: Equatable, Codable {
    /// Empty means "whatever this day was dealt" — see `FolderTint.seeded`.
    /// Storing the seeded id instead would freeze a colour nobody chose, so
    /// retuning the palette would leave old folders on the old values.
    var tintID: String = ""
    /// Nil is no face, which is the default. See `WinFolder.showsFace`.
    var faceName: String? = nil

    func tint(for dateString: String) -> Color {
        tintID.isEmpty ? FolderTint.seeded(for: dateString).colour
                       : FolderTint.tint(id: tintID).colour
    }

    var expression: FaceExpression {
        guard let faceName else { return .idle }
        return FaceExpression.all.first { $0.0 == faceName }?.1 ?? .idle
    }

    static let `default` = FolderStyle()
}

/// **Where a folder's dress lives, keyed by the day it belongs to.**
///
/// `UserDefaults` rather than SwiftData, and that is deliberate: this is
/// preference, not record. Losing it costs somebody a colour they picked;
/// putting it in the store would mean a schema migration and a CloudKit
/// field for something that has no meaning on another device and no meaning
/// in a year. The win itself is the data; this is how it is painted.
///
/// **One blob, not a key per day.** A key per day leaves `UserDefaults`
/// holding a row for every day the app has ever been open, with nothing that
/// ever cleans them up. One dictionary is one read at launch, one write when
/// something changes, and `prune` can bound it.
@Observable
final class FolderStyleStore {
    private static let defaultsKey = "apollo.folderStyles.v1"
    /// How many days of dressing to keep. A folder older than this is not on
    /// the Recents row and is not reachable, so its colour is dead weight.
    private static let keepDays = 120

    private(set) var styles: [String: FolderStyle] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([String: FolderStyle].self, from: data) {
            styles = decoded
        }
    }

    func style(for dateString: String) -> FolderStyle {
        styles[dateString] ?? .default
    }

    func set(_ style: FolderStyle, for dateString: String) {
        if style == .default {
            // A folder put back to the default keeps no row. The store only
            // ever holds choices somebody actually made.
            styles.removeValue(forKey: dateString)
        } else {
            styles[dateString] = style
        }
        persist()
    }

    /// Drops dressing for days that are no longer reachable.
    func prune(before cutoff: String) {
        let stale = styles.keys.filter { $0 < cutoff }
        guard !stale.isEmpty else { return }
        for key in stale { styles.removeValue(forKey: key) }
        persist()
    }

    /// The cutoff `prune` wants, given a day to count back from.
    static func cutoff(from today: Date, calendar: Calendar = .current) -> String {
        let day = calendar.date(byAdding: .day, value: -keepDays, to: today) ?? today
        return DateUtils.dateString(from: day)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(styles) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
