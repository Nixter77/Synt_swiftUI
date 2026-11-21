//
//  KnobView.swift
//  Synt_swiftUI
//

import AppKit
import SynthCore
import SwiftUI

private struct LiveModulationKey: EnvironmentKey {
    static let defaultValue: LiveModulationSnapshot? = nil
}

extension EnvironmentValues {
    var liveModulation: LiveModulationSnapshot? {
        get { self[LiveModulationKey.self] }
        set { self[LiveModulationKey.self] = newValue }
    }
}

/// 150 pt of vertical drag sweeps the full range, linearly from the grab point.
/// Passing `fine: true` (Shift held) slows travel by 5x for fine adjustments.
func knobDragValue(start: Float, translationY: CGFloat, range: ClosedRange<Float>, fine: Bool = false) -> Float {
    let sensitivity: Float = fine ? 750.0 : 150.0
    let delta = Float(-translationY) / sensitivity
    let span = range.upperBound - range.lowerBound
    return min(max(start + delta * span, range.lowerBound), range.upperBound)
}

/// Target value when resetting a knob: explicit `defaultValue`, or `0` for bipolar ranges.
func knobResetValue(defaultValue: Float?, range: ClosedRange<Float>) -> Float? {
    if let defaultValue {
        return min(max(defaultValue, range.lowerBound), range.upperBound)
    }
    if range.lowerBound < 0 && range.upperBound > 0 {
        return 0
    }
    return nil
}

private func resolveKnobModDestination(target: MIDIControlTarget?, label: String) -> ModDestination? {
    if let target {
        if let d = ModDestination(rawValue: target.rawValue) { return d }
        if let d = target.modDestination { return d }
    }
    switch label.lowercased() {
    case "cutoff": return .cutoff
    case "reso", "resonance": return .resonance
    case "morph", "morph 1": return .wtMorph1
    case "morph 2": return .wtMorph2
    case "pw", "pw 1": return .pwm1
    case "pw 2": return .pwm2
    case "detune", "detune 1": return .pitch1
    case "detune 2": return .pitch2
    case "mix": return .mix
    case "rate": return .lfoRate
    case "depth": return .lfoDepth
    case "vowel": return .vowel
    case "chorus": return .chorusMix
    case "delay", "time": return .delayMix
    case "reverb": return .reverbMix
    case "fine": return .finePitch
    case "fm": return .fm
    case "amp": return .amp
    case "pan": return .pan
    default: return nil
    }
}

private struct KnobInteractiveModifier: ViewModifier {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float?

    /// Value at drag start. Translation is cumulative, so it adds to this, not to `value`.
    @State private var dragStart: Float?
    @State private var dragAnchorTranslationY: CGFloat = 0
    @State private var dragFine = false
    @State private var didResetOnOptionClick = false

    func body(content: Content) -> some View {
        content
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if dragStart == nil && !didResetOnOptionClick {
                            if NSEvent.modifierFlags.contains(.option) {
                                didResetOnOptionClick = true
                                resetToDefault()
                                return
                            }
                            dragStart = value
                            dragAnchorTranslationY = 0
                            dragFine = NSEvent.modifierFlags.contains(.shift)
                            PatchHistoryManager.shared.onDragStart()
                        }
                        guard !didResetOnOptionClick else { return }
                        let fine = NSEvent.modifierFlags.contains(.shift)
                        if fine != dragFine {
                            dragStart = value
                            dragAnchorTranslationY = gesture.translation.height
                            dragFine = fine
                        }
                        let start = dragStart ?? value
                        value = knobDragValue(
                            start: start,
                            translationY: gesture.translation.height - dragAnchorTranslationY,
                            range: range,
                            fine: fine
                        )
                    }
                    .onEnded { _ in
                        if didResetOnOptionClick {
                            didResetOnOptionClick = false
                            return
                        }
                        dragStart = nil
                        dragAnchorTranslationY = 0
                        dragFine = false
                        PatchHistoryManager.shared.onDragEnd()
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        resetToDefault()
                    }
            )
    }

    private func resetToDefault() {
        guard let targetValue = knobResetValue(defaultValue: defaultValue, range: range),
              value != targetValue else {
            return
        }
        PatchHistoryManager.shared.onDragStart()
        value = targetValue
        PatchHistoryManager.shared.onDragEnd()
    }
}

private struct KnobContextMenuModifier: ViewModifier {
    let target: MIDIControlTarget?

