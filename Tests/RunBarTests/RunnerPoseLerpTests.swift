import XCTest
@testable import RunBar

final class RunnerPoseLerpTests: XCTestCase {

    // MARK: - lerpAngle (shortest-path)

    func test_lerpAngle_identity() {
        XCTAssertEqual(RunnerPose.lerpAngle(90, 90, 0.5), 90, accuracy: 0.01)
    }

    func test_lerpAngle_linear_within_range() {
        XCTAssertEqual(RunnerPose.lerpAngle(0, 180, 0.5), 90, accuracy: 0.01)
        XCTAssertEqual(RunnerPose.lerpAngle(45, 135, 0.5), 90, accuracy: 0.01)
    }

    func test_lerpAngle_takes_short_path_across_zero() {
        // 350° → 10° doit passer par 0° (delta=20°), pas par 180° (delta=-340°).
        // À t=0.5 on attend 0° (= 360°).
        let mid = RunnerPose.lerpAngle(350, 10, 0.5)
        // Tolère 0 ou 360.
        let normalized = mid > 180 ? mid - 360 : mid
        XCTAssertEqual(normalized, 0, accuracy: 0.5)
    }

    func test_lerpAngle_short_path_other_direction() {
        // 10° → 350° doit passer par 0° (delta=-20°), pas par 180°.
        let mid = RunnerPose.lerpAngle(10, 350, 0.5)
        let normalized = mid > 180 ? mid - 360 : mid
        XCTAssertEqual(normalized, 0, accuracy: 0.5)
    }

    func test_lerpAngle_at_zero_returns_a() {
        XCTAssertEqual(RunnerPose.lerpAngle(45, 135, 0), 45, accuracy: 0.01)
    }

    func test_lerpAngle_at_one_returns_b() {
        XCTAssertEqual(RunnerPose.lerpAngle(45, 135, 1), 135, accuracy: 0.01)
    }

    func test_lerpAngle_handles_180_degree_difference() {
        // Cas dégénéré : 0° → 180°. Le shortest-path n'est pas défini de manière
        // unique (les deux directions ont la même longueur). On accepte les deux.
        let mid = RunnerPose.lerpAngle(0, 180, 0.5)
        XCTAssertTrue(abs(mid - 90) < 0.5 || abs(mid - 270) < 0.5)
    }

    // MARK: - Pose interpolation

    func test_lerp_at_zero_returns_a() {
        let a = RunnerPose.base()
        var b = RunnerPose.base()
        b.headOffsetY = 5
        let result = RunnerPose.lerp(a, b, t: 0)
        XCTAssertEqual(result.headOffsetY, a.headOffsetY, accuracy: 0.01)
    }

    func test_lerp_at_one_returns_b() {
        let a = RunnerPose.base()
        var b = RunnerPose.base()
        b.headOffsetY = 5
        let result = RunnerPose.lerp(a, b, t: 1)
        XCTAssertEqual(result.headOffsetY, b.headOffsetY, accuracy: 0.01)
    }

    func test_lerp_midway_averages_scalars() {
        let a = RunnerPose.base()
        var b = RunnerPose.base()
        b.headOffsetY = 4
        b.thighLength = 19
        let result = RunnerPose.lerp(a, b, t: 0.5)
        XCTAssertEqual(result.headOffsetY, 2, accuracy: 0.01)
        XCTAssertEqual(result.thighLength, (a.thighLength + 19) / 2, accuracy: 0.01)
    }

    func test_lerp_clamps_t_below_zero() {
        let a = RunnerPose.base()
        var b = RunnerPose.base()
        b.headOffsetY = 5
        let result = RunnerPose.lerp(a, b, t: -1)
        XCTAssertEqual(result.headOffsetY, a.headOffsetY, accuracy: 0.01)
    }

    func test_lerp_clamps_t_above_one() {
        let a = RunnerPose.base()
        var b = RunnerPose.base()
        b.headOffsetY = 5
        let result = RunnerPose.lerp(a, b, t: 2)
        XCTAssertEqual(result.headOffsetY, b.headOffsetY, accuracy: 0.01)
    }
}
