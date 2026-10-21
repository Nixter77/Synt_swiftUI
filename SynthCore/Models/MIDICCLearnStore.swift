//
//  MIDICCLearnStore.swift
//  Synt_swiftUI
//
//  Stores and manages MIDI CC -> MIDIControlTarget mappings in UserDefaults.
//

import Foundation

public enum MIDIControlTarget: String, CaseIterable, Codable, Hashable {
    // 13 ModDestination targets (exact rawValues matching ModDestination.rawValue for backward compatibility)
    case pitch1 = "Pitch OSC1"
    case pitch2 = "Pitch OSC2"
    case cutoff = "Filter Cutoff"
    case resonance = "Resonance"
    case amp = "Amplitude"
    case pan = "Pan"
    case pwm1 = "PWM OSC1"
    case pwm2 = "PWM OSC2"
    case wtMorph1 = "WT Morph 1"
    case wtMorph2 = "WT Morph 2"
    case lfoRate = "LFO Rate"
    case lfoDepth = "LFO Depth"
    case mix = "Osc Mix"

    // ADSR (Amp & Filter)
    case attack = "Amp Attack"
    case decay = "Amp Decay"
    case sustain = "Amp Sustain"
    case release = "Amp Release"
    case filterAttack = "Filter Attack"
    case filterDecay = "Filter Decay"
    case filterSustain = "Filter Sustain"
    case filterRelease = "Filter Release"
    case filterEnvelopeAmount = "Filter Env Amount"

    // FX Mix & parameters
    case reverbMix = "Reverb Mix"
    case reverbRoomSize = "Reverb Room Size"
    case reverbShimmer = "Reverb Shimmer"
    case delayMix = "Delay Mix"
    case delayTime = "Delay Time"
    case delayFeedback = "Delay Feedback"
    case chorusMix = "Chorus Mix"
    case chorusRate = "Chorus Rate"
    case chorusDepth = "Chorus Depth"
    case distortionMix = "Distortion Mix"
    case distortionDrive = "Distortion Drive"
    case phaserMix = "Phaser Mix"
    case phaserRate = "Phaser Rate"
    case phaserDepth = "Phaser Depth"

    // Synthesis & Unison
    case osc1Volume = "Osc 1 Volume"
    case osc2Volume = "Osc 2 Volume"
    case subOscVolume = "Sub Osc Volume"
    case fmAmount = "FM Amount"
    case ringModAmount = "Ring Mod Amount"
    case unisonDetune = "Unison Detune"
    case unisonSpread = "Unison Spread"
    case analogDrift = "Analog Drift"
    case portamento = "Portamento"

    // Performance Macros
    case macro1 = "Macro 1"
    case macro2 = "Macro 2"
    case macro3 = "Macro 3"
    case macro4 = "Macro 4"
    case finePitch = "Fine Pitch"

    public init(_ destination: ModDestination) {
        switch destination {
        case .pitch1: self = .pitch1
        case .pitch2: self = .pitch2
        case .cutoff: self = .cutoff
        case .resonance: self = .resonance
        case .amp: self = .amp
        case .pan: self = .pan
        case .pwm1: self = .pwm1
        case .pwm2: self = .pwm2
        case .wtMorph1: self = .wtMorph1
        case .wtMorph2: self = .wtMorph2
        case .lfoRate: self = .lfoRate
        case .lfoDepth: self = .lfoDepth
        case .mix: self = .mix
        case .finePitch: self = .finePitch
        case .fm: self = .fmAmount
        case .chorusMix: self = .chorusMix
        case .delayMix: self = .delayMix
        case .reverbMix: self = .reverbMix
        case .vowel: self = .cutoff
        }
    }

    public var modDestination: ModDestination? {
        switch self {
        case .pitch1: return .pitch1
        case .pitch2: return .pitch2
        case .cutoff: return .cutoff
        case .resonance: return .resonance
        case .amp: return .amp
        case .pan: return .pan
        case .pwm1: return .pwm1
        case .pwm2: return .pwm2
        case .wtMorph1: return .wtMorph1
        case .wtMorph2: return .wtMorph2
        case .lfoRate: return .lfoRate
        case .lfoDepth: return .lfoDepth
        case .mix: return .mix
        case .finePitch: return .finePitch
        default: return nil
        }
    }

    /// Fast lock-free audio thread index.
    public var rtIndex: Int16 {
        guard let idx = MIDIControlTarget.allCases.firstIndex(of: self) else { return -1 }
        return Int16(idx)
    }

    /// Built once (first touched on main by AudioEngine.init), so the audio
    /// thread only indexes an existing array: no allocation per CC.
    private static let rtTable: ContiguousArray<MIDIControlTarget> = ContiguousArray(allCases)

    public static func from(rtIndex: Int16) -> MIDIControlTarget? {
        let i = Int(rtIndex)
        guard i >= 0 && i < rtTable.count else { return nil }
        return rtTable[i]
    }
}

