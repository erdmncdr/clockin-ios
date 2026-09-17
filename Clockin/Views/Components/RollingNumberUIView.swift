import UIKit

final class RollingNumberUIView: UIView {
    private let content = UIView()
    private var cells: [Int: RollingDigitUIView] = [:]
    private var state = RollingNumberRenderState()
    private var font = UIFont.systemFont(ofSize: 17)
    private var color = UIColor.label
    private var textLayout = RollingNumberLayout(widths: [], lineHeight: 0, ascender: 0)
    private var naturalSize: CGSize { textLayout.naturalSize }
    private var minimumScaleFactor: CGFloat = 1

    init() {
        super.init(frame: .zero)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        isUserInteractionEnabled = false
        clipsToBounds = true
        content.isAccessibilityElement = false
        content.layer.anchorPoint = .zero
        addSubview(content)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize { naturalSize }

    func fittingSize(width: CGFloat?) -> CGSize {
        guard let width, width.isFinite else { return naturalSize }
        return CGSize(width: min(naturalSize.width, max(0, width)), height: naturalSize.height)
    }

    func update(sample: RollingNumberSample, font: UIFont, color: UIColor, layout: RollingNumberLayout,
                canAnimate: Bool, minimumScaleFactor: CGFloat) {
        let fontChanged = self.font != font
        let styleChanged = fontChanged || self.color != color
        if self.minimumScaleFactor != minimumScaleFactor {
            self.minimumScaleFactor = minimumScaleFactor
            setNeedsLayout()
        }
        guard let update = state.update(to: sample, allowsAnimation: canAnimate, reset: styleChanged) else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        self.font = font
        self.color = color
        accessibilityLabel = sample.text

        let ids = Set(update.cells.map(\.id))
        for id in Array(cells.keys) where !ids.contains(id) {
            cells.removeValue(forKey: id)?.removeFromSuperview()
        }
        var x: CGFloat = 0
        let height = ceil(font.lineHeight)
        for (cell, width) in zip(update.cells, layout.widths) {
            let view: RollingDigitUIView
            if let existing = cells[cell.id] {
                view = existing
            } else {
                view = RollingDigitUIView()
                cells[cell.id] = view
                content.addSubview(view)
            }
            let frame = CGRect(x: x, y: 0, width: width, height: height)
            if view.frame != frame { view.frame = frame }
            view.update(cell: cell, direction: update.direction, font: font, color: color,
                        snap: !state.allowsAnimation || update.lengthChanged || styleChanged)
            x += width
        }
        let oldSize = naturalSize
        textLayout = layout
        if oldSize != naturalSize { invalidateIntrinsicContentSize() }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = textLayout.scale(width: bounds.width, minimum: minimumScaleFactor)
        content.bounds = CGRect(origin: .zero, size: naturalSize)
        content.layer.position = CGPoint(x: 0, y: (bounds.height - naturalSize.height * scale) / 2)
        content.layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }

    func stopAnimations() {
        state = RollingNumberRenderState()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for cell in cells.values { cell.stopAnimations() }
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopAnimations() }
    }
}

private final class RollingDigitUIView: UIView {
    private var current = UILabel()
    private var spare = UILabel()
    private var character: Character?

    init() {
        super.init(frame: .zero)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        isAccessibilityElement = false
        for label in [current, spare] {
            label.isAccessibilityElement = false
            label.textAlignment = .center
            label.backgroundColor = .clear
            addSubview(label)
        }
        spare.layer.opacity = 0
    }

    required init?(coder: NSCoder) { nil }

    func update(cell: RollingNumberCell, direction: RollDirection, font: UIFont, color: UIColor, snap: Bool) {
        layer.masksToBounds = cell.character.isNumber
        let changed = character != cell.character
        for label in [current, spare] {
            if label.font != font { label.font = font }
            if label.textColor != color { label.textColor = color }
            if label.layer.bounds.size != bounds.size {
                label.layer.bounds = CGRect(origin: .zero, size: bounds.size)
            }
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            if label.layer.position != center { label.layer.position = center }
        }
        if !snap, !changed { return }
        stopAnimations()
        character = cell.character
        guard !snap, let previous = cell.previous else {
            current.text = String(cell.character)
            return
        }
        // Iki glif yeniden kullanilir; bitiste eski glif modelde saydam kalir.
        swap(&current, &spare)
        spare.text = String(previous)
        current.text = String(cell.character)
        let travel = direction == .up ? -bounds.height : bounds.height
        spare.layer.transform = CATransform3DMakeTranslation(0, travel, 0)
        spare.layer.opacity = 0
        current.layer.transform = CATransform3DIdentity
        current.layer.opacity = 1
        animate(spare.layer, fromY: 0, toY: travel, fromOpacity: 1, toOpacity: 0)
        animate(current.layer, fromY: -travel, toY: 0, fromOpacity: 0, toOpacity: 1)
    }

    func stopAnimations() {
        current.layer.removeAllAnimations()
        spare.layer.removeAllAnimations()
        current.layer.transform = CATransform3DIdentity
        current.layer.opacity = 1
        spare.layer.transform = CATransform3DIdentity
        spare.layer.opacity = 0
    }

    private func animate(_ layer: CALayer, fromY: CGFloat, toY: CGFloat,
                         fromOpacity: Float, toOpacity: Float) {
        let move = CABasicAnimation(keyPath: "transform.translation.y")
        move.fromValue = fromY
        move.toValue = toY
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = fromOpacity
        fade.toValue = toOpacity
        // 30 fps kisa kaymada kademeli gorunuyordu; ara kareleri ekran sunucusu
        // cizdigi icin 60 fps uygulamaya yuk getirmez.
        let range = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        for animation in [move, fade] {
            animation.duration = 0.25
            animation.preferredFrameRateRange = range
        }
        let group = CAAnimationGroup()
        group.animations = [move, fade]
        group.duration = 0.25
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.preferredFrameRateRange = range
        // Model son degerdedir; CA animasyonu bitiste kendiliginden siler.
        layer.add(group, forKey: "rolling")
    }
}
