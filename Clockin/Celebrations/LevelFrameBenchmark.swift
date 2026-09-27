#if DEBUG
import SwiftUI
import Darwin

struct LevelFrameBenchmark: View {
    @State private var started = false

    var body: some View {
        Color.clear.task { @MainActor in
            guard !started else { return }
            started = true
            run()
        }
    }

    @MainActor private func run() {
        var overall: [Double] = []
        for level in [1, 150, 450, 451, 600] {
            for companion in [false, true] {
                var samples: [Double] = []
                for frame in 0..<240 {
                    let elapsed: Double = autoreleasepool {
                        let start = ContinuousClock.now
                        let renderer = ImageRenderer(content:
                            LevelUpStage(level: level, t: Double(frame) * 6 / 239,
                                         companion: companion, moving: true)
                                .frame(width: 402, height: companion ? 396 : 300)
                                .environment(\.displayScale, 3)
                                .environment(\.colorScheme, .dark)
                                .environment(\.dynamicTypeSize, .large))
                        renderer.scale = 3
                        guard let image = renderer.cgImage, image.width == 1206,
                              image.height == (companion ? 1188 : 900) else {
                            print("LEVEL_FRAMES ERROR: image rendering failed")
                            exit(1)
                        }
                        let duration = start.duration(to: .now).components
                        return Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
                    }
                    samples.append(elapsed)
                }
                report("level=\(level) companion=\(companion)", samples)
                overall.append(contentsOf: samples)
            }
        }
        report("overall", overall)
        exit(0)
    }

    private func report(_ label: String, _ samples: [Double]) {
        let sorted = samples.sorted()
        let mean = samples.reduce(0, +) / Double(samples.count)
        let p95 = sorted[Int(ceil(Double(samples.count) * 0.95)) - 1]
        print(String(format: "LEVEL_FRAMES %@ n=%d mean=%.3f p95=%.3f max=%.3f ms",
                     label, samples.count, mean, p95, sorted.last!))
    }
}
#endif
