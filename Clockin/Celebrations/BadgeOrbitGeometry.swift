import Foundation

/// Constant-time perimeter sampling; no path flattening for each trail particle.
struct BadgeOrbitGeometry {
    let size: CGSize
    let stage: Int

    func point(at fraction: Double) -> CGPoint {
        let w = max(2, size.width - 2), h = max(2, size.height - 2)
        let f = fraction - floor(fraction)
        if stage == 0 {
            let r = min(13, h / 2)
            let horizontal = w - 2 * r, vertical = h - 2 * r, arc = Double.pi * r / 2
            let lengths = [horizontal, arc, vertical, arc, horizontal, arc, vertical, arc]
            var distance = f * lengths.reduce(0, +)
            for i in 0..<8 {
                if distance <= lengths[i] || i == 7 {
                    let u = lengths[i] > 0 ? distance / lengths[i] : 0
                    switch i {
                    case 0: return CGPoint(x: 1 + r + distance, y: 1)
                    case 2: return CGPoint(x: 1 + w, y: 1 + r + distance)
                    case 4: return CGPoint(x: 1 + w - r - distance, y: 1 + h)
                    case 6: return CGPoint(x: 1, y: 1 + h - r - distance)
                    default:
                        let centers = [CGPoint(x: 1 + w - r, y: 1 + r), CGPoint(x: 1 + w - r, y: 1 + h - r), CGPoint(x: 1 + r, y: 1 + h - r), CGPoint(x: 1 + r, y: 1 + r)]
                        let corner = i / 2, angle = (-Double.pi / 2) + Double(corner) * .pi / 2 + u * .pi / 2
                        return CGPoint(x: centers[corner].x + cos(angle) * r, y: centers[corner].y + sin(angle) * r)
                    }
                }
                distance -= lengths[i]
            }
        }
        let c = min(stage >= 4 ? 13.0 : (stage >= 3 ? 10.0 : 6.0), h * 0.3)
        let pts = [CGPoint(x: 1+c,y: 1), CGPoint(x: 1+w-c,y: 1), CGPoint(x: 1+w,y: 1+c), CGPoint(x: 1+w,y: 1+h-c), CGPoint(x: 1+w-c,y: 1+h), CGPoint(x: 1+c,y: 1+h), CGPoint(x: 1,y: 1+h-c), CGPoint(x: 1,y: 1+c)]
        let lengths = [w-2*c, c*sqrt(2), h-2*c, c*sqrt(2), w-2*c, c*sqrt(2), h-2*c, c*sqrt(2)]
        var distance = f * lengths.reduce(0, +)
        for i in 0..<8 {
            if distance <= lengths[i] || i == 7 {
                let u = lengths[i] > 0 ? distance / lengths[i] : 0
                let a = pts[i], b = pts[(i+1)%8]
                return CGPoint(x: a.x + (b.x-a.x)*u, y: a.y+(b.y-a.y)*u)
            }
            distance -= lengths[i]
        }
        return pts[0]
    }
}
