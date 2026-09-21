import Foundation
import CoreGraphics
import ImageIO
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let folder = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var checks = 0
@MainActor func check(_ value: Bool, _ name: String) { precondition(value,name); checks += 1 }
@MainActor func save(_ image: CGImage, _ name: String) {
    let dest = CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(dest,image,nil);check(CGImageDestinationFinalize(dest),name)
}
let c = CGContext(data:nil,width:1200,height:520,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(CGColor(red:0.04,green:0.045,blue:0.09,alpha:1));c.fill(CGRect(x:0,y:0,width:1200,height:520))
let colors: [(Double,Double,Double)] = [(0.28,0.81,0.64),(0.22,0.70,0.95),(0.64,0.58,0.98),(1,0.65,0.25),(0.95,0.37,0.7),(0.9,0.83,0.61)]
let names = ["Launch","Orbit","Lunar","Solar","Galactic","Eternal"]
for row in 0..<2 {
    for n in 0..<6 {
        let path = row == 0 ? SpaceBadgeGeometry.insignia(n+1) : SpaceBadgeGeometry.mission(n)
        check(!path.isEmpty && CGRect(x:0,y:0,width:100,height:100).contains(path.boundingBoxOfPath),"emblem \(row)/\(n) fits")
        c.saveGState();c.translateBy(x:CGFloat(n*200+40),y:row == 0 ? 452 : 214);c.scaleBy(x:1.2,y:-1.2)
        c.setStrokeColor(CGColor(red:colors[n].0,green:colors[n].1,blue:colors[n].2,alpha:1));c.setLineWidth(3);c.setLineCap(.round);c.setLineJoin(.round)
        c.addPath(path);c.strokePath();c.restoreGState()
        let label = row == 0 ? names[n] : ["Flight","Signal","Orbit","Log","Habitat","Suit"][n]
        let attributes: [NSAttributedString.Key:Any] = [.init(kCTFontAttributeName as String):CTFontCreateWithName("HelveticaNeue-Medium" as CFString,22,nil),.init(kCTForegroundColorAttributeName as String):CGColor(gray:0.9,alpha:1)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string:label,attributes:attributes))
        let w = CTLineGetTypographicBounds(line,nil,nil,nil)
        c.textPosition = CGPoint(x:Double(n*200+100)-w/2,y:row == 0 ? 296 : 58);CTLineDraw(line,c)
    }
}
save(c.makeImage()!,"space-insignia.png")
for (file,w,h) in [("ataturk-portrait.jpg",60,80),("turkish-flag.svg",72,52)] {
    let rendered = HeritageArt.render(file,source:root.appendingPathComponent(file))
    check(rendered?.width == w && rendered?.height == h,"wall asset size")
    save(rendered!,file+".png")
}
check(HeritageArt.preservesOrientation("ataturk-portrait") && HeritageArt.preservesOrientation("turkish-flag"),"gifts do not mirror")
check(!HeritageArt.preservesOrientation("poster"),"ordinary room items keep their behavior")
print("\(checks) space art checks passed")
