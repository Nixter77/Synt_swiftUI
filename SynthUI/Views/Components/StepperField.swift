//
//  StepperField.swift
//  Synt_swiftUI
//
//  Compact "− [ n ] +" used for unison voices. The number keeps a fixed
//  width so a tight column cannot squash it.
//

import AppKit
import SynthCore
import SwiftUI

struct StepperValueWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum StepperMath {
    static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    static func stepped(_ value: Int, by delta: Int, in range: ClosedRange<Int>) -> Int {
        let added = value.addingReportingOverflow(delta)
        let raw = added.overflow ? (delta >= 0 ? range.upperBound : range.lowerBound) : added.partialValue
        return clamped(raw, to: range)
    }

    /// Whole number from a typed field. Shares `KnobValueParser`. Garbage is nil.
    static func parse(_ text: String) -> Int? {
        guard let value = KnobValueParser.parse(text, format: "%.0f", range: -1_000_000...1_000_000) else {
            return nil
        }
        return Int(value.rounded())
    }
}

struct StepperField: View {
    @Environment(\.theme) private var theme
    @Binding var value: Int
    var range: ClosedRange<Int>

    @State private var editing = false
    @State private var draft = ""
    @State private var rejectEdit = false
    @State private var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", delta: -1)
            number
            stepButton(systemName: "plus", delta: 1)
        }
        .background(invalid ? theme.destructive.opacity(0.35) : theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .fixedSize()
        .focusable(!editing)
        .onKeyPress(.upArrow) {
            guard !editing else { return .ignored }
            step(1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !editing else { return .ignored }
            step(-1)
            return .handled
        }
        .modifier(WheelStep(enabled: !editing, onStep: step))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voices")
    }

    private var number: some View {
        Group {
            if editing {
                TextField("", text: $draft)
                    .font(theme.valueFont(size: 13))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundColor(theme.text)
                    .frame(minWidth: 28, minHeight: 22)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onExitCommand { reject() }
                    .onAppear { beginTyping() }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { finishTyping() }
                    }
            } else {
                Text("\(value)")
                    .font(theme.valueFont(size: 13))
                    .foregroundColor(theme.text)
                    .frame(minWidth: 28, minHeight: 22)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditing() }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: StepperValueWidthKey.self, value: geo.size.width)
                        }
                    )
                    .accessibilityIdentifier("unison.voices")
                    .accessibilityValue("\(value)")
            }
        }
    }

    private func stepButton(systemName: String, delta: Int) -> some View {
        let next = StepperMath.stepped(value, by: delta, in: range)
        return Button {
            editing = false
            value = next
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(next == value ? theme.textFaint : theme.text)
                .frame(width: 16, height: 22)
        }
        .buttonStyle(.plain)
        .disabled(next == value)
        .accessibilityLabel(delta > 0 ? "Increase voices" : "Decrease voices")
    }

    private func step(_ delta: Int) {
        value = StepperMath.stepped(value, by: delta, in: range)
    }

    private func startEditing() {
        draft = "\(value)"
        rejectEdit = false
        invalid = false
        editing = true
    }

    private func beginTyping() {
        focused = true
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSText)?.selectAll(nil)
        }
    }

    private func reject() {
        rejectEdit = true
        editing = false
        focused = false
    }

    private func finishTyping() {
        if rejectEdit {
            rejectEdit = false
            editing = false
            return
        }
        guard editing else { return }
        commit()
    }

    private func commit() {
        if let parsed = StepperMath.parse(draft) {
            value = StepperMath.clamped(parsed, to: range)
            invalid = false
        } else {
            invalid = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                invalid = false
            }
        }
        editing = false
        focused = false
    }
}

/// Scroll-wheel steps while the pointer is over the control. The monitor is
/// removed when the view goes away, including if `onDisappear` does not run.
private struct WheelStep: ViewModifier {
    var enabled: Bool
    var onStep: (Int) -> Void

    @State private var hold = WheelHold()

    func body(content: Content) -> some View {
        hold.enabled = enabled
        hold.onStep = onStep
        return content
            .onHover { hold.hover = $0 }
            .onAppear { hold.install() }
            .onDisappear { hold.remove() }
    }
}

private final class WheelHold {
    var token: Any?
    var accum: CGFloat = 0
    var hover = false
    var enabled = true
    var onStep: ((Int) -> Void)?

    func install() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.enabled, self.hover else { return event }
            self.accum += event.scrollingDeltaY
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 10 : 0.1
            guard abs(self.accum) >= threshold else { return nil }
            let dir = self.accum > 0 ? 1 : -1
            self.accum = 0
            self.onStep?(dir)
            return nil
        }
    }

    func remove() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
        accum = 0
    }

    deinit { remove() }
}
