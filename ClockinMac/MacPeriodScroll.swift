import Foundation

/// Tek parmak birakma + momentum dizisi en fazla bir donem degistirir.
struct MacPeriodScroll {
    enum Phase { case began, changed, ended, cancelled, none }
    private enum Axis { case undecided, horizontal, vertical }
    private var axis = Axis.undecided
    private var x = 0.0
    private var y = 0.0
    private var fired = false
    private var started = false
    private var lastTime = -Double.infinity

    mutating func update(x dx: Double, y dy: Double, phase: Phase, momentum: Bool,
                         precise: Bool, time: Double) -> (consumed: Bool, direction: Int?) {
        guard precise else { return (false, nil) }
        if momentum { return (axis == .horizontal, nil) }
        if phase == .began || (phase == .none && time - lastTime > 0.25) {
            axis = .undecided; x = 0; y = 0; fired = false; started = true
        }
        lastTime = time
        if phase == .cancelled { axis = .vertical; started = false; return (false, nil) }
        guard started else { return (false, nil) }
        if phase == .ended { started = false }
        x += dx; y += dy
        if axis == .undecided, max(abs(x), abs(y)) >= 6 {
            axis = abs(x) > abs(y) * 1.3 ? .horizontal : .vertical
        }
        guard axis == .horizontal else { return (false, nil) }
        guard !fired, abs(x) >= 50 else { return (true, nil) }
        fired = true
        // NSEvent scrollingDeltaX zaten Dogal Kaydirma tercihine gore isaretlidir.
        return (true, x < 0 ? 1 : -1)
    }
}
