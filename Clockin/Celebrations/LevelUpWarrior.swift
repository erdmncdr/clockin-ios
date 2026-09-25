import SwiftUI

/// The companion as a space warrior for the level-up, in the pose MMORPG
/// heroes strike: sword planted in front, both hands on the hilt, cape behind.
/// The armour is blued steel trimmed in the rank's metal, the energy is the
/// rank's colour, and the companion's own face looks out through the visor.
/// The blade is dark steel during the charge and ignites on the impact.
struct LevelUpWarrior: View {
    let style: LevelPrestige
    let t: Double
    static let size = CGSize(width: 180, height: 210)
    /// The visor, in the warrior's own coordinates.
    private static let visor = CGRect(x: 58, y: 34, width: 64, height: 40)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in LevelUpWarriorArt.draw(&context, style: style, t: t) }
            ClockinMascotStill(mood: .hello, maxPixelSize: 314)
                .frame(width: 236, height: 236)
                .position(x: Self.visor.midX - 6.5, y: Self.visor.midY + 32)
                .mask(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .frame(width: Self.visor.width - 6, height: Self.visor.height - 6)
                        .offset(x: Self.visor.minX + 3, y: Self.visor.minY + 3)
                }
            Canvas { context, _ in LevelUpWarriorArt.glass(&context, visor: Self.visor, style: style) }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

enum LevelUpWarriorArt {
    private typealias C = LevelUpCurve
    /// Dark blued steel for the armour, so the trim and the energy stand out;
    /// one light from the upper left, like the badges.
    private static let steel = ForgeTone(hue: 0.62, saturation: 0.34, brightness: 0.62)

    static func draw(_ ctx: inout GraphicsContext, style: LevelPrestige, t: Double) {
        let post = t - LevelUpTiming.impact
        let lit = C.ramp(post, 0, 0.15)
        let trim = style.material.metal
        cape(&ctx, style: style, t: t)
        legs(&ctx, trim: trim)
        blade(&ctx, style: style, t: t, lit: lit)
        torso(&ctx, style: style, trim: trim, t: t, lit: lit)
        arms(&ctx, trim: trim)
        hilt(&ctx, style: style, trim: trim, lit: lit)
        pauldron(&ctx, side: -1, style: style, trim: trim)
        pauldron(&ctx, side: 1, style: style, trim: trim)
        helmet(&ctx, style: style, trim: trim, lit: lit)
    }

    // MARK: Parts, back to front

    private static func cape(_ ctx: inout GraphicsContext, style: LevelPrestige, t: Double) {
        func hem(_ x: CGFloat) -> CGFloat { 198 + sin(t * 2.1 + Double(x) * 0.07) * 3.5 }
        var cape = Path()
        cape.move(to: CGPoint(x: 60, y: 80))
        cape.addLine(to: CGPoint(x: 120, y: 80))
        cape.addCurve(to: CGPoint(x: 152, y: hem(152)), control1: CGPoint(x: 134, y: 120), control2: CGPoint(x: 150, y: 160))
        for x in stride(from: 144.0, through: 28, by: -8) {
            cape.addLine(to: CGPoint(x: x, y: hem(x)))
        }
        cape.addCurve(to: CGPoint(x: 60, y: 80), control1: CGPoint(x: 30, y: 160), control2: CGPoint(x: 46, y: 120))
        cape.closeSubpath()
        ctx.fill(cape, with: .linearGradient(Gradient(colors: [style.shade, style.material.face.faceTop, .black.opacity(0.9)]),
                                             startPoint: CGPoint(x: 90, y: 80), endPoint: CGPoint(x: 90, y: 200)))
        // Folds catching the column of light.
        for x: CGFloat in [52, 74, 106, 128] {
            var fold = Path()
            fold.move(to: CGPoint(x: 90 + (x - 90) * 0.45, y: 92))
            fold.addQuadCurve(to: CGPoint(x: x, y: hem(x) - 4), control: CGPoint(x: 90 + (x - 90) * 0.8, y: 150))
            ctx.stroke(fold, with: .color(style.tint.opacity(0.18)), lineWidth: 1.2)
        }
        ctx.stroke(cape, with: .color(style.tint.opacity(0.45)), lineWidth: 1)
    }

