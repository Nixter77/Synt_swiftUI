//
//  PluginLayoutTests.swift
//  Panel rectangles stay disjoint at every zoom and both view layouts.
//

import CoreAudioKit
import SwiftUI
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
struct PluginLayoutTests {

    @Test func tiledFramesDoNotIntersectAtEachZoomAndLayout() {
        for layout in PluginLayout.allCases {
            for zoom in PluginZoom.allCases {
                let size = AUPluginMetrics.preferredSize(layout: layout, zoom: zoom)
                let frames = AUPluginMetrics.frames(width: size.width, height: size.height, layout: layout)
                #expect(frames.count == AUPluginMetrics.panelIDs.count)
                #expect(Set(frames.map(\.id)) == Set(AUPluginMetrics.panelIDs))
                assertNoInteriorOverlap(frames.map(\.rect), label: "\(layout.rawValue) \(zoom.rawValue)%")
                for frame in frames {
                    #expect(frame.rect.width > 1, "\(frame.id) width")
                    #expect(frame.rect.height > 1, "\(frame.id) height")
                    #expect(frame.rect.maxX <= size.width + 0.5)
                    #expect(frame.rect.maxY <= size.height + 0.5)
                }
            }
        }
    }

    @Test func hostedPanelsDoNotIntersectAtEachZoomAndLayout() {
        let engine = AudioEngine()
        for layout in PluginLayout.allCases {
            for zoom in PluginZoom.allCases {
                let size = AUPluginMetrics.preferredSize(layout: layout, zoom: zoom)
                let recorder = PanelFrameRecorder()
                let host = NSHostingView(
                    rootView: SynthControlGrid(audioEngine: engine, layout: layout, recorder: recorder)
                        .environment(\.theme, Theme.baseline)
                        .frame(width: size.width, height: size.height, alignment: .top)
                )
                host.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                host.layoutSubtreeIfNeeded()
                let frames = AUPluginMetrics.panelIDs.compactMap { recorder.frames[$0] }
                #expect(frames.count == AUPluginMetrics.panelIDs.count, "\(layout.rawValue) \(zoom.rawValue)% placed \(frames.count)")
                assertNoInteriorOverlap(frames, label: "hosted \(layout.rawValue) \(zoom.rawValue)%")
            }
        }
    }

    @Test func compactPreferredHeightStaysWithinTheCap() {
        let size = AUPluginMetrics.preferredSize(layout: .compact, zoom: .p100)
        #expect(size.height <= 520)
        #expect(size.width == AUPluginMetrics.contentWidth)
        let extended = AUPluginMetrics.preferredSize(layout: .extended, zoom: .p100)
        #expect(extended.height > 520)
    }

    @Test func chromeZoomRoundTripsThroughFullState() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        unit.uiZoom = .p150
        unit.uiLayout = .extended
        let saved = try #require(unit.fullState)
        let data = try #require(saved["syntUIChrome"] as? Data)
        let chrome = try JSONDecoder().decode(PluginChromeState.self, from: data)
        #expect(chrome.zoom == 150)
        #expect(chrome.layout == PluginLayout.extended.rawValue)

        unit.uiZoom = .p75
        unit.uiLayout = .compact
        unit.fullState = saved
        #expect(unit.uiZoom == .p150)
        #expect(unit.uiLayout == .extended)

        var stripped = saved
        stripped.removeValue(forKey: "syntUIChrome")
        unit.fullState = stripped
        #expect(unit.uiZoom == .p100)
        #expect(unit.uiLayout == .compact)

        let missing = try JSONDecoder().decode(PluginChromeState.self, from: Data("{}".utf8))
        #expect(missing.zoom == 100)
        #expect(missing.layout == PluginLayout.compact.rawValue)
    }

    @Test func viewConfigurationsSelectCompactOrExtended() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        let compact = AUAudioUnitViewConfiguration(width: 1100, height: 520, hostHasController: false)
        let extended = AUAudioUnitViewConfiguration(width: 1440, height: 760, hostHasController: false)
        let offered = [compact, extended]
        let supported = unit.supportedViewConfigurations(offered)
        #expect(supported.contains(0))
        #expect(supported.contains(1))
        unit.select(compact)
        #expect(unit.uiLayout == .compact)
        unit.select(extended)
        #expect(unit.uiLayout == .extended)
    }

    private func assertNoInteriorOverlap(_ rects: [CGRect], label: String) {
        for left in rects.indices {
            for right in rects.indices where right > left {
                let hit = rects[left].intersection(rects[right])
                #expect(hit.width <= 0.5 || hit.height <= 0.5, "\(label) overlap \(hit)")
            }
        }
    }
}
