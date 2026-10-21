//
//  Stage7ModTests.swift
//  Fine pitch, FM ratio, FX mix destinations, and the macro XY pad.
//  Each new path stays off until a preset or a matrix row turns it on.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage7ModTests {

    private func render(_ mutate: (inout SynthPreset) -> Void, samples: Int = 800) -> [Float] {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        mutate(&preset)
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        var out: [Float] = []
        out.reserveCapacity(samples)
        for _ in 0..<samples {
            out.append(engine.renderOneSample().0)
        }
        return out
    }

    private func gap(_ a: [Float], _ b: [Float], from: Int = 200) -> Float {
        var peak: Float = 0
        let end = min(a.count, b.count)
        for i in from..<end {
            peak = max(peak, abs(a[i] - b[i]))
        }
        return peak
    }

    @Test func missingKeysLeaveTheRatioOffAndTheRenderUnchanged() throws {
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old"}"#.utf8))
        #expect(decoded.fmRatioEnabled == false)
        #expect(decoded.fmCoarse == 1)
        #expect(decoded.fmFine == 0)
        #expect(decoded.fmRoute == .osc2ToOsc1)
        #expect(ModDestination.allCases.count > 13)
        #expect(ModDestination.allCases.contains(.pan))
        #expect(ModDestination.allCases.contains(.finePitch))
        #expect(ModDestination.allCases.contains(.fm))
        #expect(ModDestination.allCases.contains(.chorusMix))
        #expect(ModDestination.allCases.contains(.delayMix))
        #expect(ModDestination.allCases.contains(.reverbMix))

        let plain = render { patch in
            patch.fmAmount = 0.4
            patch.fmCoarse = 5
            patch.fmRoute = .osc1ToOsc2
        }
        let explicit = render { patch in
            patch.fmAmount = 0.4
            patch.fmRatioEnabled = false
            patch.fmCoarse = 5
            patch.fmRoute = .osc1ToOsc2
        }
        #expect(plain == explicit)
    }

    @Test func ratioAndRouteChangeTheNoteOnlyWhenEnabled() {
        let off = render { patch in
            patch.fmAmount = 0.7
            patch.fmCoarse = 4
        }
        let on = render { patch in
            patch.fmAmount = 0.7
            patch.fmRatioEnabled = true
            patch.fmCoarse = 4
            patch.fmRoute = .osc2ToOsc1
        }
        #expect(gap(off, on) > 0.01)

        let other = render { patch in
            patch.fmAmount = 0.7
            patch.fmRatioEnabled = true
            patch.fmCoarse = 4
            patch.fmRoute = .osc1ToOsc2
        }
        #expect(gap(on, other) > 0.01)
    }

    @Test func finePitchAmountZeroMatchesTheUnroutedNote() {
        let plain = render { _ in }
        let zero = render { patch in
            patch.modMatrix = [ModMatrixEntry(source: .velocity, destination: .finePitch, amount: 0)]
        }
        #expect(plain == zero)
        let bent = render { patch in
            patch.modMatrix = [ModMatrixEntry(source: .velocity, destination: .finePitch, amount: 0.9)]
        }
        #expect(gap(plain, bent) > 0.01)
    }

    @Test func chorusMixRouteOpensASilentChorus() {
        let dry = render { patch in
            patch.chorusMix = 0
            patch.chorusDepth = 0.8
        }
        let wet = render { patch in
            patch.chorusMix = 0
            patch.chorusDepth = 0.8
            patch.modMatrix = [ModMatrixEntry(source: .velocity, destination: .chorusMix, amount: 0.85)]
        }
        #expect(dry == render { patch in
            patch.chorusMix = 0
            patch.chorusDepth = 0.8
            patch.modMatrix = [ModMatrixEntry(source: .velocity, destination: .chorusMix, amount: 0)]
        })
        #expect(gap(dry, wet) > 0.01)
    }

    @Test func macroPadMapsXToMacro1AndYUpToMacro2() {
        let mid = macroXYValues(x: 50, y: 25, width: 100, height: 50)
        #expect(abs(mid.macro1) < 0.001)
        #expect(abs(mid.macro2) < 0.001)

        let topLeft = macroXYValues(x: 0, y: 0, width: 100, height: 50)
        #expect(abs(topLeft.macro1 - (-1)) < 0.001)
        #expect(abs(topLeft.macro2 - 1) < 0.001)

        let bottomRight = macroXYValues(x: 100, y: 50, width: 100, height: 50)
        #expect(abs(bottomRight.macro1 - 1) < 0.001)
        #expect(abs(bottomRight.macro2 - (-1)) < 0.001)

        let outside = macroXYValues(x: -10, y: 80, width: 100, height: 50)
        #expect(outside.macro1 == -1)
        #expect(outside.macro2 == -1)
    }
}