    private static func legs(_ ctx: inout GraphicsContext, trim: ForgeTone) {
        for side: CGFloat in [-1, 1] {
            let x = 90 + side * 13
            let leg = Path(roundedRect: CGRect(x: x - 11, y: 144, width: 22, height: 46), cornerRadius: 7)
            plate(&ctx, leg, top: 144, bottom: 190)
            let knee = Path(roundedRect: CGRect(x: x - 9, y: 160, width: 18, height: 12), cornerRadius: 5)
            plate(&ctx, knee, top: 160, bottom: 172, trim: trim)
            let boot = Path(roundedRect: CGRect(x: x - 14 + side * 2, y: 186, width: 28, height: 18), cornerRadius: 6)
            plate(&ctx, boot, top: 186, bottom: 204)
        }
    }

    private static func blade(_ ctx: inout GraphicsContext, style: LevelPrestige, t: Double, lit: Double) {
        var blade = Path()
        blade.addLines([CGPoint(x: 85, y: 138), CGPoint(x: 95, y: 138), CGPoint(x: 94.5, y: 194),
                        CGPoint(x: 90, y: 207), CGPoint(x: 85.5, y: 194)])
        blade.closeSubpath()
        ctx.fill(blade, with: .linearGradient(Gradient(colors: [steel.metal(0.9), steel.metal(0.4)]),
                                              startPoint: CGPoint(x: 85, y: 0), endPoint: CGPoint(x: 95, y: 0)))
        guard lit > 0 else { return }
        var glow = ctx
        glow.blendMode = .plusLighter
        glow.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.fill(blade, with: .color(style.tint.opacity(0.9 * lit)))
        }
        glow.fill(blade, with: .linearGradient(Gradient(colors: [style.tint.opacity(lit), .white.opacity(lit), style.tint.opacity(lit)]),
                                               startPoint: CGPoint(x: 85, y: 0), endPoint: CGPoint(x: 95, y: 0)))
        // Energy running down the blade; the pattern repeats, so it never jumps.
        let run = CGFloat((t / 1.2).truncatingRemainder(dividingBy: 1)) * 24
        glow.clip(to: blade)
        glow.fill(Path(CGRect(x: 80, y: 130, width: 20, height: 80)), with: .linearGradient(
            Gradient(colors: [.clear, .white.opacity(0.5 * lit), .clear]),
            startPoint: CGPoint(x: 90, y: 138 + run), endPoint: CGPoint(x: 90, y: 162 + run), options: .repeat))
    }

    private static func torso(_ ctx: inout GraphicsContext, style: LevelPrestige, trim: ForgeTone, t: Double, lit: Double) {
        var chest = Path()
        chest.move(to: CGPoint(x: 58, y: 80))
        chest.addLine(to: CGPoint(x: 122, y: 80))
        chest.addQuadCurve(to: CGPoint(x: 114, y: 138), control: CGPoint(x: 126, y: 112))
        chest.addLine(to: CGPoint(x: 66, y: 138))
        chest.addQuadCurve(to: CGPoint(x: 58, y: 80), control: CGPoint(x: 54, y: 112))
        chest.closeSubpath()
        plate(&ctx, chest, top: 80, bottom: 138)
        // Pectoral plates and a centre ridge.
        var lines = Path()
        lines.move(to: CGPoint(x: 64, y: 98)); lines.addQuadCurve(to: CGPoint(x: 90, y: 116), control: CGPoint(x: 72, y: 114))
        lines.move(to: CGPoint(x: 116, y: 98)); lines.addQuadCurve(to: CGPoint(x: 90, y: 116), control: CGPoint(x: 108, y: 114))
        lines.move(to: CGPoint(x: 90, y: 116)); lines.addLine(to: CGPoint(x: 90, y: 134))
        ctx.stroke(lines, with: .color(.black.opacity(0.5)), lineWidth: 2)
        // Energy runs in the seams, brighter once the level lands.
        var seams = ctx
        seams.blendMode = .plusLighter
        seams.stroke(lines, with: .color(style.tint.opacity(0.35 + 0.5 * lit)), lineWidth: 1)
        // The energy core over the heart, brighter once the level lands.
        let core = CGPoint(x: 90, y: 99)
        let pulse = 0.75 + 0.25 * sin(t * 2.4)
        let socket = Path(ellipseIn: CGRect(x: core.x - 9, y: core.y - 9, width: 18, height: 18))
        ctx.fill(socket, with: .color(trim.metal(0.3)))
        ctx.stroke(socket, with: .linearGradient(Gradient(colors: [trim.metal(1), trim.metal(0.35)]),
                                                 startPoint: CGPoint(x: core.x, y: core.y - 9), endPoint: CGPoint(x: core.x, y: core.y + 9)),
                   lineWidth: 2)
        var light = ctx
        light.blendMode = .plusLighter
        let energy = (0.35 + 0.65 * lit) * pulse
        light.fill(Path(ellipseIn: CGRect(x: core.x - 22, y: core.y - 22, width: 44, height: 44)),
                   with: .radialGradient(Gradient(colors: [style.tint.opacity(0.55 * energy), .clear]), center: core, startRadius: 0, endRadius: 22))
        light.fill(Path(ellipseIn: CGRect(x: core.x - 6, y: core.y - 6, width: 12, height: 12)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(energy), style.tint.opacity(energy), style.shade.opacity(0.8)]),
                                         center: core, startRadius: 0, endRadius: 6))
        // Belt and hip plates.
        for side: CGFloat in [-1, 1] {
            var tasset = Path()
            tasset.addLines([CGPoint(x: 90 + side * 3, y: 142), CGPoint(x: 90 + side * 26, y: 142),
                             CGPoint(x: 90 + side * 24, y: 160), CGPoint(x: 90 + side * 5, y: 158)])
            tasset.closeSubpath()
            plate(&ctx, tasset, top: 142, bottom: 160, trim: trim)
        }
        let belt = Path(roundedRect: CGRect(x: 62, y: 132, width: 56, height: 12), cornerRadius: 4)
        ctx.fill(belt, with: .linearGradient(Gradient(colors: [trim.metal(0.85), trim.metal(0.35)]),
                                             startPoint: CGPoint(x: 0, y: 132), endPoint: CGPoint(x: 0, y: 144)))
        ctx.stroke(belt, with: .color(.black.opacity(0.55)), lineWidth: 1)
    }

    private static func arms(_ ctx: inout GraphicsContext, trim: ForgeTone) {
        for side: CGFloat in [-1, 1] {
            var arm = Path()
            arm.move(to: CGPoint(x: 90 + side * 40, y: 92))
            arm.addLine(to: CGPoint(x: 90 + side * 36, y: 116))
            arm.addLine(to: CGPoint(x: 90 + side * 9, y: 124))
            ctx.stroke(arm, with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 17, lineCap: .round, lineJoin: .round))
            ctx.stroke(arm, with: .linearGradient(Gradient(colors: [steel.metal(0.85), steel.metal(0.4)]),
                                                  startPoint: CGPoint(x: 90, y: 92), endPoint: CGPoint(x: 90, y: 128)),
                       style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
            // Gauntlet cuff in the rank's metal.
            var cuff = Path()
            cuff.move(to: CGPoint(x: 90 + side * 30, y: 111))
            cuff.addLine(to: CGPoint(x: 90 + side * 32, y: 126))
            ctx.stroke(cuff, with: .color(trim.metal(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }

    private static func hilt(_ ctx: inout GraphicsContext, style: LevelPrestige, trim: ForgeTone, lit: Double) {
        var guardBar = Path()
        guardBar.move(to: CGPoint(x: 68, y: 131))
        guardBar.addQuadCurve(to: CGPoint(x: 112, y: 131), control: CGPoint(x: 90, y: 140))
        ctx.stroke(guardBar, with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        ctx.stroke(guardBar, with: .linearGradient(Gradient(colors: [trim.metal(1), trim.metal(0.45)]),
                                                   startPoint: CGPoint(x: 0, y: 128), endPoint: CGPoint(x: 0, y: 138)),
                   style: StrokeStyle(lineWidth: 6, lineCap: .round))
        // Both fists on the grip.
        for y: CGFloat in [113, 123] {
            let fist = Path(roundedRect: CGRect(x: 80, y: y - 5, width: 20, height: 11), cornerRadius: 5)
            plate(&ctx, fist, top: y - 5, bottom: y + 6)
        }
        let pommel = CGPoint(x: 90, y: 104)
        let stone = Path(ellipseIn: CGRect(x: pommel.x - 4.5, y: pommel.y - 4.5, width: 9, height: 9))
        ctx.fill(stone, with: .radialGradient(Gradient(colors: [style.material.stone.gem(1), style.material.stone.gem(0.3)]),
                                              center: CGPoint(x: pommel.x - 1.5, y: pommel.y - 1.5), startRadius: 0, endRadius: 6))
        ctx.stroke(stone, with: .color(trim.metal(0.9)), lineWidth: 1.5)
    }

    private static func pauldron(_ ctx: inout GraphicsContext, side: CGFloat, style: LevelPrestige, trim: ForgeTone) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 90 + side * x, y: y) }
        // A lower plate, then the main dome, each edged in the rank's metal.
        for (lift, scale) in [(CGFloat(10), CGFloat(0.9)), (0, 1)] {
            var shell = Path()
            shell.move(to: p(22 * scale + 8, 76 + lift))
            shell.addQuadCurve(to: p(56 * scale + 4, 96 + lift), control: p(56 * scale + 6, 64 + lift))
            shell.addQuadCurve(to: p(24 * scale + 8, 92 + lift), control: p(40 * scale + 6, 100 + lift))
            shell.closeSubpath()
            plate(&ctx, shell, top: 64 + lift, bottom: 100 + lift)
            ctx.stroke(shell, with: .linearGradient(Gradient(colors: [trim.metal(1), trim.metal(0.4)]),
                                                    startPoint: CGPoint(x: 0, y: 64 + lift), endPoint: CGPoint(x: 0, y: 100 + lift)),
                       lineWidth: 2)
        }
        // A swept fin rising off the shoulder.
        var fin = Path()
        fin.addLines([p(38, 70), p(56, 50), p(48, 72)])
        fin.closeSubpath()
        ctx.fill(fin, with: .linearGradient(Gradient(colors: [trim.metal(1), trim.metal(0.4)]),
                                            startPoint: p(56, 50), endPoint: p(42, 72)))
        ctx.stroke(fin, with: .color(.black.opacity(0.5)), lineWidth: 0.8)
        let rivet = Path(ellipseIn: CGRect(x: 90 + side * 44 - 3, y: 80, width: 6, height: 6))
        ctx.fill(rivet, with: .color(style.tint))
    }

    private static func helmet(_ ctx: inout GraphicsContext, style: LevelPrestige, trim: ForgeTone, lit: Double) {
        let c = CGPoint(x: 90, y: 48)
        let gorget = Path(roundedRect: CGRect(x: 72, y: 72, width: 36, height: 12), cornerRadius: 5)
        plate(&ctx, gorget, top: 72, bottom: 84, trim: trim)
        // Swept wings off the temples, the helm's silhouette.
        for side: CGFloat in [-1, 1] {
            var wing = Path()
            wing.addLines([CGPoint(x: c.x + side * 32, y: 36), CGPoint(x: c.x + side * 60, y: 14),
                           CGPoint(x: c.x + side * 52, y: 30), CGPoint(x: c.x + side * 58, y: 34),
                           CGPoint(x: c.x + side * 34, y: 56)])
            wing.closeSubpath()
            plate(&ctx, wing, top: 14, bottom: 56, trim: trim)
        }
        // The shell: a domed top, straight cheeks and a pointed chin guard.
        var shell = Path()
        shell.move(to: CGPoint(x: 54, y: 44))
        shell.addQuadCurve(to: CGPoint(x: 126, y: 44), control: CGPoint(x: 90, y: -10))
        shell.addLine(to: CGPoint(x: 123, y: 64))
        shell.addLine(to: CGPoint(x: 104, y: 80))
        shell.addLine(to: CGPoint(x: 90, y: 86))
        shell.addLine(to: CGPoint(x: 76, y: 80))
        shell.addLine(to: CGPoint(x: 57, y: 64))
        shell.closeSubpath()
        plate(&ctx, shell, top: 8, bottom: 86)
        // The crest fin over the top, in the rank's metal.
        var crest = Path()
        crest.addLines([CGPoint(x: c.x - 5, y: 22), CGPoint(x: c.x, y: -2), CGPoint(x: c.x + 5, y: 22)])
        crest.closeSubpath()
        ctx.fill(crest, with: .linearGradient(Gradient(colors: [trim.metal(1), trim.metal(0.4)]),
                                              startPoint: CGPoint(x: c.x - 5, y: 0), endPoint: CGPoint(x: c.x + 5, y: 0)))
        ctx.stroke(crest, with: .color(.black.opacity(0.5)), lineWidth: 0.8)
        // Dark visor glass; the face is drawn over it, the reflection after.
        let visor = Path(roundedRect: CGRect(x: 58, y: 34, width: 64, height: 40), cornerRadius: 18, style: .continuous)
        ctx.fill(visor, with: .color(Color(red: 0.03, green: 0.07, blue: 0.13)))
        ctx.stroke(visor, with: .color(.black.opacity(0.7)), lineWidth: 3)
        var rim = ctx
        rim.blendMode = .plusLighter
        rim.stroke(visor, with: .color(style.tint.opacity(0.3 + 0.5 * lit)), lineWidth: 1.2)
    }

    /// The visor's reflection and the brow, drawn over the face.
    static func glass(_ ctx: inout GraphicsContext, visor: CGRect, style: LevelPrestige) {
        var arc = Path()
        arc.move(to: CGPoint(x: visor.minX + 10, y: visor.minY + 16))
        arc.addQuadCurve(to: CGPoint(x: visor.minX + 26, y: visor.minY + 6), control: CGPoint(x: visor.minX + 12, y: visor.minY + 7))
        ctx.stroke(arc, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        // A pointed brow over the visor, in the rank's metal.
        var brow = Path()
        brow.addLines([CGPoint(x: 55, y: 30), CGPoint(x: 90, y: 37), CGPoint(x: 125, y: 30),
                       CGPoint(x: 122, y: 37), CGPoint(x: 90, y: 43), CGPoint(x: 58, y: 37)])
        brow.closeSubpath()
        plate(&ctx, brow, top: 30, bottom: 43, trim: style.material.metal)
    }

    // MARK: Helpers

    /// A steel plate lit from the upper left, outlined, with a lit top edge.
    /// With `trim` the plate is in the rank's metal instead.
    private static func plate(_ ctx: inout GraphicsContext, _ path: Path, top: CGFloat, bottom: CGFloat, trim: ForgeTone? = nil) {
        let tone = trim ?? steel
        ctx.fill(path, with: .linearGradient(Gradient(colors: [tone.metal(0.95), tone.metal(0.62), tone.metal(0.3)]),
                                             startPoint: CGPoint(x: 70, y: top), endPoint: CGPoint(x: 110, y: bottom)))
        ctx.stroke(path, with: .color(.black.opacity(0.55)), lineWidth: 1.1)
        var edge = ctx
        edge.clip(to: path)
        edge.stroke(path.offsetBy(dx: 1, dy: 1.2), with: .color(.white.opacity(0.28)), lineWidth: 1.2)
    }
}
