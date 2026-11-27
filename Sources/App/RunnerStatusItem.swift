import AppKit

/// How fast the dog runs: the calmer the CPU, the quicker its strides; the
/// busier it gets, the more slowly the dog goes.
enum RunnerPace {
    /// Seconds per frame at rest (quick) and at full load (slow).
    static let fastest: TimeInterval = 0.08
    static let slowest: TimeInterval = 0.9

    /// Seconds per frame for a CPU busy share in 0...1, out-of-range values clamped.
    static func interval(busy: Double) -> TimeInterval {
        let share = min(1, max(0, busy))
        return fastest + (slowest - fastest) * share
    }
}

/// The running dog from RunCatNeo (Apache-2.0, see NOTICE): five frames of one
/// stride, black silhouettes shipped as template images so macOS tints them to
/// match the menu bar. Each frame is 35pt by 18pt.
enum DogFrames {
    static let frameCount = 5

    /// Loaded once: the menu bar asks for the same frames over and over.
    static let images: [NSImage] = (0..<frameCount).compactMap { index in
        guard let image = NSImage(named: "runner-dog-\(index)") else { return nil }
        image.size = NSSize(width: 35, height: 18)
        image.isTemplate = true
        return image
    }
}

/// A second menu bar item holding the running dog. It exists only while the
/// setting is on, and never touches the main Codenotch item.
@MainActor
final class RunnerStatusItem {
    private var item: NSStatusItem?
    private var task: Task<Void, Never>?
    private var previousTicks: [UInt32]?

    var isRunning: Bool { task != nil }

    func start() {
        guard task == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.toolTip = L10n.t("Running dog: runs slower when the CPU is busier")
        self.item = item
        previousTicks = SystemSampler.cpuTicks()

        task = Task { [weak self] in
            var frame = 0
            while !Task.isCancelled {
                guard let self else { return }
                let images = DogFrames.images
                self.item?.button?.image = images[frame % images.count]
                frame += 1
                let interval = RunnerPace.interval(busy: self.busyShare())
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        previousTicks = nil
    }

    /// The CPU share busy since the last frame, from two tick readings.
    private func busyShare() -> Double {
        let now = SystemSampler.cpuTicks()
        defer { previousTicks = now }
        guard let before = previousTicks, let after = now else { return 0 }
        return SystemMetricMath.busyFraction(from: before, to: after) ?? 0
    }
}