public enum SamsonGraphite49CC {
    // 8 Encoders (E1-E8)
    public static let encoderCutoff: UInt8 = 74
    public static let encoderResonance: UInt8 = 71
    public static let encoderFilterEnvAmount: UInt8 = 73
    public static let encoderMorph1: UInt8 = 75
    public static let encoderFMAmount: UInt8 = 72
    public static let encoderReverbMix: UInt8 = 91
    public static let encoderChorusMix: UInt8 = 93
    public static let encoderDelayMix: UInt8 = 94

    // 8 Faders (F1-F8)
    public static let faderAttack: UInt8 = 20
    public static let faderDecay: UInt8 = 21
    public static let faderSustain: UInt8 = 22
    public static let faderRelease: UInt8 = 23
    public static let faderMacro1: UInt8 = 24
    public static let faderMacro2: UInt8 = 25
    public static let faderMacro3: UInt8 = 26
    public static let faderMacro4: UInt8 = 27

    // Master Fader (F9)
    public static let masterVolume: UInt8 = 7
}

public final class MIDICCLearnStore: ObservableObject {
    public static let shared = MIDICCLearnStore()

    private let storageKey = "midiCCMappings"

    @Published public var mappings: [UInt8: MIDIControlTarget] = [:]
    @Published public var learningTarget: MIDIControlTarget? = nil

    weak var engine: AudioEngine?

    /// Backward compatibility for existing UI and tests expecting ModDestination.
    public var learningDestination: ModDestination? {
        get { learningTarget?.modDestination }
        set { learningTarget = newValue.map { MIDIControlTarget($0) } }
    }

    public init() {
        loadMappings()
    }

    public func attachEngine(_ engine: AudioEngine) {
        self.engine = engine
        syncToAudioEngine()
    }

    public func syncToAudioEngine() {
        engine?.updateRTMappings(mappings)
    }

    public func startLearning(for target: MIDIControlTarget) {
        learningTarget = target
    }

    public func startLearning(destination: ModDestination) {
        startLearning(for: MIDIControlTarget(destination))
    }

    public func cancelLearning() {
        learningTarget = nil
    }

    public func cc(for target: MIDIControlTarget) -> UInt8? {
        mappings.first(where: { $0.value == target })?.key
    }

    public func cc(destination: ModDestination) -> UInt8? {
        cc(for: MIDIControlTarget(destination))
    }

    public func unmap(target: MIDIControlTarget) {
        if let cc = cc(for: target) {
            mappings.removeValue(forKey: cc)
            saveMappings()
            syncToAudioEngine()
        }
    }

    public func unmap(destination: ModDestination) {
        unmap(target: MIDIControlTarget(destination))
    }

    public func map(cc: UInt8, to target: MIDIControlTarget) {
        mappings[cc] = target
        saveMappings()
        syncToAudioEngine()
    }

    public func map(cc: UInt8, destination: ModDestination) {
        map(cc: cc, to: MIDIControlTarget(destination))
    }

    public func clearMappings() {
        mappings.removeAll()
        learningTarget = nil
        saveMappings()
        syncToAudioEngine()
    }

    public func applySamsonGraphite49Template() {
        mappings.removeAll()
        learningTarget = nil

        // Encoders E1-E8
        mappings[SamsonGraphite49CC.encoderCutoff] = .cutoff
        mappings[SamsonGraphite49CC.encoderResonance] = .resonance
        mappings[SamsonGraphite49CC.encoderFilterEnvAmount] = .filterEnvelopeAmount
        mappings[SamsonGraphite49CC.encoderMorph1] = .wtMorph1
        mappings[SamsonGraphite49CC.encoderFMAmount] = .fmAmount
        mappings[SamsonGraphite49CC.encoderReverbMix] = .reverbMix
        mappings[SamsonGraphite49CC.encoderChorusMix] = .chorusMix
        mappings[SamsonGraphite49CC.encoderDelayMix] = .delayMix

        // Faders F1-F8
        mappings[SamsonGraphite49CC.faderAttack] = .attack
        mappings[SamsonGraphite49CC.faderDecay] = .decay
        mappings[SamsonGraphite49CC.faderSustain] = .sustain
        mappings[SamsonGraphite49CC.faderRelease] = .release
        mappings[SamsonGraphite49CC.faderMacro1] = .macro1
        mappings[SamsonGraphite49CC.faderMacro2] = .macro2
        mappings[SamsonGraphite49CC.faderMacro3] = .macro3
        mappings[SamsonGraphite49CC.faderMacro4] = .macro4

        // Master Fader (F9)
        mappings[SamsonGraphite49CC.masterVolume] = .amp

        saveMappings()
        syncToAudioEngine()
    }

    /// Called when an incoming CC arrives. Returns true if handled (learning or mapped).
    @discardableResult
    public func handleIncomingCC(_ cc: UInt8, value: UInt8, currentPreset: inout SynthPreset) -> Bool {
        if let target = learningTarget {
            mappings[cc] = target
            learningTarget = nil
            saveMappings()
            syncToAudioEngine()
            applyValue(value, to: target, preset: &currentPreset)
            return true
        }

        if let target = mappings[cc] {
            applyValue(value, to: target, preset: &currentPreset)
            return true
        }

        return false
    }

