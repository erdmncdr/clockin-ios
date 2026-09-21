import SwiftUI

extension BadgeTier {
    var tint: Color {
        switch self {
        case .launch: Color(red:0.28,green:0.81,blue:0.64)
        case .orbit: Color(red:0.22,green:0.70,blue:0.95)
        case .lunar: Color(red:0.64,green:0.58,blue:0.98)
        case .solar: Color(red:1,green:0.65,blue:0.25)
        case .galactic: Color(red:0.95,green:0.37,blue:0.70)
        case .eternal: Color(red:0.90,green:0.83,blue:0.61)
        }
    }
    var highlight: Color { self == .eternal ? .white : tint.opacity(0.65) }
}

struct SpaceInsignia: Shape {
    let stage: Int
    var mission: Bool = false
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let base = mission ? SpaceBadgeGeometry.mission(stage) : SpaceBadgeGeometry.insignia(stage)
        let transform = CGAffineTransform(translationX: rect.midX-side/2,y:rect.midY-side/2).scaledBy(x:side/100,y:side/100)
        return Path(base).applying(transform)
    }
}

/// One finite, category-specific effect. Its parent owns the animation clock.
struct BadgeEffectField: View, Animatable {
    let tier: BadgeTier
    let mission: BadgeMission
    nonisolated var phase: Double
    var seed = 0
    nonisolated var animatableData: Double { get { phase } set { phase = newValue } }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width,size.height)
            let c = CGPoint(x:size.width/2,y:size.height/2)
            let radius = side * 0.36
            let turn = phase * .pi * 2 + Double(seed % 36) * .pi / 18
            let strength = 0.28 + 0.09 * Double(tier.rawValue)
            switch mission {
            case .flight:
                for n in 0..<(4 + tier.rawValue) {
                    let a = Double(n) * .pi * 2 / Double(4+tier.rawValue) + Double(seed % 17)
                    let start = radius * (0.65 + phase * 0.4)
                    var path = Path()
                    path.move(to:CGPoint(x:c.x+cos(a)*start,y:c.y+sin(a)*start))
                    path.addLine(to:CGPoint(x:c.x+cos(a)*(start+side*0.10),y:c.y+sin(a)*(start+side*0.10)))
                    context.stroke(path,with:.color(tier.tint.opacity(strength)),lineWidth:1.4)
                }
            case .signal:
                for n in 0..<3 {
                    let r = radius * (0.75 + (phase + Double(n)/3).truncatingRemainder(dividingBy:1)*0.6)
                    var path = Path()
                    path.addArc(center:c,radius:r,startAngle:.degrees(-65),endAngle:.degrees(65),clockwise:false)
                    path.addArc(center:c,radius:r,startAngle:.degrees(115),endAngle:.degrees(245),clockwise:false)
                    context.stroke(path,with:.color(tier.tint.opacity(strength*(1-Double(n)*0.2))),lineWidth:1)
                }
            case .orbit:
                let r = radius * 1.08
                let ellipse = CGRect(x:c.x-r,y:c.y-r*0.55,width:r*2,height:r*1.1)
                context.stroke(Path(ellipseIn:ellipse),with:.color(tier.tint.opacity(0.3)),lineWidth:1)
                for n in 0..<(tier.rawValue > 3 ? 3 : 1) {
                    let a = turn + Double(n) * .pi*2/3
                    let dot = CGRect(x:c.x+cos(a)*r-2,y:c.y+sin(a)*r*0.55-2,width:4,height:4)
                    context.fill(Path(ellipseIn:dot),with:.color(tier.tint))
                }
            case .archive:
                for n in 0..<3 {
                    let y = c.y + (Double(n)-1)*side*0.17
                    let x = c.x - radius + phase * radius*0.3
                    let r = CGRect(x:x,y:y,width:radius*2-phase*radius*0.3,height:1.3)
                    context.fill(Path(r),with:.color(tier.tint.opacity(strength*(0.5+Double(n)*0.2))))
                }
            case .habitat:
                for n in 0..<6 {
                    let a = Double(n) * .pi/3 + .pi/6
                    let r = radius * (1.05+sin(phase * .pi)*0.08)
                    let point = CGPoint(x:c.x+cos(a)*r,y:c.y+sin(a)*r)
                    let next = CGPoint(x:c.x+cos(a + .pi/3)*r,y:c.y+sin(a + .pi/3)*r)
                    var line = Path();line.move(to:point);line.addLine(to:next)
                    context.stroke(line,with:.color(tier.tint.opacity(0.35)),lineWidth:1)
                    context.fill(Path(ellipseIn:CGRect(x:point.x-2,y:point.y-2,width:4,height:4)),with:.color(tier.tint))
                }
            case .suit:
                var path = Path()
                path.addArc(center:c,radius:radius*1.15,startAngle:.radians(turn),endAngle:.radians(turn + .pi*1.3),clockwise:false)
                context.stroke(path,with:.color(tier.tint.opacity(strength)),style:StrokeStyle(lineWidth:2,lineCap:.round))
                path = Path()
                path.addArc(center:c,radius:radius*0.96,startAngle:.radians(-turn),endAngle:.radians(-turn + .pi/2),clockwise:false)
                context.stroke(path,with:.color(.white.opacity(0.55)),lineWidth:1)
            }
            if tier == .eternal {
                let r = radius * 1.4
                context.stroke(Path(ellipseIn:CGRect(x:c.x-r,y:c.y-r,width:r*2,height:r*2)),
                               with:.color(.white.opacity(0.18)),style:StrokeStyle(lineWidth:1,dash:[2,6]))
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct SpaceBadgeSeal: View {
    let badge: InsightsBadge
    let size: CGFloat
    var phase = 0.0
    var preview = false
    private var lit: Bool { badge.unlocked || preview }
    var body: some View {
        ZStack {
            BadgeEffectField(tier:badge.tier,mission:badge.mission,phase:phase,seed:badge.visualSeed)
                .opacity(lit ? 1 : 0.32)
            Circle().fill(Color(red:0.055,green:0.065,blue:0.12)).padding(size*0.21)
            Circle().strokeBorder(badge.tier.tint.opacity(lit ? 0.65 : 0.25),lineWidth:1).padding(size*0.21)
            SpaceInsignia(stage:badge.mission.rawValue,mission:true)
                .stroke(LinearGradient(colors:[.white,badge.tier.tint],startPoint:.topLeading,endPoint:.bottomTrailing),
                        style:StrokeStyle(lineWidth:max(1.3,size*0.019),lineCap:.round,lineJoin:.round))
                .padding(size*0.29).opacity(lit ? 1 : 0.45)
            SpaceInsignia(stage:badge.tier.rawValue)
                .stroke(badge.tier.tint,style:StrokeStyle(lineWidth:max(1,size*0.012),lineCap:.round,lineJoin:.round))
                .frame(width:size*0.20,height:size*0.20).offset(y:size*0.32)
        }
        .frame(width:size,height:size).accessibilityHidden(true)
    }
}
