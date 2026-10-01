import AppKit
import SwiftUI

/// Monitor yalniz bu gorunur grafik dikdortgeni ve kendi penceresinde calisir.
struct MacPeriodNavigation: ViewModifier {
    var enabled = true
    var capturesScroll = true
    let onPage: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .focusable(enabled)
            .onKeyPress(.leftArrow) {
                guard enabled else { return .ignored }
                onPage(-1); return .handled
            }
            .onKeyPress(.rightArrow) {
                guard enabled else { return .ignored }
                onPage(1); return .handled
            }
            .background(MacPeriodEventRegion(enabled: enabled, capturesScroll: capturesScroll, onPage: onPage))
    }
}

private struct MacPeriodEventRegion: NSViewRepresentable {
    let enabled: Bool
    let capturesScroll: Bool
    let onPage: (Int) -> Void

    func makeNSView(context: Context) -> Region { Region() }
    func updateNSView(_ view: Region, context: Context) {
        view.enabled = enabled
        view.capturesScroll = capturesScroll
        view.onPage = onPage
    }
    static func dismantleNSView(_ view: Region, coordinator: ()) { view.stopMonitoring() }

    final class Region: NSView {
        var enabled = true
        var capturesScroll = true
        var onPage: ((Int) -> Void)?
        private var monitor: Any?
        private var scroll = MacPeriodScroll()

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] event in
                // AppKit yerel event monitorunu ana thread'de cagirir.
                let consumed = MainActor.assumeIsolated {
                    guard let self else { return false }
                    return self.handle(event) == nil
                }
                return consumed ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            scroll = MacPeriodScroll()
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard enabled, let window, event.window === window, window.isKeyWindow,
                  window.attachedSheet == nil, !isHiddenOrHasHiddenAncestor else { return event }
            let point = event.type == .keyDown ? window.mouseLocationOutsideOfEventStream : event.locationInWindow
            guard visibleRect.contains(convert(point, from: nil)) else { return event }
            if event.type == .keyDown {
                guard !event.isARepeat, event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                      !(window.firstResponder is NSTextView), !(window.firstResponder is NSTextField) else { return event }
                if event.keyCode == 123 { onPage?(-1); return nil }
                if event.keyCode == 124 { onPage?(1); return nil }
                return event
            }
            guard capturesScroll else { return event }
            let phase: MacPeriodScroll.Phase
            if event.phase.contains(.began) { phase = .began }
            else if event.phase.contains(.cancelled) { phase = .cancelled }
            else if event.phase.contains(.ended) { phase = .ended }
            else if event.phase.contains(.changed) || event.phase.contains(.stationary) { phase = .changed }
            else { phase = .none }
            let result = scroll.update(x: event.scrollingDeltaX, y: event.scrollingDeltaY, phase: phase,
                momentum: !event.momentumPhase.isEmpty, precise: event.hasPreciseScrollingDeltas, time: event.timestamp)
            if let direction = result.direction { onPage?(direction) }
            return result.consumed ? nil : event
        }
    }
}
