import XCTest
@testable import TunnelPong

final class CourtMathTests: XCTestCase {

    // MARK: - Projector

    func testScaleAtNearPlaneIsOne() {
        let p = Projector(focal: 320, center: .zero)
        XCTAssertEqual(p.scale(z: 0), 1, accuracy: 0.0001)
    }

    func testScaleShrinksWithDepth() {
        let p = Projector(focal: 320, center: .zero)
        let near = p.scale(z: 0)
        let mid = p.scale(z: 320)
        let far = p.scale(z: 900)
        XCTAssertGreaterThan(near, mid)
        XCTAssertGreaterThan(mid, far)
        XCTAssertEqual(mid, 0.5, accuracy: 0.0001) // 320 / (320 + 320)
    }

    func testProjectCentersAtOrigin() {
        let p = Projector(focal: 320, center: CGPoint(x: 200, y: 400))
        let pt = p.project(x: 0, y: 0, z: 100)
        XCTAssertEqual(pt.x, 200, accuracy: 0.0001)
        XCTAssertEqual(pt.y, 400, accuracy: 0.0001)
    }

    func testScaleClampsWhenPastCamera() {
        let p = Projector(focal: 320, center: .zero)
        // z = -focal would be a divide-by-zero without the clamp.
        let s = p.scale(z: -320)
        XCTAssertTrue(s.isFinite)
        XCTAssertGreaterThan(s, 0)
        // Floor is z = -focal + 1 → scale = focal / 1 = focal.
        XCTAssertEqual(s, 320, accuracy: 0.0001)
    }

    // MARK: - Reflect (wall-fold)

    func testReflectInsideUnchanged() {
        XCTAssertEqual(CourtMath.reflect(30, limit: 100), 30, accuracy: 0.0001)
        XCTAssertEqual(CourtMath.reflect(-40, limit: 100), -40, accuracy: 0.0001)
    }

    func testReflectOneWallBounce() {
        // Past +limit by 20 → mirrors to +limit - 20.
        XCTAssertEqual(CourtMath.reflect(120, limit: 100), 80, accuracy: 0.0001)
        // Past -limit by 20 → mirrors to -limit + 20.
        XCTAssertEqual(CourtMath.reflect(-120, limit: 100), -80, accuracy: 0.0001)
    }

    func testReflectZeroLimit() {
        XCTAssertEqual(CourtMath.reflect(50, limit: 0), 0, accuracy: 0.0001)
    }

    func testReflectStaysWithinBounds() {
        let limit: CGFloat = 75
        for raw: CGFloat in [-500, -200, -75, 0, 75, 200, 500, 1234.5] {
            let r = CourtMath.reflect(raw, limit: limit)
            XCTAssertGreaterThanOrEqual(r, -limit - 0.0001)
            XCTAssertLessThanOrEqual(r, limit + 0.0001)
        }
    }

    // MARK: - Velocity renorm

    func testRenormHitsTargetSpeed() {
        var vx: CGFloat = 3, vy: CGFloat = 4, vz: CGFloat = 0
        CourtMath.renormVelocity(vx: &vx, vy: &vy, vz: &vz, speed: 100, minVzFraction: 0.55)
        let mag = sqrt(vx * vx + vy * vy + vz * vz)
        XCTAssertEqual(mag, 100, accuracy: 0.01)
    }

    func testRenormEnforcesMinVz() {
        var vx: CGFloat = 100, vy: CGFloat = 0, vz: CGFloat = 1
        CourtMath.renormVelocity(vx: &vx, vy: &vy, vz: &vz, speed: 100, minVzFraction: 0.55)
        XCTAssertGreaterThanOrEqual(abs(vz), 55 - 0.01)
        let mag = sqrt(vx * vx + vy * vy + vz * vz)
        XCTAssertEqual(mag, 100, accuracy: 0.01)
    }

    func testRenormPreservesVzSign() {
        var vx: CGFloat = 10, vy: CGFloat = 0, vz: CGFloat = -1
        CourtMath.renormVelocity(vx: &vx, vy: &vy, vz: &vz, speed: 200, minVzFraction: 0.55)
        XCTAssertLessThan(vz, 0)
    }

    // MARK: - Move toward

    func testMoveTowardCapsStep() {
        XCTAssertEqual(CourtMath.moveToward(0, target: 100, maxStep: 10), 10, accuracy: 0.0001)
        XCTAssertEqual(CourtMath.moveToward(50, target: 40, maxStep: 3), 47, accuracy: 0.0001)
    }

    func testMoveTowardReachesTarget() {
        XCTAssertEqual(CourtMath.moveToward(5, target: 8, maxStep: 10), 8, accuracy: 0.0001)
    }

    // MARK: - Ring helpers

    func testRingTEndpoints() {
        XCTAssertEqual(CourtMath.ringT(index: 0, ringCount: 13), 0, accuracy: 0.0001)
        XCTAssertEqual(CourtMath.ringT(index: 12, ringCount: 13), 1, accuracy: 0.0001)
    }

    func testRingTSafeWhenCountIsOne() {
        // Must not divide by zero.
        XCTAssertEqual(CourtMath.ringT(index: 0, ringCount: 1), 0, accuracy: 0.0001)
    }

    func testRingIndexClamped() {
        XCTAssertEqual(CourtMath.ringIndex(z: -50, zFar: 900, ringCount: 13), 0)
        XCTAssertEqual(CourtMath.ringIndex(z: 2000, zFar: 900, ringCount: 13), 12)
        XCTAssertEqual(CourtMath.ringIndex(z: 0, zFar: 900, ringCount: 13), 0)
        XCTAssertEqual(CourtMath.ringIndex(z: 900, zFar: 900, ringCount: 13), 12)
    }
}
