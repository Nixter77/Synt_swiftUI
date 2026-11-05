//
//  PerformanceSettingsToggles.swift
//  Synt_swiftUI
//
//  Touch and the global CC7/CC11 switch. Drop the Group into a settings menu.
//  The caller saves UserDefaults. The engine didSet does not.
//

import SwiftUI
import SynthCore

struct PerformanceSettingsToggles: View {
    @Binding var touch: KeyboardTouch
    @Binding var respondToExpression: Bool
    var onChange: () -> Void

    var body: some View {
        Group {
            Picker("Touch", selection: Binding(
                get: { touch },
                set: { newValue in
                    touch = newValue
                    onChange()
                }
            )) {
                ForEach(KeyboardTouch.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .accessibilityIdentifier("performanceTouch")

            Toggle("Respond to CC7/CC11", isOn: Binding(
                get: { respondToExpression },
                set: { newValue in
                    respondToExpression = newValue
                    onChange()
                }
            ))
            .accessibilityIdentifier("performanceExpression")
        }
    }
}
