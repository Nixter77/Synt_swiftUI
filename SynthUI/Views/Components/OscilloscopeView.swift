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

struct OscilloscopeView: View {
    @Environment(\.theme) private var theme
    var metering: AtomicMeteringState
    var lineColor: Color? = nil
    var lineWidth: CGFloat = 2.0
    /// Engine stopped: freeze the last frame instead of redrawing at 30 Hz.
    var isRunning: Bool = true
    @State var mode: OutputVisualizerMode = .scope

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

                    if mode == .scope {
                        let gridColor = theme.border
                        var gridPath = Path()
                        for frac in [0.25, 0.75] as [CGFloat] {
                            let y = size.height * frac
                            gridPath.move(to: CGPoint(x: 0, y: y))
                            gridPath.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        for frac in [0.25, 0.5, 0.75] as [CGFloat] {
                            let x = size.width * frac
                            gridPath.move(to: CGPoint(x: x, y: 0))
                            gridPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        context.stroke(gridPath, with: .color(gridColor.opacity(0.25)), lineWidth: 0.5)

                        let midY = size.height / 2.0
                        var zeroPath = Path()
                        zeroPath.move(to: CGPoint(x: 0, y: midY))
                        zeroPath.addLine(to: CGPoint(x: size.width, y: midY))
                        context.stroke(zeroPath, with: .color(gridColor.opacity(0.45)), lineWidth: 0.75)

                        guard count > 1 else { return }

                        let start = Self.risingZeroCrossingIndex(in: data, maxSearch: count / 2)
                        let windowCount = max(2, count / 2)
                        let end = min(count, start + windowCount)
                        let visibleCount = end - start
                        guard visibleCount > 1 else { return }

                        let stepX = size.width / CGFloat(visibleCount - 1)
                        var path = Path()
                        let firstSample = data[start].isFinite ? min(1.0, max(-1.0, CGFloat(data[start]))) : 0
                        path.move(to: CGPoint(x: 0, y: midY - firstSample * midY))
                        for offset in 1..<visibleCount {
                            let raw = data[start + offset]
                            let sample = raw.isFinite ? min(1.0, max(-1.0, CGFloat(raw))) : 0
                            path.addLine(to: CGPoint(x: CGFloat(offset) * stepX, y: midY - sample * midY))
                        }
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    } else {
                        guard count > 1 else { return }
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
