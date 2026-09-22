import SwiftUI

#if DEBUG
/// **Every face at once, so the set can be judged as a set.**
///
/// Reached with `-strataFolderLab 1`. It exists for the same reason the film
/// look contact sheet does: a single expression looks fine on its own and the
/// only question that matters is whether the eight read apart from each other
/// and belong to the same face.
///
/// Not shipped. It is behind `#if DEBUG` and a launch argument.
struct FolderLabView: View {
    @State private var mood = 0
    @State private var tint = 0
    @State private var engine = FolderMood(contents: FolderContents(count: 12))
    /// The live folder is driven by EVENTS, so the logic and the glide can be
    /// watched rather than reasoned about. The grid below is still faces.
    @State private var drivenByEvents = true

    private static let tints: [(String, Color)] = [
        ("Default", WinFolder.defaultTint),
        ("Warm", Color(red: 0.60, green: 0.42, blue: 0.34)),
        ("Violet", Color(red: 0.47, green: 0.40, blue: 0.72)),
        ("Sage", Color(red: 0.40, green: 0.50, blue: 0.42))
    ]

    private var photos: [UIImage] {
        ["LookPreview", "DemoPhoto4", "DemoPhoto11"].compactMap { UIImage(named: $0) }
    }

    var body: some View {
        ZStack {
            Grey.g950.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // The one that is alive, big, to watch it idle.
                    WinFolder(title: "Today", count: engine.contents.count,
                              tint: Self.tints[tint].1,
                              contents: photos,
                              expression: drivenByEvents ? engine.expression
                                                         : FaceExpression.all[mood].1,
                              isAlive: true)
                        .frame(width: 260)
                        .padding(.top, 24)

                    events

                    controls

                    Divider().overlay(Grey.g800)

                    // All eight, still, so the set is judged as a set.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                              spacing: 20) {
                        ForEach(FaceExpression.all, id: \.0) { name, face in
                            VStack(spacing: 8) {
                                WinFolder(title: name, count: 12,
                                          tint: Self.tints[tint].1,
                                          contents: photos,
                                          expression: face,
                                          isAlive: false)
                                Text(name)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(Grey.g400)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// The logic, driven by hand. Every button here is something a person
    /// does; there is no button for time passing, because nothing in the
    /// system listens for it.
    private var events: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                eventButton("Add win", .winAdded) { engine.contents.count += 1 }
                eventButton("Rush", .winRush) { engine.contents.count += 4 }
                eventButton("Shake", .shaken)
                eventButton("Poke", .poked)
            }
            HStack(spacing: 8) {
                eventButton("Hover", .winHovering)
                eventButton("Drop it", .hoverEnded)
                eventButton("Open", .opened)
                eventButton("Empty", .closed) { engine.contents.count = 0 }
            }
        }
    }

    private func eventButton(_ name: String, _ event: FolderEvent,
                             _ also: (() -> Void)? = nil) -> some View {
        Button(name) {
            HapticsEngine.tick()
            also?()
            engine.react(to: event)
            drivenByEvents = true
        }
        .font(Typography.bodySmall)
        .foregroundStyle(Grey.g200)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Capsule().fill(Grey.g900))
        .buttonStyle(.pressWord)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(FaceExpression.all.enumerated()), id: \.offset) { index, item in
                    Button(item.0) {
                        drivenByEvents = false
                        withAnimation(FolderMood.glide) { mood = index }
                    }
                    .font(Typography.bodySmall)
                    .foregroundStyle(mood == index ? .white : Grey.g500)
                    .buttonStyle(.pressWord)
                }
            }
            HStack(spacing: 10) {
                ForEach(Array(Self.tints.enumerated()), id: \.offset) { index, item in
                    Button {
                        withAnimation(GridConstants.motionSnappy) { tint = index }
                    } label: {
                        Circle()
                            .fill(item.1)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(.white.opacity(tint == index ? 0.9 : 0.15),
                                                           lineWidth: 2))
                    }
                    .buttonStyle(.press)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
