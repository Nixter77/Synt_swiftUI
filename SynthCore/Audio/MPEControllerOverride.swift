//
//  MPEControllerOverride.swift
//  SYNT_16 R13-1: controller-set MPE configuration that survives host snapshots.
//

import Foundation

/// Plain value type (no references, no ARC). Written only on the render thread.
public struct MPEControllerOverride: Sendable {
    public var enabled: Bool? = nil
    public var zone: MPEZone? = nil
    public var memberCount: Int? = nil
    public var memberRange: Float? = nil
    public var masterRange: Float? = nil
    public var baseEnabled: Bool = false
    public var baseZone: MPEZone = .lower
    public var baseMemberCount: Int = 15
    public var baseMemberRange: Float = 48
    public var baseMasterRange: Float = 2
    public init() {}
}

public extension AudioEngine {
    @inline(__always) func adoptHostMPEEnabled(_ v: Bool) {
        if v != mpeCtl.baseEnabled { mpeCtl.enabled = nil }
        mpeCtl.baseEnabled = v
        cachedMpeEnabled = mpeCtl.enabled ?? v
    }
    @inline(__always) func adoptHostMPEZone(_ v: MPEZone) {
        if v != mpeCtl.baseZone { mpeCtl.zone = nil }
        mpeCtl.baseZone = v
        cachedMpeZone = mpeCtl.zone ?? v
    }
    @inline(__always) func adoptHostMPEMemberCount(_ v: Int) {
        if v != mpeCtl.baseMemberCount { mpeCtl.memberCount = nil }
        mpeCtl.baseMemberCount = v
        cachedMpeMemberChannelCount = mpeCtl.memberCount ?? v
    }
    @inline(__always) func adoptHostMPEMemberRange(_ v: Float) {
        if v != mpeCtl.baseMemberRange { mpeCtl.memberRange = nil }
        mpeCtl.baseMemberRange = v
        cachedMpePitchBendRange = mpeCtl.memberRange ?? v
    }
    @inline(__always) func adoptHostMasterBendRange(_ v: Float) {
        if v != mpeCtl.baseMasterRange { mpeCtl.masterRange = nil }
        mpeCtl.baseMasterRange = v
        cachedPitchBendRange = mpeCtl.masterRange ?? v
    }
}
