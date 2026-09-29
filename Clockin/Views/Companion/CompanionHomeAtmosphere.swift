import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

#if canImport(UIKit)
struct CompanionFurnitureImage: UIViewRepresentable {
    let image: CGImage
    let mirrored: Bool
    let swaying: Bool
    func makeUIView(context: Context) -> FurnitureLayerView { FurnitureLayerView() }
    func updateUIView(_ view: FurnitureLayerView, context: Context) { view.configure(image, mirrored: mirrored, swaying: swaying) }
    static func dismantleUIView(_ view: FurnitureLayerView, coordinator: ()) { view.art.removeAllAnimations() }
}

#else
struct CompanionFurnitureImage: NSViewRepresentable {
    let image: CGImage
    let mirrored: Bool
    let swaying: Bool
    func makeNSView(context: Context) -> FurnitureLayerView { FurnitureLayerView() }
    func updateNSView(_ view: FurnitureLayerView, context: Context) { view.configure(image, mirrored: mirrored, swaying: swaying) }
    static func dismantleNSView(_ view: FurnitureLayerView, coordinator: ()) { view.art.removeAllAnimations() }
}

#endif

#if canImport(UIKit)
typealias FurnitureLayerViewBase = UIView
#else
typealias FurnitureLayerViewBase = NSView
#endif

final class FurnitureLayerView: FurnitureLayerViewBase {
    #if os(macOS)
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    #endif

    private var renderingLayer: CALayer {
        #if canImport(UIKit)
        layer
        #else
        layer!
        #endif
    }
    let art = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        #if canImport(UIKit)
        isUserInteractionEnabled = false
        #else
        wantsLayer = true
        setAccessibilityElement(false)
        #endif

        art.anchorPoint = CGPoint(x: 0.5,y: 1)
        art.magnificationFilter = .nearest; art.minificationFilter = .nearest
        renderingLayer.addSublayer(art)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    #if canImport(UIKit)
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutLayers()
    }
    #else
    override func layout() {
        super.layout()
        layoutLayers()
    }
    #endif

    private func layoutLayers() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        art.bounds = bounds; art.position = CGPoint(x: bounds.midX,y: bounds.maxY)
        CATransaction.commit()
    }
    func configure(_ image: CGImage, mirrored: Bool, swaying: Bool) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        art.contents = image; art.transform = CATransform3DMakeScale(mirrored ? -1 : 1,1,1)
        CATransaction.commit()
        if swaying {
            guard art.animation(forKey: "leaves") == nil else { return }
            let sway = CABasicAnimation(keyPath: "transform.rotation.z")
            sway.fromValue = -0.012; sway.toValue = 0.012
            sway.duration = 4; sway.autoreverses = true; sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            MascotAnimationRate.sway.apply(to: sway)
            art.add(sway,forKey: "leaves")
        } else { art.removeAllAnimations() }
    }
}

#if canImport(UIKit)
struct CompanionHomeAtmosphere: UIViewRepresentable {
    let state: WardrobeState
    let room: WardrobeRoom
    let light: CompanionHomeLight
    let moving: Bool
    func makeUIView(context: Context) -> HomeAtmosphereLayerView { HomeAtmosphereLayerView() }
    func updateUIView(_ view: HomeAtmosphereLayerView, context: Context) { view.configure(state: state, room: room, light: light, moving: moving) }
    static func dismantleUIView(_ view: HomeAtmosphereLayerView, coordinator: ()) { view.stop() }
}

#else
struct CompanionHomeAtmosphere: NSViewRepresentable {
    let state: WardrobeState
    let room: WardrobeRoom
    let light: CompanionHomeLight
    let moving: Bool
    func makeNSView(context: Context) -> HomeAtmosphereLayerView { HomeAtmosphereLayerView() }
    func updateNSView(_ view: HomeAtmosphereLayerView, context: Context) { view.configure(state: state, room: room, light: light, moving: moving) }
    static func dismantleNSView(_ view: HomeAtmosphereLayerView, coordinator: ()) { view.stop() }
}

#endif

#if canImport(UIKit)
typealias HomeAtmosphereLayerViewBase = UIView
#else
typealias HomeAtmosphereLayerViewBase = NSView
#endif

final class HomeAtmosphereLayerView: HomeAtmosphereLayerViewBase {
    #if os(macOS)
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    #endif

