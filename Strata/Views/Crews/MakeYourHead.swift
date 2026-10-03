import SwiftUI

/// **The way into the head maker, from where heads are.** A friend of the
/// owner's opened a crew, saw heads walking about and never learned that one
/// of them could be theirs (2026-10-02). So a crew asks, in one pill at the
/// foot of its tower, for as long as you have no head and no longer: it is
/// the one moment the question answers itself, with your friends' heads on
/// screen beside it.
///
/// Your face in it is drawn from your friends' own: up to three of their
/// heads, then a dashed circle with a plus where yours will stand.
struct MakeYourHeadPill: View {
    let crew: Crew
    let me: UUID
    @State private var making = false

    var body: some View {
        Button {
            HapticsEngine.tick()
            making = true
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(Array(crew.others(than: me).prefix(3))) { member in
                        CrewFace(member: member, crew: crew.id, me: me, side: 28)
                            .overlay(Circle().strokeBorder(AppColors.quietFill, lineWidth: 1.5))
                    }
                    Image(systemName: "plus")
                        .font(Typography.headerSmall)
                        .imageScale(.small)
                        .foregroundStyle(AppColors.inkSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().strokeBorder(AppColors.inkTertiary,
                                                          style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                }
                Text("Make Your Head")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .frame(minHeight: 44)
            .glassCapsule(onPage: true, carriesType: true)
        }
        .buttonStyle(.pressSurface)
        .accessibilityLabel("Make your head")
        .accessibilityHint("Your crew sees it on their tower.")
        .fullScreenCover(isPresented: $making) { HeadMakerView() }
    }
}
