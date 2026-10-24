//
//  MPEControllerOverride.swift
//  SYNT_16 R13-1 / SYNT_17 R14-1, R14-2: controller-set MPE configuration (runtime only).
//
//  SYNT_17 decision (nixter): what a controller sends (RPN 0, MCM / RPN 6) is RUNTIME state.
//  It is never written into AU parameters 163–166, the preset or `fullState`, so connecting a
//  controller does not dirty the project and the host never records it as automation.
//  AU params 163–166 / the preset stay the USER's settings.
//
//  Last change wins (R14-2): the effective value is `override ?? base`.
//  - A controller message sets the override.
//  - A user / automation / preset value that DIFFERS from the previous base clears the override
//    (so a ramp or a new preset value replaces the controller value at every change point).
//  - Re-sending the SAME base value (e.g. a snapshot of an unrelated knob move) keeps the override.
//  - MCM with N = 0 ("MPE off", sent by some controllers on disconnect) turns MPE off at runtime
//    only (MPE 1.0); it is never saved, so the user's saved MPE setting is never overridden and
//    is back after reopening the project. `clearOverrides()` drops all controller values.
//

import Foundation

/// Plain value type (no references, no ARC). One copy is written only on the render thread
/// (`AudioEngine.mpeCtl`), another only on main (`AudioEngine.controllerMPEMain`).
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

    @inline(__always) public mutating func adoptEnabled(_ v: Bool) -> Bool {
        if v != baseEnabled { enabled = nil }
        baseEnabled = v
        return enabled ?? v
    }
    @inline(__always) public mutating func adoptZone(_ v: MPEZone) -> MPEZone {
        if v != baseZone { zone = nil }
        baseZone = v
        return zone ?? v
    }
    @inline(__always) public mutating func adoptMemberCount(_ v: Int) -> Int {
        if v != baseMemberCount { memberCount = nil }
        baseMemberCount = v
        return memberCount ?? v
    }
    @inline(__always) public mutating func adoptMemberRange(_ v: Float) -> Float {
        if v != baseMemberRange { memberRange = nil }
        baseMemberRange = v
        return memberRange ?? v
    }
    @inline(__always) public mutating func adoptMasterRange(_ v: Float) -> Float {
        if v != baseMasterRange { masterRange = nil }
        baseMasterRange = v
        return masterRange ?? v
    }
    /// Drop every controller value, back to the user's settings.
    @inline(__always) public mutating func clearOverrides() {
        enabled = nil; zone = nil; memberCount = nil; memberRange = nil; masterRange = nil
    }
    public var hasOverride: Bool {
        enabled != nil || zone != nil || memberCount != nil || memberRange != nil || masterRange != nil
    }
}

public extension AudioEngine {
    /// SYNT_18 R15-8: "Reset to my settings". Main mirror now, render via the command queue.
    func resetControllerMPEOverrides() {
        controllerMPEMain.clearOverrides()
        mpeEnabled = controllerMPEMain.baseEnabled
        mpeZone = controllerMPEMain.baseZone
        mpeMemberChannelCount = controllerMPEMain.baseMemberCount
        mpePitchBendRange = controllerMPEMain.baseMemberRange
        controllerMasterPitchBendRange = nil
        if commandQueue.push(.clearMPEControllerOverrides) { mpeResetIssued &+= 1 }
    }

    // SYNT_18 R15-3: when a host value drops a controller override on render, tell main
    // through the existing lock-free mailbox (main used to keep showing the stale controller value).
    @inline(__always) func adoptHostMPEEnabled(_ v: Bool) {
        let had = mpeCtl.enabled != nil
        cachedMpeEnabled = mpeCtl.adoptEnabled(v)
        if had && mpeCtl.enabled == nil { publishMPEConfigRT() }
    }
    @inline(__always) func adoptHostMPEZone(_ v: MPEZone) {
        let had = mpeCtl.zone != nil
        cachedMpeZone = mpeCtl.adoptZone(v)
        if had && mpeCtl.zone == nil { publishMPEConfigRT() }
    }
    @inline(__always) func adoptHostMPEMemberCount(_ v: Int) {
        let had = mpeCtl.memberCount != nil
        cachedMpeMemberChannelCount = mpeCtl.adoptMemberCount(v)
        if had && mpeCtl.memberCount == nil { publishMPEConfigRT() }
    }
    @inline(__always) func adoptHostMPEMemberRange(_ v: Float) {
        let had = mpeCtl.memberRange != nil
        cachedMpePitchBendRange = mpeCtl.adoptMemberRange(v)
        if had && mpeCtl.memberRange == nil { publishMPEConfigRT() }
    }
    @inline(__always) func adoptHostMasterBendRange(_ v: Float) {
        let had = mpeCtl.masterRange != nil
        cachedPitchBendRange = mpeCtl.adoptMasterRange(v)
        if had && mpeCtl.masterRange == nil { publishMPEConfigRT(masterRangeChanged: true) }
    }
}

public extension MPEControllerOverride {
    /// SYNT_17 R14-8: UI label for the controller's master bend range (runtime only).
    /// SYNT_18 R15-8: one-line UI summary of the controller values; nil when there is no override.
    var overrideSummary: String? {
        guard hasOverride else { return nil }
        func st(_ r: Float) -> String { r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r) }
        var parts: [String] = []
        if let e = enabled, !e { parts.append("MPE off") }
        if let z = zone { parts.append(z == .lower ? "Lower zone" : "Upper zone") }
        if let c = memberCount { parts.append("\(c) members") }
        if let r = memberRange { parts.append("±\(st(r)) st") }
        if let m = masterRange { parts.append("master ±\(st(m)) st") }
        if parts.isEmpty, enabled == true { parts.append("MPE on") }
        return "Controller: " + parts.joined(separator: ", ")
    }

    static func masterBendLabel(_ range: Float?) -> String? {
        guard let r = range else { return nil }
        let txt = r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r)
        return "Controller Master Bend: ±\(txt) st"
    }
}
