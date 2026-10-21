//
//  AUParameterRangeTests.swift
//  What auval checks: every published parameter's default lies in [min, max],
//  and a value set at min / max reads back. Addresses >= 128 used to fall
//  outside AddressedParameterStore and read 0.
//

import AudioToolbox
import Foundation
import Testing
@testable import SynthCore

@MainActor
struct AUParameterRangeTests {
    private func makeUnit() throws -> SyntAudioUnit {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)
        return try SyntAudioUnit(componentDescription: description)
    }

    @Test(arguments: [false, true])
    func everyParameterDefaultIsInRangeAndMinMaxAreRetained(allocated: Bool) throws {
        let unit = try makeUnit()
        if allocated { try unit.allocateRenderResources() }
        let tree = try #require(unit.parameterTree)
        #expect(tree.allParameters.count > 0)
        for p in tree.allParameters {
            #expect(p.value >= p.minValue && p.value <= p.maxValue,
                    "\(p.identifier) (\(p.address)) default \(p.value) outside [\(p.minValue), \(p.maxValue)]")
            p.value = p.minValue
            #expect(p.value == p.minValue, "\(p.identifier) (\(p.address)) min not retained: \(p.value)")
            p.value = p.maxValue
            #expect(p.value == p.maxValue, "\(p.identifier) (\(p.address)) max not retained: \(p.value)")
        }
        if allocated { unit.deallocateRenderResources() }
    }

    @Test func hostValueSetBeforeAllocateSurvivesAllocate() throws {
        let unit = try makeUnit()
        let tree = try #require(unit.parameterTree)
        let attack = try #require(tree.parameter(withAddress: SynthParameterAddress.modEnvAttack.rawValue))
        attack.value = attack.maxValue
        try unit.allocateRenderResources()
        #expect(attack.value == attack.maxValue)
        unit.deallocateRenderResources()
    }

    @Test func storeCoversEveryAddress() {
        let store = AddressedParameterStore()
        for a in SynthParameterAddress.allCases {
            store.set(a.rawValue, 0.5)
            #expect(store.value(a.rawValue) == 0.5, "address \(a.rawValue)")
        }
        var drained = Set<UInt64>()
        store.drain { id, _ in drained.insert(id) }
        #expect(drained == Set(SynthParameterAddress.allCases.map(\.rawValue)))
    }
}
