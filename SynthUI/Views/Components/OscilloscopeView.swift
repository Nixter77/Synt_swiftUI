//
//  OscilloscopeView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore
import Accelerate

public enum OutputVisualizerMode: String, CaseIterable, Sendable {
    case scope = "SCOPE"
    case spectrum = "SPEC"
}

public final class OutputSpectrumCalculator: @unchecked Sendable {
    public static let shared = OutputSpectrumCalculator()
    private let n = 512
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup?
    private let window: [Float]
    private let lock = NSLock()
    private var windowed: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var result: [Float]

    public init() {
        let size = 512
        log2n = vDSP_Length(log2(Double(size)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        window = (0..<size).map {
            Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double($0) / Double(size - 1))))
        }
        windowed = [Float](repeating: 0, count: size)
        real = [Float](repeating: 0, count: size)
        imag = [Float](repeating: 0, count: size)
        result = [Float](repeating: 0, count: size / 2)
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    public func computeMagnitudes(from buffer: [Float]) -> [Float] {
        guard let fftSetup, buffer.count >= n else { return [] }
        lock.lock()
        defer { lock.unlock() }

        let count = vDSP_Length(n)
        buffer.withUnsafeBufferPointer { bBuf in
            window.withUnsafeBufferPointer { wBuf in
                windowed.withUnsafeMutableBufferPointer { winBuf in
                    guard let bPtr = bBuf.baseAddress,
                          let wPtr = wBuf.baseAddress,
                          let winPtr = winBuf.baseAddress else { return }
                    vDSP_vmul(bPtr, 1, wPtr, 1, winPtr, 1, count)
                }
            }
        }
        windowed.withUnsafeBufferPointer { winBuf in
            real.withUnsafeMutableBufferPointer { rBuf in
                guard let winPtr = winBuf.baseAddress,
                      let rPtr = rBuf.baseAddress else { return }
                rPtr.update(from: winPtr, count: n)
            }
        }

        real.withUnsafeMutableBufferPointer { rBuf in
            imag.withUnsafeMutableBufferPointer { iBuf in
                result.withUnsafeMutableBufferPointer { resBuf in
                    guard let rPtr = rBuf.baseAddress,
                          let iPtr = iBuf.baseAddress,
                          let resPtr = resBuf.baseAddress else { return }
                    vDSP_vclr(iPtr, 1, count)
                    var split = DSPSplitComplex(realp: rPtr, imagp: iPtr)
                    vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                    let halfN = n / 2
                    for k in 0..<halfN {
                        let re = rPtr[k]
                        let im = iPtr[k]
                        let mag = sqrt(re * re + im * im) / Float(halfN)
                        let safeMag = mag.isFinite ? max(mag, 1.0e-3) : 1.0e-3
                        let db = 20.0 * log10(safeMag)
                        resPtr[k] = max(0.0, min(1.0, (db + 60.0) / 60.0))
                    }
                }
            }
        }
        return result
    }
}

public enum ScopeDisplayMode: String, CaseIterable, Sendable {
    case wave = "WAVE"
    case fft = "FFT"
    case phase = "PHASE"

    mutating func cycle() {
        switch self {
        case .wave: self = .fft
        case .fft: self = .phase
        case .phase: self = .wave
        }
    }
}

struct OscilloscopeView: View {
    @Environment(\.theme) private var theme
    var metering: AtomicMeteringState
    var lineColor: Color? = nil
    var lineWidth: CGFloat = 2.0
    /// Engine stopped: freeze the last frame instead of redrawing at 30 Hz.
    var isRunning: Bool = true
    @State private var displayMode: ScopeDisplayMode = .wave

