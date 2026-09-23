import SwiftUI

@MainActor
struct InsightsBadgesView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let badges: [InsightsBadge]
    @State private var tier: BadgeTier = .launch
    @State private var selectedBadge: InsightsBadge?
    @State private var reveal = 0.0

    private var items: [InsightsBadge] { badges.filter { $0.tier == tier } }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text("Missions").font(.title3.bold())
                Spacer()
                Text("\(badges.filter(\.unlocked).count)/\(badges.count)")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Group {
                if typeSize.isAccessibilitySize {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:3),spacing:8) { tabs }
                } else {
                    HStack(spacing:4) { tabs }
                }
            }
            .accessibilityElement(children:.contain).accessibilityLabel("Mission tiers")
            tierHeader
            if let next = items.first(where:{ !$0.unlocked }) {
                Button { selectedBadge = next } label: {
                    HStack(spacing:10) {
                        SpaceBadgeSeal(badge:next,size:46,preview:true)
                        VStack(alignment:.leading,spacing:3) {
                            Text("Next: \(next.title)").font(.subheadline.weight(.semibold))
                            Text(next.requirement).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength:0)
                        Image(systemName:"chevron.right").font(.caption.weight(.semibold))
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityHint("Opens this mission")
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:90),spacing:8)],spacing:8) {
                ForEach(items) { badge in
                    Button { selectedBadge = badge } label: {
                        VStack(spacing:3) {
                            SpaceBadgeSeal(badge:badge,size:76,phase:badge.unlocked ? reveal : 0)
                            Text(badge.title).font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
                            Text(badge.unlocked ? String(localized: "badge.status.earned", defaultValue: "Earned") : String(localized: "Locked"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,minHeight:124).padding(.horizontal,4).padding(.vertical,6)
                        .background(badge.unlocked ? tier.tint.opacity(0.08) : palette.surface,
                                    in:RoundedRectangle(cornerRadius:14))
                        .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(tier.tint.opacity(badge.unlocked ? 0.25 : 0.08)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable).buttonPressHaptic(false)
                    .accessibilityLabel("\(badge.title), \(tier.title)")
                    .accessibilityValue(badge.unlocked ? String(localized: "badge.status.earned", defaultValue: "Earned") : badge.requirement)
                }
            }
            .id(tier)
        }
        .padding(14).card(palette)
        .hapticFeedback(.selection,trigger:tier)
        .hapticFeedback(.selection,trigger:selectedBadge?.id) { _,new in new != nil }
        .celebrationBlocked(by: selectedBadge != nil)
        .sheet(item:$selectedBadge) { selected in
            InsightsBadgeDetail(badge:badges.first { $0.id == selected.id } ?? selected)
        }
        .task(id:tier) {
            reveal = 0
            guard !reduceMotion, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
            withAnimation(.easeOut(duration:1.8)) { reveal = 1 }
        }
    }

    private var tabs: some View {
        ForEach(BadgeTier.allCases) { item in
            Button { tier = item } label: {
                VStack(spacing:5) {
                    TierMedal(tier:item,dimmed:item != tier,phase:item == tier ? reveal : 0)
                        .frame(width:44,height:44)
                    Text(item.title).font(.system(size:11,weight:.semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Capsule().fill(item == tier ? item.tint : .clear).frame(height:2)
                }
                .frame(maxWidth:.infinity).padding(.vertical,4)
                .background(item == tier ? item.tint.opacity(0.09) : .clear,in:RoundedRectangle(cornerRadius:10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("\(item.title), tier \(item.rawValue)")
            .accessibilityAddTraits(item == tier ? .isSelected : [])
            .accessibilityIdentifier("badges.tier.\(item.rawValue)")
        }
    }

    private var tierHeader: some View {
        HStack(spacing:14) {
            TierMedal(tier:tier,phase:reveal).frame(width:94,height:94)
            VStack(alignment:.leading,spacing:7) {
                Text(tier.title).font(.title2.bold()).foregroundStyle(tier.tint)
                Text(tier.caption).font(.caption).foregroundStyle(.white.opacity(0.75))
                ProgressView(value:Double(items.filter(\.unlocked).count),total:Double(max(1,items.count))).tint(tier.tint)
                Text("\(items.filter(\.unlocked).count) of \(items.count) earned")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength:0)
        }
        .padding(12).frame(maxWidth:.infinity,alignment:.leading)
        .background(Color(red:0.04,green:0.045,blue:0.09),in:RoundedRectangle(cornerRadius:18))
        .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(tier.tint.opacity(0.3)))
    }
}

@MainActor
private struct InsightsBadgeDetail: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let badge: InsightsBadge
    @State private var reveal = 0.0
    @State private var replay = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.center,spacing:12) {
                    SpaceBadgeSeal(badge:badge,size:184,phase:reveal,preview:true)
                        .padding(.vertical,14)
                        .frame(maxWidth:.infinity).background(Color(red:0.04,green:0.045,blue:0.09),in:RoundedRectangle(cornerRadius:22))
                    Text("\(badge.tier.title) / \(badge.mission.title)")
                        .font(.caption.weight(.semibold)).foregroundStyle(badge.tier.tint)
                    Text(badge.title).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(badge.requirement).multilineTextAlignment(.center)
                    Text(badge.progress).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    Label(badge.unlocked ? "Mission complete" : "Earn it through your real-world progress",
                          systemImage:badge.unlocked ? "checkmark.circle" : "lock")
                        .font(.caption).foregroundStyle(.secondary)
                    if !reduceMotion {
                        Button("Replay effect") { replay += 1 }.font(.subheadline.weight(.semibold)).frame(minHeight:44)
                    }
                    if badge.id.hasPrefix("collection") || badge.id.hasPrefix("home") || badge.id.hasPrefix("outfits") {
                        Text("Different purchases count. Free gifts don’t. No extra coins or XP.")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if ["streak","weekstreak","monthstreak"].contains(badge.id) {
                        Text("Locks again when your current streak ends.").font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }
            .background(palette.background).navigationTitle("Mission").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(badge.tier.tint).fontDesign(palette.fontDesign).presentationDetents([.large])
        .task(id:replay) {
            reveal = 0
            guard !reduceMotion, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
            withAnimation(.easeInOut(duration:2.4)) { reveal = 1 }
        }
    }
}
