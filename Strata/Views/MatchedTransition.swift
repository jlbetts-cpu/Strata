import SwiftUI

extension View {
    /// `matchedTransitionSource` wants a real namespace; this is the version
    /// that tolerates not having one, so a caller that does not animate is not
    /// forced to invent a namespace it never uses.
    ///
    /// Shared, because more than one page opens something out of the thing you
    /// touched: a photograph out of its thumbnail, a day's album out of its
    /// block on the month tower. One copy, so those two never drift into
    /// behaving differently.
    @ViewBuilder
    func matchedTransitionSource(id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
