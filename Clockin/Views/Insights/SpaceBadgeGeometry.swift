import Foundation
import CoreGraphics

/// Original 100-unit mission insignia. No font glyphs or SF Symbols.
enum SpaceBadgeGeometry {
    static func insignia(_ stage: Int) -> CGPath {
        let p = CGMutablePath()
        func line(_ points: [(Double, Double)], closed: Bool = false) {
            p.move(to: CGPoint(x: points[0].0, y: points[0].1))
            for q in points.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
            if closed { p.closeSubpath() }
        }
        switch stage {
        case 1:
            line([(50,12),(74,72),(50,59),(26,72),(50,12)])
            line([(50,31),(50,52)])
            line([(41,72),(41,81)]); line([(50,70),(50,91)]); line([(59,72),(59,81)])
        case 2:
            p.addEllipse(in: CGRect(x: 31,y: 31,width: 38,height: 38))
            p.move(to: CGPoint(x: 17,y: 73))
            p.addCurve(to: CGPoint(x: 83,y: 27), control1: CGPoint(x: -1,y: 51), control2: CGPoint(x: 66,y: 2))
            p.addCurve(to: CGPoint(x: 17,y: 73), control1: CGPoint(x: 104,y: 47), control2: CGPoint(x: 34,y: 98))
            p.addEllipse(in: CGRect(x: 72,y: 20,width: 10,height: 10))
        case 3:
            p.move(to: CGPoint(x: 66,y: 16))
            p.addCurve(to: CGPoint(x: 68,y: 80), control1: CGPoint(x: 17,y: 3), control2: CGPoint(x: 12,y: 76))
            p.addCurve(to: CGPoint(x: 66,y: 16), control1: CGPoint(x: 35,y: 70), control2: CGPoint(x: 34,y: 27))
            p.addEllipse(in: CGRect(x: 63,y: 41,width: 16,height: 16))
            line([(17,86),(83,86)])
        case 4:
            p.addEllipse(in: CGRect(x: 30,y: 30,width: 40,height: 40))
            p.addArc(center: CGPoint(x:50,y:50), radius:28, startAngle:0.25, endAngle:2.85, clockwise:false)
            for n in 0..<8 {
                let a = Double(n) * .pi / 4
                line([(50+cos(a)*37,50+sin(a)*37),(50+cos(a)*46,50+sin(a)*46)])
            }
            p.addEllipse(in: CGRect(x: 44,y: 44,width: 12,height: 12))
        case 5:
            p.addEllipse(in: CGRect(x: 43,y: 43,width: 14,height: 14))
            for n in 0..<3 {
                let arm = CGMutablePath()
                arm.move(to: CGPoint(x: 51,y: 37))
                arm.addCurve(to: CGPoint(x: 25,y: 85), control1: CGPoint(x: 97,y: 4), control2: CGPoint(x: 100,y: 88))
                var t = CGAffineTransform(translationX:50,y:50).rotated(by:Double(n) * .pi * 2 / 3).translatedBy(x:-50,y:-50)
                if let a = arm.copy(using:&t) { p.addPath(a) }
            }
        default:
            line([(50,6),(78,24),(88,50),(78,76),(50,94),(22,76),(12,50),(22,24)], closed:true)
            line([(50,20),(68,50),(50,80),(32,50)], closed:true)
            p.addEllipse(in: CGRect(x: 41,y: 41,width:18,height:18))
            line([(5,50),(28,50)]); line([(72,50),(95,50)])
            line([(50,6),(50,20)]); line([(50,80),(50,94)])
        }
        return p
    }

    static func mission(_ family: Int) -> CGPath {
        let p = CGMutablePath()
        func line(_ points: [(Double,Double)], closed: Bool = false) {
            p.move(to: CGPoint(x:points[0].0,y:points[0].1))
            points.dropFirst().forEach { p.addLine(to: CGPoint(x:$0.0,y:$0.1)) }
            if closed { p.closeSubpath() }
        }
        switch family {
        case 0: // flight: swept spacecraft
            line([(50,15),(79,77),(50,62),(21,77)],closed:true)
            line([(50,34),(50,52)]);line([(41,78),(50,88),(59,78)])
        case 1: // streak: uninterrupted radio pulse
            line([(13,51),(28,51),(37,29),(49,73),(61,20),(72,51),(88,51)])
        case 2: // days: orbital clock
            p.addEllipse(in:CGRect(x:20,y:20,width:60,height:60))
            line([(50,31),(50,50),(65,59)])
            line([(50,11),(50,17)]);line([(83,50),(89,50)]);line([(50,83),(50,89)]);line([(11,50),(17,50)])
        case 3: // archive: stacked mission logs
            for y in [33.0,49,65] { line([(19,y),(50,y+17),(81,y),(50,y-17)],closed:true) }
        case 4: // collection: orbital habitat
            p.addArc(center:CGPoint(x:50,y:60),radius:29,startAngle: .pi,endAngle:0,clockwise:false)
            line([(21,60),(21,78),(79,78),(79,60)])
            line([(50,31),(50,78)]);line([(28,48),(72,48)])
            p.addEllipse(in:CGRect(x:45,y:12,width:10,height:10))
        default: // style: space helmet
            p.addRoundedRect(in:CGRect(x:21,y:18,width:58,height:65),cornerWidth:25,cornerHeight:25)
            p.addRoundedRect(in:CGRect(x:28,y:35,width:44,height:25),cornerWidth:10,cornerHeight:10)
            line([(35,83),(35,90),(65,90),(65,83)])
            line([(19,44),(12,44),(12,59),(19,59)]);line([(81,44),(88,44),(88,59),(81,59)])
        }
        return p
    }
}