    func body(content: Content) -> some View {
        content.contextMenu {
            if let tgt = target {
                Button(MIDICCLearnStore.shared.learningTarget == tgt ? "Waiting for MIDI CC..." : "Learn MIDI CC (\(tgt.rawValue))") {
                    MIDICCLearnStore.shared.startLearning(for: tgt)
                }
                if let mappedCC = MIDICCLearnStore.shared.cc(for: tgt) {
                    Button("Unmap MIDI CC (\(mappedCC))") {
                        MIDICCLearnStore.shared.unmap(target: tgt)
                    }
                }
            }
        }
    }
}

struct KnobView: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"
    /// Replaces the formatted number when a destination has its own units.
    var valueText: String? = nil
    /// Matrix sources aimed at this parameter. A dot is drawn when the list is not empty.
    var modulated: [ModSource] = []
    var modulationAmount: Float = 0.0
    var destination: ModDestination? = nil
    var target: MIDIControlTarget? = nil
    var defaultValue: Float? = nil

    var resolvedTarget: MIDIControlTarget? {
        if let target { return target }
        if let destination { return MIDIControlTarget(destination) }
        switch label.lowercased() {
        case "cutoff": return .cutoff
        case "reso", "resonance": return .resonance
        case "morph", "morph 1": return .wtMorph1
        case "morph 2": return .wtMorph2
        case "pw", "pw 1": return .pwm1
        case "pw 2": return .pwm2
        case "detune", "detune 1": return .pitch1
        case "detune 2": return .pitch2
        case "mix": return .mix
        case "rate": return .lfoRate
        case "depth": return .lfoDepth
        case "attack": return .attack
        case "decay": return .decay
        case "sustain": return .sustain
        case "release": return .release
        case "env": return .filterEnvelopeAmount
        case "room": return .reverbRoomSize
        case "shimmer": return .reverbShimmer
        case "time": return .delayTime
        case "feedback", "fdbk": return .delayFeedback
        case "drive": return .distortionDrive
        case "bright": return .macro1
        case "timbre": return .macro2
        case "motion": return .macro3
        case "space": return .macro4
        case "glide": return .portamento
        case "drift": return .analogDrift
        case "sub": return .subOscVolume
        case "fm": return .fmAmount
        default: return nil
        }
    }

    var body: some View {
        KnobBody(
            value: $value,
            range: range,
            label: label,
            format: format,
            valueText: valueText,
            modulated: modulated,
            modulationAmount: modulationAmount,
            target: resolvedTarget,
            defaultValue: defaultValue,
            themeID: theme.id
        )
        .equatable()
    }
}

private struct KnobBody: View, Equatable {
    @Environment(\.theme) private var theme
    @Environment(\.liveModulation) private var liveModulationSnapshot
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    var valueText: String? = nil
    var modulated: [ModSource] = []
    var modulationAmount: Float = 0.0
    let target: MIDIControlTarget?
    let defaultValue: Float?
    let themeID: ThemeID

    private let knobSize: CGFloat = 50

    static func == (lhs: KnobBody, rhs: KnobBody) -> Bool {
        lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.label == rhs.label
            && lhs.format == rhs.format
            && lhs.valueText == rhs.valueText
            && lhs.modulated == rhs.modulated
            && lhs.modulationAmount == rhs.modulationAmount
            && lhs.target == rhs.target
            && lhs.defaultValue == rhs.defaultValue
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                KnobDiscShadow(diameter: knobSize + 4, themeID: theme.id)
                .equatable()

                if modulationAmount != 0, let dest = resolvedDestination {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { _ in
                        KnobChrome(
                            fraction: fraction,
                            angle: rotationAngle,
                            diameter: knobSize,
                            centeredFill: range.lowerBound < 0 && range.upperBound > 0,
                            modulationAmount: modulationAmount,
                            liveModulation: liveModulationSnapshot?.value(for: dest) ?? 0
                        )
                    }
                } else {
                    KnobChrome(
                        fraction: fraction,
                        angle: rotationAngle,
                        diameter: knobSize,
                        centeredFill: range.lowerBound < 0 && range.upperBound > 0,
                        modulationAmount: modulationAmount
                    )
                }
                if !modulated.isEmpty {
                    Circle()
                        .fill(theme.aMod)
                        .frame(width: 5, height: 5)
                        .offset(y: knobSize * 0.38)
                        .help(modulated.map(\.rawValue).joined(separator: ", "))
                }
            }
            .modifier(KnobInteractiveModifier(value: $value, range: range, defaultValue: defaultValue))

