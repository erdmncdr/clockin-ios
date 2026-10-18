import AppKit
import SwiftUI

/// The pinned timer is a borderless panel: no title bar to drag and no edges
/// AppKit resizes reliably. These pieces give it both, and keep it on screen.
enum PinnedFrame {
    /// `frame` moved (and if needed shrunk) so it lies inside `visible`.
    /// A panel saved on a larger screen, or grown by a layout change, could
    /// otherwise sit half off-screen where it cannot be grabbed.
    static func fitted(_ frame: NSRect, in visible: NSRect, minimum: NSSize) -> NSRect {
        var result = frame
        result.size.width = min(max(result.width, minimum.width), visible.width)
        result.size.height = min(max(result.height, minimum.height), visible.height)
        result.origin.x = min(max(result.minX, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        return result
    }

    /// The frame after dragging the bottom-right corner by (dx, dy) in screen
    /// points: the top-left corner stays put.
    static func resized(_ frame: NSRect, dx: CGFloat, dy: CGFloat, minimum: NSSize, maximum: NSSize) -> NSRect {
        let width = min(max(frame.width + dx, minimum.width), maximum.width)
        let height = min(max(frame.height - dy, minimum.height), maximum.height)
        return NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
    }
}

/// Behind the timer's content: a press on any empty part drags the panel.
struct PinnedWindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        // The panel never becomes key; without this the first press is eaten.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}
}

/// The bottom-right corner: drag to resize, top-left corner fixed.
struct PinnedResizeGrip: NSViewRepresentable {
    var onEnd: @MainActor () -> Void

    final class GripView: NSView {
        var onEnd: @MainActor () -> Void = {}
        private var start: (point: NSPoint, frame: NSRect)?

        override var mouseDownCanMoveWindow: Bool { false }
        // The panel never becomes key; without this the first press is eaten.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            if #available(macOS 15.0, *) {
                addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
            } else {
                addCursorRect(bounds, cursor: .crosshair)
            }
        }

        private func screenPoint(_ event: NSEvent) -> NSPoint {
            window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            start = (screenPoint(event), window.frame)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start, let window else { return }
            let point = screenPoint(event)
            let frame = PinnedFrame.resized(start.frame, dx: point.x - start.point.x, dy: point.y - start.point.y,
                                            minimum: window.minSize, maximum: window.maxSize)
            window.setFrame(frame, display: true)
        }

        override func mouseUp(with event: NSEvent) {
            guard start != nil else { return }
            start = nil
            onEnd()
        }
    }

    func makeNSView(context: Context) -> GripView {
        let view = GripView()
        view.onEnd = onEnd
        return view
    }

    func updateNSView(_ nsView: GripView, context: Context) { nsView.onEnd = onEnd }
}