    public func applyValue(_ rawValue: UInt8, to destination: ModDestination, preset: inout SynthPreset) {
        applyValue(rawValue, to: MIDIControlTarget(destination), preset: &preset)
    }

    public func applyValue(_ rawValue: UInt8, to target: MIDIControlTarget, preset: inout SynthPreset) {
        let norm = Float(rawValue) / 127.0
        switch target {
        case .cutoff:
            preset.filterCutoff = 20.0 * pow(1000.0, norm)
        case .resonance:
            preset.filterResonance = norm * 0.95
        case .amp:
            preset.masterVolume = norm
        case .pan:
            break // pan is a live performance offset (render-side ccPanRT); no preset field
        case .pitch1:
            preset.osc1Detune = (norm - 0.5) * 100.0
        case .pitch2:
            preset.osc2Detune = (norm - 0.5) * 100.0
        case .finePitch:
            preset.osc1Detune = (norm - 0.5) * 100.0
            preset.osc2Detune = (norm - 0.5) * 100.0
        case .pwm1:
            preset.osc1PulseWidth = 0.1 + norm * 0.8
        case .pwm2:
            preset.osc2PulseWidth = 0.1 + norm * 0.8
        case .wtMorph1:
            preset.osc1WavetableMorph = norm
        case .wtMorph2:
            preset.osc2WavetableMorph = norm
        case .lfoRate:
            preset.lfoRate = 0.05 + norm * 19.95
        case .lfoDepth:
            preset.lfoDepth = norm
        case .mix:
            preset.osc2Volume = norm
        case .attack:
            preset.attack = 0.001 + norm * 1.999
        case .decay:
            preset.decay = 0.001 + norm * 1.999
        case .sustain:
            preset.sustain = norm
        case .release:
            preset.release = 0.001 + norm * 2.999
        case .filterAttack:
            preset.filterAttack = 0.001 + norm * 1.999
        case .filterDecay:
            preset.filterDecay = 0.001 + norm * 1.999
        case .filterSustain:
            preset.filterSustain = norm
        case .filterRelease:
            preset.filterRelease = 0.001 + norm * 2.999
        case .filterEnvelopeAmount:
            preset.filterEnvelopeAmount = (norm - 0.5) * 2.0
        case .reverbMix:
            preset.reverbMix = norm
        case .reverbRoomSize:
            preset.reverbRoomSize = norm
        case .reverbShimmer:
            preset.reverbShimmer = norm
        case .delayMix:
            preset.delayMix = norm
        case .delayTime:
            preset.delayTime = 0.01 + norm * 0.99
        case .delayFeedback:
            preset.delayFeedback = norm * 0.9
        case .chorusMix:
            preset.chorusMix = norm
        case .chorusRate:
            preset.chorusRate = 0.1 + norm * 4.9
        case .chorusDepth:
            preset.chorusDepth = norm
        case .distortionMix:
            preset.distortionMix = norm
        case .distortionDrive:
            preset.distortionDrive = norm
        case .phaserMix:
            preset.phaserMix = norm
        case .phaserRate:
            preset.phaserRate = 0.05 + norm * 4.95
        case .phaserDepth:
            preset.phaserDepth = norm
        case .osc1Volume:
            preset.osc1Volume = norm
        case .osc2Volume:
            preset.osc2Volume = norm
        case .subOscVolume:
            preset.subOscVolume = norm
        case .fmAmount:
            preset.fmAmount = norm
        case .ringModAmount:
            preset.ringModAmount = norm
        case .unisonDetune:
            preset.unisonDetune = norm * 50.0
        case .unisonSpread:
            preset.unisonSpread = norm
        case .analogDrift:
            preset.analogDrift = norm
        case .portamento:
            preset.portamento = norm
        case .macro1:
            preset.macro1 = (norm - 0.5) * 2.0
        case .macro2:
            preset.macro2 = (norm - 0.5) * 2.0
        case .macro3:
            preset.macro3 = (norm - 0.5) * 2.0
        case .macro4:
            preset.macro4 = (norm - 0.5) * 2.0
        }
    }

    private func loadMappings() {
        guard let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] else {
            return
        }
        var loaded: [UInt8: MIDIControlTarget] = [:]
        for (k, v) in dict {
            if let cc = UInt8(k) {
                if let target = MIDIControlTarget(rawValue: v) {
                    loaded[cc] = target
                } else if let dest = ModDestination(rawValue: v) {
                    loaded[cc] = MIDIControlTarget(dest)
                }
            }
        }
        mappings = loaded
    }

    private func saveMappings() {
        var dict: [String: String] = [:]
        for (k, v) in mappings {
            dict[String(k)] = v.rawValue
        }
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}
