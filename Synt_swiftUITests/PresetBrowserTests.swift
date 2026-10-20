//
//  PresetBrowserTests.swift
//  Up / down preset arrows, the "NNN / total" counter, Program Change mapping.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct PresetBrowserTests {
    private var list: [SynthPreset] { PresetBrowser.list }

    @Test func listIsTheWholeFactoryLibraryGroupedByCategory() {
        #expect(list.count == SynthPreset.factoryPresets.count)
        #expect(Set(list.map(\.name)) == Set(SynthPreset.factoryPresets.map(\.name)))
        let order = list.map { PresetCategory.allCases.firstIndex(of: $0.category)! }
        #expect(order == order.sorted(), "browse order must follow the popover's category order")
    }

    @Test func nextAndPreviousStepByOne() {
        #expect(PresetBrowser.step(from: list[0], by: 1).name == list[1].name)
        #expect(PresetBrowser.step(from: list[5], by: -1).name == list[4].name)
    }

    @Test func arrowsWrapAtBothEnds() {
        #expect(PresetBrowser.step(from: list[list.count - 1], by: 1).name == list[0].name)
        #expect(PresetBrowser.step(from: list[0], by: -1).name == list[list.count - 1].name)
    }

    @Test func fullLapReturnsToStart() {
        var p = list[3]
        for _ in 0..<list.count { p = PresetBrowser.step(from: p, by: 1) }
        #expect(p.name == list[3].name)
    }

    @Test func initAndUserPresetsEnterAtTheEnds() {
        #expect(PresetBrowser.step(from: .defaultPreset, by: 1).name == list[0].name)
        #expect(PresetBrowser.step(from: .defaultPreset, by: -1).name == list[list.count - 1].name)
        let user = SynthPreset(name: "My Preset 7", category: .pad)
        #expect(PresetBrowser.index(of: user) == nil)
    }

    @Test func editedFactoryPresetKeepsItsNumber() {
        var edited = list[10]
        edited.filterCutoff = 1234
        #expect(PresetBrowser.index(of: edited) == 10)
        #expect(PresetBrowser.step(from: edited, by: 1).name == list[11].name)
    }

    @Test func counterIsZeroPadded() {
        let total = String(format: "%03d", list.count)
        #expect(PresetBrowser.counterLabel(for: list[0]) == "001 / \(total)")
        #expect(PresetBrowser.counterLabel(for: list[41]) == "042 / \(total)")
        #expect(PresetBrowser.counterLabel(for: .defaultPreset) == "— / \(total)")
    }

    @Test func programChangeMapsZeroBased() {
        #expect(PresetBrowser.preset(forProgram: 0)?.name == list[0].name)
        #expect(PresetBrowser.preset(forProgram: list.count - 1)?.name == list.last?.name)
        #expect(PresetBrowser.preset(forProgram: list.count) == nil)
        #expect(PresetBrowser.preset(forProgram: -1) == nil)
    }
}