            Text(label)
                .themeCaption(theme, size: 10)
                .foregroundColor(theme.textDim)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            KnobValueField(
                value: $value,
                range: range,
                format: format,
                valueText: valueText,
                fontSize: 9,
                color: theme.textFaint
            )
        }
        .modifier(KnobContextMenuModifier(target: target))
    }

    private var fraction: CGFloat { knobArcFraction(value: value, range: range) }

    private var rotationAngle: Double {
        -135 + Double(fraction) * 270
    }

    private var resolvedDestination: ModDestination? {
        resolveKnobModDestination(target: target, label: label)
    }
}

struct LargeKnobView: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"
    var modulated: [ModSource] = []
    var modulationAmount: Float = 0.0
    var destination: ModDestination? = nil
    var target: MIDIControlTarget? = nil
    var defaultValue: Float? = nil

    var resolvedTarget: MIDIControlTarget? {
        if let target { return target }
        if let destination { return MIDIControlTarget(destination) }
        switch label.lowercased() {
        case "cutoff": return .cutoff
        case "master", "master volume", "amp": return .amp
        default: return nil
        }
    }

    var body: some View {
        LargeKnobBody(
            value: $value,
            range: range,
            label: label,
            format: format,
            modulated: modulated,
            modulationAmount: modulationAmount,
            target: resolvedTarget,
            defaultValue: defaultValue,
            themeID: theme.id
        )
        .equatable()
    }
}

private struct LargeKnobBody: View, Equatable {
    @Environment(\.theme) private var theme
    @Environment(\.liveModulation) private var liveModulationSnapshot
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    var modulated: [ModSource] = []
    var modulationAmount: Float = 0.0
    let target: MIDIControlTarget?
    let defaultValue: Float?
    let themeID: ThemeID

    private let knobSize: CGFloat = 70

    static func == (lhs: LargeKnobBody, rhs: LargeKnobBody) -> Bool {
        lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.label == rhs.label
            && lhs.format == rhs.format
            && lhs.modulated == rhs.modulated
            && lhs.modulationAmount == rhs.modulationAmount
            && lhs.target == rhs.target
            && lhs.defaultValue == rhs.defaultValue
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                KnobDiscShadow(diameter: knobSize + 6, themeID: theme.id)
                .equatable()

                ForEach(0..<11) { i in
                    let angle = -135 + Double(i) * 27
                    Rectangle()
                        .fill(theme.textFaint.opacity(0.5))
                        .frame(width: 1, height: 6)
                        .offset(y: -knobSize / 2 - 5)
                        .rotationEffect(Angle(degrees: angle))
                }

                if modulationAmount != 0, let dest = resolvedDestination {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { _ in
                        KnobChrome(
                            fraction: fraction,
                            angle: rotationAngle,
                            diameter: knobSize,
                            indicatorWidth: 4,
                            centeredFill: range.lowerBound < 0 && range.upperBound > 0,
                            modulationAmount: modulationAmount,
                            liveModulation: liveModulationSnapshot?.value(for: dest) ?? 0
                        )
                    }
                } else {
                    KnobChrome(
                        fraction: fraction,
                        angle: rotationAngle,
                        diameter: knobSize,
                        indicatorWidth: 4,
                        centeredFill: range.lowerBound < 0 && range.upperBound > 0,
                        modulationAmount: modulationAmount
                    )
                }
                if !modulated.isEmpty {
                    Circle()
                        .fill(theme.aMod)
                        .frame(width: 5, height: 5)
                        .offset(y: knobSize * 0.38)
                        .help(modulated.map(\.rawValue).joined(separator: ", "))
                }
            }
            .modifier(KnobInteractiveModifier(value: $value, range: range, defaultValue: defaultValue))

            Text(label)
                .themeCaption(theme, size: 12, weight: .semibold)
                .foregroundColor(theme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            KnobValueField(
                value: $value,
                range: range,
                format: format,
                fontSize: 10,
                color: theme.accent
            )
        }
        .modifier(KnobContextMenuModifier(target: target))
    }

    private var fraction: CGFloat { knobArcFraction(value: value, range: range) }

    private var rotationAngle: Double {
        -135 + Double(fraction) * 270
    }

    private var resolvedDestination: ModDestination? {
        resolveKnobModDestination(target: target, label: label)
    }
}

struct KnobChrome: View {
    var fraction: CGFloat
    var angle: Double
    var diameter: CGFloat
    var indicatorWidth: CGFloat = 3
    /// Bipolar ranges draw the value arc out from the center of the sweep.
    var centeredFill: Bool = false
    var modulationAmount: Float = 0.0
    var liveModulation: Float = 0.0
    @Environment(\.theme) private var theme

    private var fillStart: CGFloat {
        let unit = max(0, min(1, fraction))
        guard centeredFill else { return 0 }
        return 0.75 * min(unit, 0.5)
    }

