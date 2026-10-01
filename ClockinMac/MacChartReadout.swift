import Charts
import SwiftUI

/// Salt okunur saat grafiklerine isaretci degeri ekler; iPhone'a uygulanmaz.
struct MacChartReadout: ViewModifier {
    let values: [(date: Date, text: String)]
    @State private var readout: String?
    @State private var delivery = MacDeferredValue<String?>()

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let anchor = proxy.plotFrame {
                        let frame = geometry[anchor]
                        Color.clear.contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard frame.contains(location),
                                          let date = proxy.value(atX: location.x - frame.minX, as: Date.self),
                                          Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: .now) else {
                                        delivery.submit(nil, to: $readout); return
                                    }
                                    delivery.submit(values.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.text, to: $readout)
                                case .ended: delivery.submit(nil, to: $readout)
                                }
                            }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if let readout {
                    Text(readout).font(.caption).monospacedDigit()
                        .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: values.map(\.date)) { _, _ in delivery.submit(nil, to: $readout) }
            .onChange(of: values.map(\.text)) { _, _ in delivery.submit(nil, to: $readout) }
            .onDisappear { delivery.submit(nil, to: $readout) }
    }
}