    private static let hannWindow512: [Float] = (0..<512).map { i in
        Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / 511.0)))
    }

    static func risingZeroCrossingIndex(in data: [Float], maxSearch: Int) -> Int {
        let limit = min(maxSearch, data.count - 1)
        guard limit > 0 else { return 0 }
        for i in 0..<limit {
            if data[i] <= 0 && data[i + 1] > 0 {
                return i
            }
        }
        return 0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.rSmall)
                .fill(theme.scopeBg)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isRunning)) { _ in
                Canvas { context, size in
                    let data = metering.readScopeBuffer()
                    let count = data.count
                    let strokeColor = lineColor ?? theme.scopeLine

                    drawGraticule(context: &context, size: size)

                    switch displayMode {
                    case .wave:
                        drawWaveform(data: data, count: count, strokeColor: strokeColor, context: &context, size: size)
                    case .fft:
                        drawSpectrum(data: data, count: count, strokeColor: strokeColor, context: &context, size: size)
                    case .phase:
                        drawPhaseScope(data: data, count: count, strokeColor: strokeColor, context: &context, size: size)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.rSmall))
                .contentShape(Rectangle())
                .onTapGesture {
                    displayMode.cycle()
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        displayMode.cycle()
                    } label: {
                        Text(displayMode.rawValue)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.card.opacity(0.85))
                            .foregroundColor(lineColor ?? theme.scopeLine)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.border.opacity(0.65), lineWidth: 0.5))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("outputVisualizerMode")
                    .padding(4)
                }
                Spacer()
            }

            RoundedRectangle(cornerRadius: theme.rSmall)
                .stroke(theme.border, lineWidth: 1)
        }
    }

    private func drawGraticule(context: inout GraphicsContext, size: CGSize) {
        let gridColor = theme.border
        var gridPath = Path()
        for frac in [0.25, 0.75] as [CGFloat] {
            let y = size.height * frac
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        for frac in [0.25, 0.75] as [CGFloat] {
            let x = size.width * frac
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(gridPath, with: .color(gridColor.opacity(0.22)), lineWidth: 0.5)

        var axisPath = Path()
        let midY = size.height * 0.5
        let midX = size.width * 0.5
        axisPath.move(to: CGPoint(x: 0, y: midY))
        axisPath.addLine(to: CGPoint(x: size.width, y: midY))
        axisPath.move(to: CGPoint(x: midX, y: 0))
        axisPath.addLine(to: CGPoint(x: midX, y: size.height))
        context.stroke(axisPath, with: .color(gridColor.opacity(0.4)), lineWidth: 0.75)

        if displayMode == .phase {
            var diagPath = Path()
            diagPath.move(to: CGPoint(x: 0, y: size.height))
            diagPath.addLine(to: CGPoint(x: size.width, y: 0))
            diagPath.move(to: CGPoint(x: 0, y: 0))
            diagPath.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(
                diagPath,
                with: .color(gridColor.opacity(0.32)),
                style: StrokeStyle(lineWidth: 0.6, dash: [3, 3])
            )
        }
    }

    private func drawWaveform(
        data: [Float],
        count: Int,
        strokeColor: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard count > 1 else { return }

        let start = Self.risingZeroCrossingIndex(in: data, maxSearch: count / 2)
        let windowCount = max(2, count / 2)
        let end = min(count, start + windowCount)
        let visibleCount = end - start
        guard visibleCount > 1 else { return }

        let midY = size.height * 0.5
        let ampY = midY * 0.92
        let stepX = size.width / CGFloat(visibleCount - 1)
        var path = Path()
        var fillPath = Path()

        let firstSample = data[start].isFinite ? min(1.0, max(-1.0, CGFloat(data[start]))) : 0
        let firstPt = CGPoint(x: 0, y: midY - firstSample * ampY)
        path.move(to: firstPt)
        fillPath.move(to: CGPoint(x: 0, y: midY))
        fillPath.addLine(to: firstPt)

        for offset in 1..<visibleCount {
            let raw = data[start + offset]
            let sample = raw.isFinite ? min(1.0, max(-1.0, CGFloat(raw))) : 0
            let pt = CGPoint(x: CGFloat(offset) * stepX, y: midY - sample * ampY)
            path.addLine(to: pt)
            fillPath.addLine(to: pt)
        }
        fillPath.addLine(to: CGPoint(x: size.width, y: midY))
        fillPath.closeSubpath()

        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: [
                    strokeColor.opacity(0.28),
                    strokeColor.opacity(0.03),
                    strokeColor.opacity(0.28)
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        context.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawSpectrum(
        data: [Float],
        count: Int,
        strokeColor: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard count > 1 else { return }
        let n = min(count, 512)
        let bandCount = 32
        let sampleRate: Float = 44100.0
        let invNMinus1 = 1.0 / Float(max(1, n - 1))
        let normScale = 4.0 / Float(n)
        let slotW = size.width / CGFloat(bandCount)
        let barW = max(1.5, slotW * 0.72)

        var contourPath = Path()
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: 0, y: size.height))

        for b in 0..<bandCount {
            let frac = Float(b) / Float(bandCount - 1)
            let freq = 40.0 * powf(400.0, frac)
            let omega = 2.0 * Float.pi * freq / sampleRate
            let cosW = cosf(omega)
            let sinW = sinf(omega)
            let coeff = 2.0 * cosW

            var s1: Float = 0
            var s2: Float = 0
            if n == 512 {
                for i in 0..<512 {
                    let raw = data[i]
                    let sample = raw.isFinite ? raw : 0
                    let s0 = sample * Self.hannWindow512[i] + coeff * s1 - s2
                    s2 = s1
                    s1 = s0
                }
            } else {
                for i in 0..<n {
                    let raw = data[i]
                    let sample = raw.isFinite ? raw : 0
                    let win = 0.5 * (1.0 - cosf(2.0 * Float.pi * Float(i) * invNMinus1))
                    let s0 = sample * win + coeff * s1 - s2
                    s2 = s1
                    s1 = s0
                }
            }
            let re = s1 - s2 * cosW
            let im = s2 * sinW
            let mag = sqrtf(re * re + im * im) * normScale
            let db = 20.0 * log10f(max(mag, 1.0e-4))
            let level = CGFloat(max(0.0, min(1.0, (db + 60.0) / 60.0)))

            let barH = max(1.0, level * (size.height - 4.0))
            let cx = (CGFloat(b) + 0.5) * slotW
            let topY = size.height - barH

            let barRect = CGRect(x: cx - barW * 0.5, y: topY, width: barW, height: barH)
            context.fill(
                Path(roundedRect: barRect, cornerRadius: 1),
                with: .linearGradient(
                    Gradient(colors: [strokeColor.opacity(0.6), strokeColor.opacity(0.14)]),
                    startPoint: CGPoint(x: cx, y: topY),
                    endPoint: CGPoint(x: cx, y: size.height)
                )
            )

            let pt = CGPoint(x: cx, y: topY)
            if b == 0 {
                contourPath.move(to: pt)
            } else {
                contourPath.addLine(to: pt)
            }
            fillPath.addLine(to: pt)
        }
        fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
        fillPath.closeSubpath()

        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: [strokeColor.opacity(0.18), strokeColor.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        context.stroke(
            contourPath,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: max(1.25, lineWidth * 0.75), lineCap: .round, lineJoin: .round)
        )
    }

    private func drawPhaseScope(
        data: [Float],
        count: Int,
        strokeColor: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard count > 1 else { return }
        let midX = size.width * 0.5
        let midY = size.height * 0.5
        let scaleX = size.width * 0.44
        let scaleY = size.height * 0.44
        let split = count / 2

        var trailPath = Path()
        var freshPath = Path()
        var lastPt = CGPoint(x: midX, y: midY)

        for i in 0..<count {
            let rx = data[i]
            let ry = data[(i + 64) % count]
            let sx = rx.isFinite ? min(1.0, max(-1.0, CGFloat(rx))) : 0
            let sy = ry.isFinite ? min(1.0, max(-1.0, CGFloat(ry))) : 0
            let pt = CGPoint(x: midX + sx * scaleX, y: midY - sy * scaleY)

            if i < split {
                if i == 0 { trailPath.move(to: pt) } else { trailPath.addLine(to: pt) }
            } else {
                if i == split { freshPath.move(to: lastPt) }
                freshPath.addLine(to: pt)
            }
            lastPt = pt
        }

        context.stroke(
            trailPath,
            with: .color(strokeColor.opacity(0.32)),
            style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            freshPath,
            with: .color(strokeColor.opacity(0.95)),
            style: StrokeStyle(lineWidth: min(lineWidth, 1.6), lineCap: .round, lineJoin: .round)
        )
    }
}

#Preview {
    OscilloscopePreview()
        .frame(height: 100)
        .padding()
        .background(Theme.baseline.bg)
}

private struct OscilloscopePreview: View {
    let metering = AtomicMeteringState()

    var body: some View {
        OscilloscopeView(metering: metering)
            .onAppear {
                let samples = (0..<512).map { sin(Double($0) * 0.1).toFloat() }
                metering.writeScopeBuffer(samples)
            }
    }
}

extension Double {
    func toFloat() -> Float {
        return Float(self)
    }
}
