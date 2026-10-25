import XCTest
@testable import SynthCore

/// SYNT_27 Stage 1 (Swift 6 prep): enums stored in the Sendable `RTPresetSnapshot` are explicitly
/// Sendable (public enums are not inferred Sendable across modules), and `defaultMaxSteps` is usable
/// off the main actor. Cannot fail on old code in Swift 5 / minimal concurrency (missing Sendable is only a
/// warning there); it pins the conformances so a Swift 6 switch keeps compiling. Real check: 0 Swift-6 warnings in SynthCore.
final class Stage27SendableTests: XCTestCase {
    private func requireSendable<T: Sendable>(_: T.Type) {}
    func testSnapshotEnumsAreSendable() {
        requireSendable(WaveformType.self); requireSendable(ArpeggiatorMode.self)
        requireSendable(TimeDivision.self); requireSendable(SyncSource.self)
        requireSendable(VoiceMode.self); requireSendable(NoiseColor.self)
        requireSendable(ChordMode.self); requireSendable(FilterType.self)
        requireSendable(LFOTarget.self); requireSendable(PhaserMode.self)
        requireSendable(DistortionType.self)
        requireSendable(RTPresetSnapshot.self)
    }
    nonisolated func testDefaultMaxStepsIsNonisolated() {
        XCTAssertEqual(PatchHistoryManager.defaultMaxSteps, 64)
    }
}