    private var renderingLayer: CALayer {
        #if canImport(UIKit)
        layer
        #else
        layer!
        #endif
    }
    private var key = ""
    private var arrangement = RoomArrangement()
    override init(frame: CGRect) {
        super.init(frame: frame)
        #if canImport(UIKit)
        isUserInteractionEnabled = false
        #else
        wantsLayer = true
        setAccessibilityElement(false)
        #endif
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func stop() { renderingLayer.sublayers?.forEach { $0.removeAllAnimations() } }
    func configure(state: WardrobeState, room: WardrobeRoom, light: CompanionHomeLight, moving: Bool) {
        let next = "\(state.room)/\(state.homeLayout)/\(state.homeLampOn)/\(light)/\(moving)/" + state.furniture.values.sorted().joined(separator: "/")
        guard next != key || arrangement != state.homeArrangement else { return }
        arrangement = state.homeArrangement
        key = next; stop(); renderingLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        func placed(_ id: String, _ size: CGSize) -> CGRect {
            guard let item = WardrobeArt.home.items[id] else { return .zero }
            return HomeSceneLayout.furnitureRect(item,in:room,imageSize:size,layout:.deskLeft,
                roomID:state.room,arrangement:state.homeArrangement)
        }
        func x(_ value: Double) -> Double { state.homeLayout.x(value) }
        func glow(_ px: Double, _ py: Double, radius: Double, strength: Float) {
            let glow = CAGradientLayer()
            glow.type = .radial
            glow.colors = [PlatformColor(red:1,green:0.78,blue:0.35,alpha:0.32).cgColor,PlatformColor.clear.cgColor]
            glow.startPoint = CGPoint(x:0.5,y:0.5); glow.endPoint = CGPoint(x:1,y:1)
            glow.frame = CGRect(x:x(px)-radius,y:py-radius,width:radius*2,height:radius*2)
            glow.opacity = strength
            renderingLayer.addSublayer(glow)
        }
        if state.homeLampOn {
            glow(176,44,radius:48,strength:light == .day ? 0.45 : 1)
            if state.furniture["floorLeft"] == "floor-lamp" {
                let rect = placed("floor-lamp",CGSize(width:58,height:106))
                glow(rect.minX+28,rect.minY+18,radius:48,strength:0.8)
            }
            if state.furniture["desk"] == "desk-lamp" {
                let rect = placed("desk-lamp",CGSize(width:110,height:112))
                let scale = rect.height / 112
                glow(rect.minX+59*scale,rect.minY+19*scale,radius:30,strength:0.8)
            }
        }
        var sources = [WardrobePoint]()
        if state.furniture["floorLeft"] == "coffee-machine" {
            let rect = placed("coffee-machine",CGSize(width:58,height:80))
            sources.append(.init(rect.minX+28,rect.minY+17))
        }
        if state.furniture["desk"] == "desk-monitor" {
            let rect = placed("desk-monitor",CGSize(width:110,height:104))
            let scale = rect.height / 104
            sources.append(.init(rect.minX+13*scale,rect.minY+25*scale))
        }
        for source in sources {
            for index in 0..<3 {
                let steam = CAShapeLayer()
                #if canImport(UIKit)
                let path = UIBezierPath()
                path.move(to: CGPoint(x:0,y:0))
                path.addCurve(to:CGPoint(x:1,y:-11),controlPoint1:CGPoint(x:-5,y:-3),controlPoint2:CGPoint(x:5,y:-7))
                steam.path = path.cgPath; steam.strokeColor = PlatformColor.white.withAlphaComponent(0.5).cgColor
                #else
                let path = CGMutablePath()
                path.move(to: CGPoint(x:0,y:0))
                path.addCurve(to: CGPoint(x:1,y:-11), control1: CGPoint(x:-5,y:-3), control2: CGPoint(x:5,y:-7))
                steam.path = path; steam.strokeColor = PlatformColor.white.withAlphaComponent(0.5).cgColor
                #endif
                steam.fillColor = nil; steam.lineWidth = 1
                steam.position = CGPoint(x:x(source.x + Double(index*4-4)),y:source.y)
                steam.opacity = moving ? 0 : 0.18
                renderingLayer.addSublayer(steam)
                if moving {
                    let rise = CABasicAnimation(keyPath:"transform.translation.y"); rise.fromValue = 3; rise.toValue = -10
                    let fade = CAKeyframeAnimation(keyPath:"opacity"); fade.values = [0,0.45,0]; fade.keyTimes = [0,0.3,1]
                    let group = CAAnimationGroup(); group.animations = [rise,fade]; group.duration = 3.6
                    group.beginTime = CACurrentMediaTime()+Double(index)*0.85; group.repeatCount = .infinity
                    MascotAnimationRate.sway.apply(to:group); steam.add(group,forKey:"steam")
                }
            }
        }
    }
}
