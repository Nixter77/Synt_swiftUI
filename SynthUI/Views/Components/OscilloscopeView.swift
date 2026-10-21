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

    public init() {
        let size = 512
        log2n = vDSP_Length(log2(Double(size)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        window = (0..<size).map {
            Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double($0) / Double(size - 1))))
        }
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    public func computeMagnitudes(from buffer: [Float]) -> [Float] {
        guard let fftSetup, buffer.count >= n else { return [] }
        var windowed = [Float](repeating: 0, count: n)
        for i in 0..<n {
            windowed[i] = buffer[i] * window[i]
        }

        var real = windowed
        var imag = [Float](repeating: 0, count: n)

        return real.withUnsafeMutableBufferPointer { rBuf in
            imag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                let halfN = n / 2
                var result = [Float](repeating: 0, count: halfN)
                for k in 0..<halfN {
                    let re = rBuf[k]
                    let im = iBuf[k]
                    let mag = sqrt(re * re + im * im) / Float(halfN)
                    let db = 20.0 * log10(max(mag, 1.0e-3))
                    let normalized = max(0.0, min(1.0, (db + 60.0) / 60.0))
                    result[k] = normalized
                }
                return result
            }
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
    @State var mode: OutputVisualizerMode = .scope

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.rSmall)
                .fill(theme.scopeBg)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isRunning)) { _ in
                Canvas { context, size in
                    let data = metering.readScopeBuffer()
                    let count = data.count
                    guard count > 1 else { return }

                    let strokeColor = lineColor ?? theme.scopeLine

                    if mode == .scope {
                        let midY = size.height / 2.0
                        let stepX = size.width / CGFloat(count - 1)
                        var path = Path()
                        let start = min(1.0, max(-1.0, CGFloat(data[0])))
                        path.move(to: CGPoint(x: 0, y: midY - start * midY))
                        for i in 1..<count {
                            let sample = min(1.0, max(-1.0, CGFloat(data[i])))
                            path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: midY - sample * midY))
                        }
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    } else {
                        let mags = OutputSpectrumCalculator.shared.computeMagnitudes(from: data)
                        guard mags.count > 1 else { return }
                        let barCount = 48
                        let barWidth = size.width / CGFloat(barCount)

                        var fillPath = Path()
                        fillPath.move(to: CGPoint(x: 0, y: size.height))
                        for b in 0..<barCount {
                            let norm = Float(b) / Float(barCount - 1)
                            let binIdx = min(mags.count - 1, max(1, Int(pow(Float(mags.count - 1), norm))))
                            let mag = CGFloat(mags[binIdx])
                            let x = CGFloat(b) * barWidth + barWidth * 0.5
                            let y = size.height * (1.0 - mag)
                            fillPath.addLine(to: CGPoint(x: x, y: y))
                        }
                        fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                        fillPath.closeSubpath()

                        let gradient = Gradient(colors: [strokeColor.opacity(0.35), strokeColor.opacity(0.04)])
                        context.fill(
                            fillPath,
                            with: .linearGradient(
                                gradient,
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )

                        var linePath = Path()
                        for b in 0..<barCount {
                            let norm = Float(b) / Float(barCount - 1)
                            let binIdx = min(mags.count - 1, max(1, Int(pow(Float(mags.count - 1), norm))))
                            let mag = CGFloat(mags[binIdx])
                            let x = CGFloat(b) * barWidth + barWidth * 0.5
                            let y = size.height * (1.0 - mag)
                            if b == 0 {
                                linePath.move(to: CGPoint(x: x, y: y))
                            } else {
                                linePath.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        context.stroke(
                            linePath,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.rSmall))
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        mode = (mode == .scope ? .spectrum : .scope)
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(theme.card.opacity(0.85))
                            .foregroundColor(lineColor ?? theme.scopeLine)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.border.opacity(0.6), lineWidth: 0.5))
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