    private var fillEnd: CGFloat {
        let unit = max(0, min(1, fraction))
        guard centeredFill else { return 0.75 * unit }
        return 0.75 * max(unit, 0.5)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.knobTop, theme.knobBottom],
                        center: UnitPoint(x: 0.5, y: 0.38),
                        startRadius: 1,
                        endRadius: diameter * 0.62
                    )
                )
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(theme.knobRing, lineWidth: 1.5)
                .frame(width: diameter - 2, height: diameter - 2)

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(theme.knobTrack, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: diameter - 6, height: diameter - 6)

            Circle()
                .trim(from: fillStart, to: fillEnd)
                .stroke(theme.knobFill, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: diameter - 6, height: diameter - 6)

            if modulationAmount != 0 {
                let modDelta = CGFloat(modulationAmount) / 2.0
                let modStart = max(0, min(0.75, (fraction + min(0, modDelta)) * 0.75))
                let modEnd = max(0, min(0.75, (fraction + max(0, modDelta)) * 0.75))
                Circle()
                    .trim(from: modStart, to: modEnd)
                    .stroke(theme.aMod, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: diameter - 6, height: diameter - 6)

                let liveFrac = max(0, min(1, fraction + CGFloat(liveModulation) / 2.0))
                let liveAng = -135 + Double(liveFrac) * 270
                Circle()
                    .fill(theme.accent)
                    .frame(width: 4, height: 4)
                    .offset(y: -(diameter - 6) / 2)
                    .rotationEffect(.degrees(liveAng))
            }

            Rectangle()
                .fill(theme.knobIndicator)
                .frame(width: indicatorWidth, height: diameter * 0.34)
                .offset(y: -diameter * 0.16)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Click the readout to type. The disc keeps its own drag gesture.
struct KnobValueField: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    var format: String = "%.2f"
    var valueText: String? = nil
    var fontSize: CGFloat = 9
    var color: Color

    @State private var editing = false
    @State private var draft = ""
    @State private var rejectEdit = false
    @State private var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField("", text: $draft)
                    .font(theme.valueFont(size: fontSize))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundColor(theme.text)
                    .frame(minWidth: 28)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous)
                            .fill(theme.inset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous)
                            .stroke(invalid ? theme.destructive : theme.border, lineWidth: 1)
                    )
                    .focused($focused)
                    .onSubmit { commit() }
                    .onExitCommand { cancel() }
                    .onAppear { beginTyping() }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { finishTyping() }
                    }
            } else {
                Text(KnobValueParser.display(value: value, format: format, valueText: valueText, range: range))
                    .font(theme.valueFont(size: fontSize))
                    .foregroundColor(invalid ? theme.destructive : color)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditing() }
                    .background(
                        RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous)
                            .fill(invalid ? theme.destructive.opacity(0.35) : Color.clear)
                    )
            }
        }
    }

    private func startEditing() {
        draft = KnobValueParser.editingText(value: value, format: format, valueText: valueText, range: range)
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

    private func cancel() {
        let kept = KnobTyping.resolved(
            draft: draft,
            current: value,
            format: format,
            range: range,
            cancelled: true
        )
        if kept.value != value { value = kept.value }
        rejectEdit = true
        invalid = false
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
        let result = KnobTyping.resolved(
            draft: draft,
            current: value,
            format: format,
            range: range,
            cancelled: false
        )
        if result.value != value { value = result.value }
        invalid = result.invalid
        if result.invalid {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                invalid = false
            }
        }
        editing = false
        focused = false
    }
}

/// Static knob well. Parent redraws skip this when the diameter is unchanged.
private struct KnobDiscShadow: View, Equatable {
    @Environment(\.theme) private var theme
    let diameter: CGFloat
    let themeID: ThemeID

    static func == (lhs: KnobDiscShadow, rhs: KnobDiscShadow) -> Bool {
        lhs.diameter == rhs.diameter && lhs.themeID == rhs.themeID
    }

    var body: some View {
        Circle()
            .fill(theme.inset)
            .frame(width: diameter, height: diameter)
            .compositingGroup()
            .shadow(color: theme.knobShadow.color, radius: theme.knobShadow.radius, x: 0, y: theme.knobShadow.y)
            .drawingGroup()
    }
}

#Preview {
    HStack(spacing: 30) {
        KnobView(value: .constant(0.5), range: 0...1, label: "Volume")
        LargeKnobView(value: .constant(0.7), range: 0...1, label: "Cutoff")
    }
    .padding()
    .background(Theme.baseline.bg)
}
