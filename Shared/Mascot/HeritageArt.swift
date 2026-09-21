import Foundation
import CoreGraphics
import ImageIO

/// Runtime rendering keeps the historic photograph intact in the bundle.
/// These wall decorations retain their orientation when the room is mirrored.
enum HeritageArt {
    static func preservesOrientation(_ id: String) -> Bool {
        ["ataturk-portrait", "turkish-flag"].contains(id)
    }
    static func render(_ file: String, source: URL?) -> CGImage? {
        guard file == "ataturk-portrait.jpg" || file == "turkish-flag.svg" else { return nil }
        let portrait = file == "ataturk-portrait.jpg"
        let width = portrait ? 60 : 72
        let height = portrait ? 80 : 52
        guard let c = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.setFillColor(CGColor(red:0.15,green:0.17,blue:0.23,alpha:1))
        c.fill(CGRect(x:0,y:0,width:width,height:height))
        c.setStrokeColor(CGColor(red:0.65,green:0.58,blue:0.39,alpha:1));c.setLineWidth(1)
        c.stroke(CGRect(x:1.5,y:1.5,width:Double(width-3),height:Double(height-3)))
        if portrait {
            guard let source, let input = CGImageSourceCreateWithURL(source as CFURL,nil),
                  let image = CGImageSourceCreateImageAtIndex(input,0,nil) else { return nil }
            let ratio = min(52.0/Double(image.width),72.0/Double(image.height))
            let w = Double(image.width)*ratio, h = Double(image.height)*ratio
            c.interpolationQuality = .high
            c.draw(image,in:CGRect(x:(60-w)/2,y:(80-h)/2,width:w,height:h))
        } else {
            // 3:2 flag; white crescent and a five-point star, never an emoji.
            let h = 64.0/1.5
            c.saveGState();c.translateBy(x:4,y:(52-h)/2);c.scaleBy(x:h,y:h)
            let red = CGColor(red:227.0/255,green:10.0/255,blue:23.0/255,alpha:1)
            c.setFillColor(red);c.fill(CGRect(x:0,y:0,width:1.5,height:1))
            c.setFillColor(CGColor(gray:1,alpha:1));c.fillEllipse(in:CGRect(x:0.25,y:0.25,width:0.5,height:0.5))
            c.setFillColor(red);c.fillEllipse(in:CGRect(x:0.3625,y:0.3,width:0.4,height:0.4))
            let star = CGMutablePath()
            for n in 0..<10 {
                let angle = Double(n) * .pi/5 + .pi
                let radius = n.isMultiple(of:2) ? 0.125 : 0.04774575
                let point = CGPoint(x:0.82084+cos(angle)*radius,y:0.5+sin(angle)*radius)
                if n == 0 { star.move(to:point) } else { star.addLine(to:point) }
            }
            star.closeSubpath();c.addPath(star);c.setFillColor(CGColor(gray:1,alpha:1));c.fillPath()
            c.restoreGState()
        }
        return c.makeImage()
    }
}
