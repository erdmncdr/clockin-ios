import SwiftUI

/// The level-up moment, staged the way MOBAs and MMORPGs stage it: energy
/// gathers, the new level lands in a column of light, then the rewards follow
/// one by one. A new rank adds a second beat. See docs/level-up-design.md.
struct LevelUpCard: View {
    let level: Int
    let hours: Int
    var xp = 0
    let moving: Bool
    let companionEnabled: Bool
    let dismiss: () -> Void
    let share: () -> Void
    #if DEBUG
    /// Holds the whole card at one moment, for reviewing single frames.
    var pinnedTime: Double?
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title) private var bannerSize = 25
    @State private var began = Date.now
    @State private var settled = false
    private typealias C = LevelUpCurve
    private var style: LevelPrestige { .init(level: level) }
    private var nextStyle: LevelPrestige { .init(level: style.nextUnlock) }
    /// A new rank levels up in the old rank's colours; the new ones take over
    /// on the second beat.
    private func shown(_ t: Double) -> LevelPrestige {
        style.isMilestone && t < LevelUpTiming.rankReveal ? .init(level: max(1, level - 1)) : style
    }
    /// How far the new rank's colours have taken over, 0 to 1.
    private func takeover(_ t: Double) -> Double {
        style.isMilestone ? C.ramp(t, LevelUpTiming.rankReveal, LevelUpTiming.rankReveal + 0.35) : 1
    }
    private var motion: Bool {
        animationPolicy.allowsAnimation(reduceMotion: reduceMotion, contentActive: moving,
                                       sceneActive: scenePhase == .active, visible: true)
    }
    /// The rank row lands after the level, or on its own beat for a new rank.
    private var rankBeat: Double { style.isMilestone ? LevelUpTiming.rankReveal : LevelUpTiming.impact + 0.75 }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }.scrollBounceBehavior(.basedOnSize)
            }
            clock { t in
                actions.opacity(0.25 + 0.75 * C.ramp(t, rankBeat + 0.2, rankBeat + 0.6))
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            clock { t in
                ZStack {
                    if style.isMilestone {
                        LevelUpBackdrop(stage: LevelPrestige(level: level - 1).stage).equatable()
                    }
                    LevelUpBackdrop(stage: style.stage).equatable().opacity(takeover(t))
                }
            }
            .ignoresSafeArea()
        }
        .onAppear { began = .now }
        .task {
            // Everything but the stage has landed by now; stop redrawing it.
            do { try await Task.sleep(for: .seconds(rankBeat + 1.2)) } catch { return }
            settled = true
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            stage
            clock { t in banner(t) }.padding(.horizontal, 20)
            clock { t in xpBar(t) }.padding(.horizontal, 36).padding(.top, 16)
            clock { t in rank(t) }.padding(.horizontal, 22).padding(.top, 18)
            // The last rank has no next look to show.
            if style.stage < 8 {
                clock { t in next(t) }.padding(.horizontal, 22).padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Seconds since the card appeared, for the text and panels. They stop
    /// updating once everything has landed; the stage keeps its own clock.
    private func clock<Content: View>(@ViewBuilder _ content: @escaping (Double) -> Content) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !motion || settled)) { context in
            content(time(at: context.date, settled: settled))
        }
    }

    private func time(at date: Date, settled: Bool) -> Double {
        #if DEBUG
        if let pinnedTime { return pinnedTime }
        #endif
        return motion && !settled ? max(0, date.timeIntervalSince(began)) : C.still
    }

    private var stage: some View {
        TimelineView(.animation(minimumInterval: settled ? 1 / 30 : 1 / 60, paused: !motion)) { context in
            LevelUpStage(level: level, t: time(at: context.date, settled: false), companion: companionEnabled,
                         moving: motion)
        }
    }

    // MARK: Banner

    private func banner(_ t: Double) -> some View {
        let post = t - LevelUpTiming.impact
        let p = C.ramp(post, 0.05, 0.4)
        let e = C.easeOut(p)
        let rule = C.easeOut(C.ramp(post, 0.15, 0.6))
        let title = String(localized: "Level up", bundle: .app).uppercased(with: AppLanguage.locale)
        let colors = shown(t)
        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                LevelUpRule(style: colors, leading: true).frame(maxWidth: 56).scaleEffect(x: rule, anchor: .trailing)
                ZStack {
                    if style.isMilestone { bannerTitle(title, style: .init(level: max(1, level - 1)), shown: e) }
                    bannerTitle(title, style: style, shown: e).opacity(takeover(t))
                }
                .scaleEffect(1 + 0.35 * (1 - e))
                LevelUpRule(style: colors, leading: false).frame(maxWidth: 56).scaleEffect(x: rule, anchor: .leading)
            }
            Text(hours == 1 ? "1 hour of focus" : "\(hours.formatted(.number.locale(AppLanguage.formatLocale))) hours of focus")
                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                .opacity(C.ramp(post, 0.3, 0.7))
        }
        .opacity(p > 0 ? min(1, p * 4) : 0)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Level up", bundle: .app) + ", " + String(localized: "Level \(level)", bundle: .app))
        .accessibilityAddTraits(.isHeader)
    }

    private func bannerTitle(_ title: String, style: LevelPrestige, shown e: Double) -> some View {
        // The title is decoration over the crest; the card's heading for
        // assistive technologies is the label on the banner.
        Text(verbatim: title)
            .font(.system(size: min(bannerSize, 34), weight: .heavy).width(.expanded))
            .tracking(1.5 + 9 * (1 - e))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .foregroundStyle(LinearGradient(colors: [.white, style.highlight, style.tint],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.6), radius: 0, y: 2)
            .shadow(color: style.tint.opacity(0.55 * e), radius: 12)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: XP bar

    /// The bar fills to the end during the charge, flashes on the impact, then
    /// empties and refills to the XP carried into the new level.
    private func xpBar(_ t: Double) -> some View {
        let post = t - LevelUpTiming.impact
        let carried = LevelPrestige.progress(xp: xp)
        let start = 0.8
        // A new rank holds the full bar until its own beat.
        let refill = style.isMilestone ? LevelUpTiming.rankReveal + 0.1 - LevelUpTiming.impact : 0.5
        let fill: Double
        let barLevel: Int
        if post < 0 {
            fill = start + (1 - start) * C.easeInOut(C.ramp(t, 0.1, LevelUpTiming.impact))
            barLevel = max(1, level - 1)
        } else if post < refill - 0.1 {
            fill = 1
            barLevel = max(1, level - 1)
        } else {
            fill = carried * C.easeOut(C.ramp(post, refill, refill + 0.8))
            barLevel = level
        }
        let flash = post < 0 ? 0 : exp(-post * 5)
        return VStack(spacing: 7) {
            HStack {
                Text("XP").font(.caption.weight(.semibold)).foregroundStyle(shown(t).highlight.opacity(0.8))
                Spacer()
                Text(verbatim: "\(Int((fill * 500).rounded())) / 500")
                    .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
            }
            PrestigeProgressBar(level: barLevel, progress: fill, height: 12)
                .overlay {
                    Capsule().fill(.white).opacity(0.75 * flash).blendMode(.plusLighter)
                }
                .shadow(color: shown(t).tint.opacity(0.8 * flash), radius: 10)
        }
        .opacity(C.ramp(t, 0.05, 0.3))
    }

    // MARK: Rewards

    private func rank(_ t: Double) -> some View {
        let p = C.ramp(t, rankBeat, rankBeat + 0.45)
        let landed = C.land(p)
        let milestone = style.isMilestone
        let badge = LevelBadge(level: level, xp: xp, active: motion)
            .scaleEffect(milestone ? 0.55 + 0.45 * landed : 1)
            .overlay {
                if milestone && motion {
                    PrestigeUnlockBurst(style: style, elapsed: t - rankBeat).frame(width: 220, height: 160)
                }
            }
        let heading = (milestone ? String(localized: "New rank unlocked", bundle: .app) : String(localized: "Rank", bundle: .app))
            .uppercased(with: AppLanguage.locale)
        func name(_ alignment: HorizontalAlignment) -> some View {
            VStack(alignment: alignment, spacing: 2) {
                Text(style.name).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(.white)
                Text(style.detail).font(.caption).foregroundStyle(.white.opacity(0.55))
            }
        }
        // Everything in the panel sits on its centre line, under a titled rule.
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                LevelUpRule(style: style, leading: true).frame(maxWidth: 40)
                Text(verbatim: heading)
                    .font(.caption2.weight(.bold)).tracking(1.4)
                    .foregroundStyle(style.highlight.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                LevelUpRule(style: style, leading: false).frame(maxWidth: 40)
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) { badge; name(.center) }
            } else {
                HStack(spacing: 14) {
                    badge
                    name(.leading).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background { LevelUpPanel(style: style, glow: milestone ? exp(-max(0, t - rankBeat) * 2.5) * (p > 0 ? 1 : 0) : 0) }
        .opacity(min(1, p * 3))
        .offset(y: 12 * (1 - C.easeOut(p)))
        .accessibilityElement(children: .combine)
    }

    private func next(_ t: Double) -> some View {
        let p = C.ramp(t, rankBeat + 0.2, rankBeat + 0.6)
        return HStack(spacing: 10) {
            PrestigeInsignia(style: nextStyle).frame(width: 19, height: 22).opacity(0.6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Next look · \(nextStyle.name)").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.72))
                Text("\(style.nextUnlock - level) levels to go").font(.caption2).foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 8)
            Text("LV \(style.nextUnlock)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(nextStyle.highlight.opacity(0.75))
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background { LevelUpPanel(style: style, glow: 0).opacity(0.7) }
        .opacity(min(1, p * 2))
        .offset(y: 10 * (1 - C.easeOut(p)))
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 4) {
            Button(action: dismiss) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Color(red: 0.025, green: 0.04, blue: 0.07))
                    .background(LinearGradient(colors: [style.highlight, style.tint], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .top) {
                        // The lit top edge of a pressed metal plate.
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.7), .clear, .black.opacity(0.25)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    }
                    .shadow(color: style.tint.opacity(0.35), radius: 12, y: 4)
            }.accessibilityIdentifier("celebration.continue")
            Button(action: share) {
                Label("Share milestone", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityIdentifier("celebration.share")
        }.buttonStyle(.plain).buttonPressHaptic(false)
    }
}

/// A banner rule: a line that fades in from the outside and ends in a small
/// diamond beside the title.
private struct LevelUpRule: View {
    let style: LevelPrestige
    let leading: Bool
    var body: some View {
        HStack(spacing: 3) {
            if !leading { diamond }
            Rectangle()
                .fill(LinearGradient(colors: [.clear, style.highlight.opacity(0.8)],
                                     startPoint: leading ? .leading : .trailing, endPoint: leading ? .trailing : .leading))
                .frame(height: 1.2)
            if leading { diamond }
        }
        .accessibilityHidden(true)
    }
    private var diamond: some View {
        Rectangle().fill(style.highlight).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            .shadow(color: style.tint, radius: 4)
    }
}

/// The dark reward panel with a thin rank-coloured edge, lit from the top.
private struct LevelUpPanel: View {
    let style: LevelPrestige
    let glow: Double
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [style.shade.opacity(0.35), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient(colors: [style.highlight.opacity(0.45 + 0.5 * glow), style.tint.opacity(0.08)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .shadow(color: style.tint.opacity(0.6 * glow), radius: 16)
    }
}

/// Deep space behind the level-up, lit in the rank's colour from where the
/// crest hangs.
private struct LevelUpBackdrop: View, Equatable {
    let stage: Int
    var body: some View {
        Canvas { context, size in
            let style = LevelPrestige(level: max(1, stage * LevelPrestige.interval))
            let all = Path(CGRect(origin: .zero, size: size))
            context.fill(all, with: .linearGradient(
                Gradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.08), Color(red: 0.01, green: 0.014, blue: 0.03)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let focus = CGPoint(x: size.width / 2, y: size.height * 0.2)
            context.fill(all, with: .radialGradient(Gradient(colors: [style.shade.opacity(0.6), style.shade.opacity(0.14), .clear]),
                                                    center: focus, startRadius: 0, endRadius: size.height * 0.55))
            for (i, spot) in [(0.18, 0.12, 0.9), (0.86, 0.3, 0.7), (0.3, 0.62, 0.6)].enumerated() {
                let c = CGPoint(x: size.width * spot.0, y: size.height * spot.1)
                let r = size.width * spot.2
                context.fill(all, with: .radialGradient(Gradient(colors: [style.tint.opacity(i == 0 ? 0.07 : 0.05), .clear]),
                                                        center: c, startRadius: 0, endRadius: r))
            }
            for i in 0..<120 {
                let x = LevelUpCurve.noise(i, 31) * size.width
                let y = LevelUpCurve.noise(i, 32) * size.height
                let big = LevelUpCurve.noise(i, 33) > 0.9
                let r: CGFloat = big ? 1.3 : 0.6
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.15 + 0.45 * LevelUpCurve.noise(i, 34))))
            }
            context.fill(all, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.55)]),
                                                    center: CGPoint(x: size.width / 2, y: size.height * 0.4),
                                                    startRadius: size.height * 0.3, endRadius: size.height * 0.8))
        }
        .accessibilityHidden(true)
    }
}
