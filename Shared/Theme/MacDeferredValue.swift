#if os(macOS)
import Foundation

/// AppKit yerlesim/izleme geri cagrilari SwiftUI durumunu ayni geciste yazamaz.
/// Son deger kazanir; esitlik teslim aninda okunur, eski yakalamadan degil.
@MainActor
final class MacDeferredValue<Value: Equatable> {
    typealias Delivery = @MainActor () -> Void
    private let enqueue: (@escaping Delivery) -> Void
    private var pending: Delivery?
    private var scheduled = false
    private var generation = 0

    init(enqueue: @escaping (@escaping Delivery) -> Void = { delivery in
        DispatchQueue.main.async { delivery() }
    }) {
        self.enqueue = enqueue
    }

    func submit(_ value: Value, read: @escaping () -> Value, write: @escaping (Value) -> Void) {
        pending = {
            guard read() != value else { return }
            write(value)
        }
        guard !scheduled else { return }
        scheduled = true
        let ticket = generation
        enqueue { [weak self] in
            guard let self, ticket == self.generation else { return }
            let delivery = self.pending
            self.pending = nil
            self.scheduled = false
            delivery?()
        }
    }

    func cancel() {
        generation += 1
        pending = nil
        scheduled = false
    }
}
#endif
