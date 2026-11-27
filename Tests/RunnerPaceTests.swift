import XCTest

/// The runner's stride follows the CPU: a calmer machine, a quicker figure; a
/// busier one, a slower figure.
final class RunnerPaceTests: XCTestCase {
    func testIdleIsFastestAndFullLoadIsSlowest() {
        XCTAssertEqual(RunnerPace.interval(busy: 0), RunnerPace.fastest, accuracy: 1e-9)
        XCTAssertEqual(RunnerPace.interval(busy: 1), RunnerPace.slowest, accuracy: 1e-9)
    }

    func testBusierIsNeverFaster() {
        let shares = stride(from: 0.0, through: 1.0, by: 0.1).map { $0 }
        let intervals = shares.map(RunnerPace.interval(busy:))
        XCTAssertEqual(intervals, intervals.sorted())
    }

    func testOutOfRangeSharesAreClamped() {
        XCTAssertEqual(RunnerPace.interval(busy: -3), RunnerPace.fastest, accuracy: 1e-9)
        XCTAssertEqual(RunnerPace.interval(busy: 7), RunnerPace.slowest, accuracy: 1e-9)
    }

    /// The dog's images come from the app's asset catalog, which this unhosted
    /// test bundle cannot see, so only the frame count is checked here. The
    /// template tint is checked by running the app.
    func testTheDogHasFiveFrames() {
        XCTAssertEqual(DogFrames.frameCount, 5)
    }
}
