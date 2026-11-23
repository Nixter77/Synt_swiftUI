//
//  EnumCaseEquality.swift
//  SynthCore
//
//  Payload-free `String` raw-value enums otherwise get `Equatable` from the stdlib
//  `RawRepresentable ==`, which compares the raw *strings* (string compare plus
//  retain/release). The render loop compares these enums per voice per sample
//  (`lfoTarget == .pan`, `filterType == .ladder`, …); Instruments showed ~15 % of
//  render time in that path. Comparing the 1-byte case tag is the same answer
//  (every case has a distinct raw value) at integer cost. No behaviour change:
//  `EnumCaseEqualityTests` checks `==` against `rawValue ==` for every case pair.
//

@inline(__always)
@usableFromInline
func syntCaseTag<E>(_ value: E) -> UInt8 {
    withUnsafeBytes(of: value) { $0[0] }
}


extension AmpRetriggerMode {
    @inlinable @inline(__always)
    public static func == (lhs: AmpRetriggerMode, rhs: AmpRetriggerMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension ArpeggiatorMode {
    @inlinable @inline(__always)
    public static func == (lhs: ArpeggiatorMode, rhs: ArpeggiatorMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension CharacterMode {
    @inlinable @inline(__always)
    public static func == (lhs: CharacterMode, rhs: CharacterMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension ChordMode {
    @inlinable @inline(__always)
    public static func == (lhs: ChordMode, rhs: ChordMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension ChorusMode {
    @inlinable @inline(__always)
    public static func == (lhs: ChorusMode, rhs: ChorusMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension DSPMSEGSyncMode {
    @inlinable @inline(__always)
    public static func == (lhs: DSPMSEGSyncMode, rhs: DSPMSEGSyncMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension DSPMSEGTriggerMode {
    @inlinable @inline(__always)
    public static func == (lhs: DSPMSEGTriggerMode, rhs: DSPMSEGTriggerMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension DistortionType {
    @inlinable @inline(__always)
    public static func == (lhs: DistortionType, rhs: DistortionType) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension DualFilterRouting {
    @inlinable @inline(__always)
    public static func == (lhs: DualFilterRouting, rhs: DualFilterRouting) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension EnvelopeModel {
    @inlinable @inline(__always)
    public static func == (lhs: EnvelopeModel, rhs: EnvelopeModel) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension FMRoute {
    @inlinable @inline(__always)
    public static func == (lhs: FMRoute, rhs: FMRoute) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension FilterType {
    @inlinable @inline(__always)
    public static func == (lhs: FilterType, rhs: FilterType) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension GlideMode {
    @inlinable @inline(__always)
    public static func == (lhs: GlideMode, rhs: GlideMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension GlobalVoiceSourcePolicy {
    @inlinable @inline(__always)
    public static func == (lhs: GlobalVoiceSourcePolicy, rhs: GlobalVoiceSourcePolicy) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension LFOMode {
    @inlinable @inline(__always)
    public static func == (lhs: LFOMode, rhs: LFOMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension LFOTarget {
    @inlinable @inline(__always)
    public static func == (lhs: LFOTarget, rhs: LFOTarget) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension ModCurve {
    @inlinable @inline(__always)
    public static func == (lhs: ModCurve, rhs: ModCurve) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension ModDestination {
    @inlinable @inline(__always)
    public static func == (lhs: ModDestination, rhs: ModDestination) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension ModSource {
    @inlinable @inline(__always)
    public static func == (lhs: ModSource, rhs: ModSource) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension MonoPriority {
    @inlinable @inline(__always)
    public static func == (lhs: MonoPriority, rhs: MonoPriority) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension NoiseColor {
    @inlinable @inline(__always)
    public static func == (lhs: NoiseColor, rhs: NoiseColor) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension OscPhaseMode {
    @inlinable @inline(__always)
    public static func == (lhs: OscPhaseMode, rhs: OscPhaseMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension PhaserMode {
    @inlinable @inline(__always)
    public static func == (lhs: PhaserMode, rhs: PhaserMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension SyncSource {
    @inlinable @inline(__always)
    public static func == (lhs: SyncSource, rhs: SyncSource) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension TimeDivision {
    @inlinable @inline(__always)
    public static func == (lhs: TimeDivision, rhs: TimeDivision) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension VelocityCurve {
    @inlinable @inline(__always)
    public static func == (lhs: VelocityCurve, rhs: VelocityCurve) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension VoiceMode {
    @inlinable @inline(__always)
    public static func == (lhs: VoiceMode, rhs: VoiceMode) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension WaveformType {
    @inlinable @inline(__always)
    public static func == (lhs: WaveformType, rhs: WaveformType) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}

extension MPEZone {
    @inlinable @inline(__always)
    public static func == (lhs: MPEZone, rhs: MPEZone) -> Bool { syntCaseTag(lhs) == syntCaseTag(rhs) }
}
