#if DEBUG
import SwiftUI
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Renders the widget at its real sizes, from `-strataRenderWidget`.
///
/// **Because nothing on this machine can add a widget to a home screen.**
/// The widget's views are the one part of the app that a simulator screenshot
/// cannot reach — they run in another process, placed by a gesture. So they
/// are rendered here instead, at the point sizes iOS actually gives a widget,
/// with the same `widgetFamily` in the environment.
///
/// This is a photograph of the view, not proof of the extension: it says the
/// layout is right, not that WidgetKit will load the appex. Those are two
/// different claims and only the first is being made.
enum WidgetPreviewRenderer {

    /// Point sizes for a 6.3" iPhone. Widgets are laid out in points and
    /// scaled by the device, so these are the numbers the views see.
    private static let sizes: [(String, CGSize, WidgetFamily)] = [
        ("small", CGSize(width: 170, height: 170), .systemSmall),
        ("medium", CGSize(width: 364, height: 170), .systemMedium),
        ("lock", CGSize(width: 160, height: 72), .accessoryRectangular)
    ]

    static func run(snapshot: WidgetSnapshot) {
        for scheme in [ColorScheme.light, .dark] {
            for (name, size, family) in sizes {
                let view = ZStack {
                    if family == .accessoryRectangular {
                        Color.black
                    } else {
                        WidgetGround()
                    }
                    TowerWidgetView(snapshot: snapshot, forcedFamily: family)
                        .padding(family == .accessoryRectangular ? 0 : 14)
                }
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, scheme)
                .foregroundStyle(family == .accessoryRectangular ? .white : .primary)

                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                guard let image = renderer.uiImage,
                      let data = image.pngData() else { continue }
                let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("widget-\(name)-\(scheme == .dark ? "dark" : "light").png")
                try? data.write(to: url)
                NSLog("[strata-widget] wrote \(url.lastPathComponent)")
            }
        }
        NSLog("[strata-widget] done")
    }

    static var isRequested: Bool { DebugHarness.argument("-strataRenderWidget") != nil }
}
#endif
