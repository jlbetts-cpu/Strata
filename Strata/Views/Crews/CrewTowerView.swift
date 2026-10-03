import SwiftUI

/// A crew's tower for today.
///
/// Laid out the way a group thread is in Messages: back on the left, the
/// crew's faces in the middle with its name in a glass capsule under them,
/// and the page below is today's tower, drawn by the same blocks, lattice,
/// drop and dance as your own (`TowerBlocksForEach`).
///
/// A friend's win falls in while you watch. Every tenth win the tower dances.
/// Nothing else celebrates, and nothing counts anyone against anyone.
struct CrewTowerView: View {
    let crewID: CrewID
    var onBack: () -> Void

    @State private var model = CrewTowerModel()
    @State private var parking: CrewParking
    @State private var showsInfo = false
    @State private var openWin: SharedWin?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    init(crewID: CrewID, onBack: @escaping () -> Void) {
        self.crewID = crewID
        self.onBack = onBack
        _parking = State(initialValue: CrewParking(crewID: crewID))
    }

    private var store: SocialStore { SocialStore.shared }
    private var crew: Crew? { store.visible(crewID) }
    private let spacing = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let hPad = GridConstants.horizontalPadding

    var body: some View {
        GeometryReader { geo in
            let colW = floor((geo.size.width - hPad * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            tower(colW: colW, viewport: geo.size.height)
        }
        .background { WarmBackground().ignoresSafeArea().allowsHitTesting(false) }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        // Everyone's heads, over the header too, so one can be carried up
        // into the bubble. See `CrewHeadArena`.
        .overlay {
            if let crew {
                CrewHeadArena(crew: crew, me: store.me, model: model, parking: parking)
                    .ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onDisappear { if CrewNotifications.visibleCrew == crewID { CrewNotifications.visibleCrew = nil } }
        .onAppear {
            CrewNotifications.visibleCrew = crewID
            model.wire(reduceMotion: reduceMotion)
            #if DEBUG
            // `-strataCrewSheet info|win`: the crew's sheets, for captures.
            switch DebugHarness.argument("-strataCrewSheet") {
            case "info": showsInfo = true
            case "win": openWin = store.today(in: crewID).last { $0.senderProfileID != store.me }
            case "mine": openWin = store.today(in: crewID).last { $0.senderProfileID == store.me }
            default: break
            }
            // `-strataCrewParkEvery <s>`: a head goes into the bubble, or one
            // pops out, every s seconds, so both can be filmed.
            if let every = DebugHarness.argument("-strataCrewParkEvery").flatMap(Double.init) {
                Task { @MainActor in
                    var going = true
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(every))
                        guard let crew else { continue }
                        let free = crew.members.map(\.profileID).filter { !parking.isHidden($0) }
                        if going, let next = free.randomElement() {
                            parking.beginArrival(next, from: .zero)
                        } else if let out = parking.parked.randomElement() {
                            parking.pop(out)
                        }
                        if parking.parked.count >= 3 { going = false }
                        if parking.parked.isEmpty { going = true }
                    }
                }
            }
            #endif
            rebuild()
            store.markSeen(crewID)
        }
        .onChange(of: store.today(in: crewID)) { _, _ in
            rebuild()
            store.markSeen(crewID)
        }
        .onChange(of: crew?.members) { _, _ in rebuild() }
        // While the crew is on screen it stays current: a modest poll, since
        // a push is only a nudge to look and may never come.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                await store.refresh()
            }
        }
        .sheet(isPresented: $showsInfo) {
            if let crew { CrewInfoSheet(crewID: crew.id, onLeft: onBack) }
        }
        .sheet(item: $openWin) { win in
            CrewWinSheet(win: win, crewID: crewID)
        }
        .accessibilityAction(.escape) { onBack() }
    }

    private func rebuild() {
        let names = Dictionary(uniqueKeysWithValues: (crew?.members ?? []).map { ($0.profileID, $0.shortName) })
        model.rebuild(wins: store.today(in: crewID), me: store.me, names: names)
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                GlassIconButton(systemName: "chevron.left", onPage: true, accessibilityLabel: "Crews") { onBack() }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.controls["back"] = $0 }
                Spacer(minLength: 0)
                if let crew, crew.members.count < CrewCaps.members {
                    GlassIconButton(systemName: "person.badge.plus", onPage: true,
                                    accessibilityLabel: "Add People") {
                        Task { await CrewSharing.invite(crewID) }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.controls["add"] = $0 }
                }
            }
            if let crew {
                VStack(spacing: parking.parked.isEmpty ? -10 : -2) {
                    CrewBubble(crew: crew, me: store.me, parking: parking, side: 60)
                        .onTapGesture { if parking.parked.isEmpty { showsInfo = true } }
                        .accessibilityElement(children: parking.parked.isEmpty ? .ignore : .contain)
                        .accessibilityLabel(parking.parked.isEmpty ? "\(crew.displayName(excluding: store.me)), \(crew.members.count) people" : "The bubble")
                        .accessibilityAddTraits(parking.parked.isEmpty ? .isButton : [])
                        .accessibilityAction { if parking.parked.isEmpty { showsInfo = true } }
                        .zIndex(1)
                    Button { showsInfo = true } label: {
                        HStack(spacing: 4) {
                            Text(crew.displayName(excluding: store.me))
                                .font(Typography.headerSmall)
                                .foregroundStyle(AppColors.inkPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(Typography.headerSmall)
                                .imageScale(.small)
                                .foregroundStyle(AppColors.inkTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassCapsule(onPage: true)
                        .frame(maxWidth: 220)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.controls["name"] = $0 }
                    }
                    .buttonStyle(.pressSurface)
                    .accessibilityLabel("\(crew.displayName(excluding: store.me)), details")
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .padding(.horizontal, hPad)
        .padding(.top, GridConstants.gapTight)
        .padding(.bottom, GridConstants.gapTight)
    }

    // MARK: Tower

    private func tower(colW: CGFloat, viewport: CGFloat) -> some View {
        let tower = model.tower
        let rows = tower.totalRows
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let gridH = rows > 0 ? CGFloat(rows) * colW + CGFloat(rows - 1) * spacing : 0
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .allowsHitTesting(false)
                    .frame(width: gridW, height: max(gridH, 1))
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                        model.probe.gridTopOnScreen = rect.minY
                        model.probe.gridHeight = gridH
                        model.probe.cellSize = colW
                    }
                if rows > 0 {
                    TowerBlocksForEach(
                        visibleBlocks: tower.placedBlocks, animCoord: model.animation, towerVM: tower,
                        groupedIDs: [], mergeDestinedIDs: [],
                        colW: colW, gridH: gridH,
                        cornerRadius: GridConstants.cornerRadius, expandedBlockID: nil,
                        reduceMotion: reduceMotion, colorScheme: colorScheme,
                        onTapExpandBlock: { id in
                            openWin = store.today(in: crewID).first { $0.winID == id }
                        },
                        liftedBlockID: nil)
                }
            }
            .environment(\.blockLight, BlockLight.over(rows: max(rows, 1)))
            .background(alignment: .bottom) {
                TowerLattice(cellSize: colW, contentHeight: max(gridH, 1), ripple: model.latticeRipple)
                    .frame(width: gridW)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, GridConstants.gapWide)
            .frame(minHeight: viewport, alignment: .bottom)
        }
        .defaultScrollAnchor(.bottom)
        .softScrollEdge(.top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rows == 0 ? "No wins yet today" : "Today's crew tower, \(tower.placedBlocks.count) wins")
    }
}
