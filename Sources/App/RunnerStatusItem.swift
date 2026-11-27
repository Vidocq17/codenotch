import AppKit

/// How fast the dumbbell lifts: the busier the CPU, the quicker the strokes.
enum RunnerPace {
    /// Seconds per frame at rest and at full load.
    static let slowest: TimeInterval = 0.9
    static let fastest: TimeInterval = 0.08

    /// Seconds per frame for a CPU busy share in 0...1, out-of-range values clamped.
    static func interval(busy: Double) -> TimeInterval {
        let share = min(1, max(0, busy))
        return slowest - (slowest - fastest) * share
    }
}

/// A dumbbell lifted and lowered, drawn in code as an 18pt template image. Its
/// frames make one lift: down, rising, up, lowering. The plates are chunky
/// enough to read at menu bar size, where a thin figure does not.
enum DumbbellFrames {
    static let lifts: [CGFloat] = [0, 1.5, 3, 1.5]

    /// Drawn once: the menu bar asks for the same four frames over and over.
    static let images: [NSImage] = lifts.map(image(lift:))

    static func image(lift: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            draw(lift: lift)
            return true
        }
        // Template: macOS tints it dark or light to match the menu bar.
        image.isTemplate = true
        return image
    }

    /// Laid out top-down, as it reads on the page, then flipped to AppKit's
    /// bottom-up space by `rect`.
    private static func draw(lift: CGFloat) {
        NSColor.black.set()

        let middle: CGFloat = 9 - lift
        plate(x: 1, middle: middle)
        plate(x: 14, middle: middle)
        NSBezierPath(rect: rect(x: 4, top: middle - 1, width: 10, height: 2)).fill()
    }

    private static func plate(x: CGFloat, middle: CGFloat) {
        NSBezierPath(roundedRect: rect(x: x, top: middle - 4, width: 3, height: 8),
                     xRadius: 1, yRadius: 1).fill()
    }

    private static func rect(x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: x, y: 18 - top - height, width: width, height: height)
    }
}

/// A second menu bar item holding the dumbbell. It exists only while the
/// setting is on, and never touches the main Codenotch item.
@MainActor
final class RunnerStatusItem {
    private var item: NSStatusItem?
    private var task: Task<Void, Never>?
    private var previousTicks: [UInt32]?

    var isRunning: Bool { task != nil }

    func start() {
        guard task == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: 18)
        item.button?.toolTip = L10n.t("Dumbbell: lifts faster when the CPU is busier")
        self.item = item
        previousTicks = SystemSampler.cpuTicks()

        task = Task { [weak self] in
            var frame = 0
            while !Task.isCancelled {
                guard let self else { return }
                let images = DumbbellFrames.images
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
