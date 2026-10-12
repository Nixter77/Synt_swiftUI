//
//  SpectrumAnalyzer.swift
//  Synt_swiftUI
//
//  FFT-based spectrum analyzer view for audio visualization.
//

import SwiftUI
import Accelerate

// MARK: - Spectrum Data Model

final class SpectrumData {
    var magnitudes: [Float] = []
    var peakMagnitudes: [Float] = []
    
    private let fftSize: Int
    private let binCount: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var inputBuffer: [Float] = []
    private var realPart: [Float] = []
    private var imagPart: [Float] = []
    private var window: [Float] = []
    private let peakDecay: Float = 0.95
    private let smoothingFactor: Float = 0.7
    
    init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        self.binCount = fftSize / 2
        inputBuffer = Array(repeating: 0, count: fftSize)
        realPart = Array(repeating: 0, count: fftSize)
        imagPart = Array(repeating: 0, count: fftSize)
        magnitudes = Array(repeating: 0, count: binCount)
        peakMagnitudes = Array(repeating: 0, count: binCount)
        window = Array(repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }
    
    deinit {
        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
    }
    
    func process(samples: [Float]) {
        guard samples.count >= fftSize, let setup = fftSetup else { return }
        let startIndex = max(0, samples.count - fftSize)
        for i in 0..<fftSize { inputBuffer[i] = samples[startIndex + i] }
        vDSP_vmul(inputBuffer, 1, window, 1, &inputBuffer, 1, vDSP_Length(fftSize))
        for i in 0..<fftSize { realPart[i] = inputBuffer[i]; imagPart[i] = 0 }
        var outputReal = [Float](repeating: 0, count: fftSize)
        var outputImag = [Float](repeating: 0, count: fftSize)
        vDSP_DFT_Execute(setup, realPart, imagPart, &outputReal, &outputImag)
        var newMagnitudes = [Float](repeating: 0, count: binCount)
        for i in 0..<binCount {
            let mag = sqrt(outputReal[i] * outputReal[i] + outputImag[i] * outputImag[i]) / Float(fftSize)
            let dB = 20.0 * log10(max(mag, 1e-10))
            newMagnitudes[i] = max(0, min(1, (dB + 80.0) / 80.0))
        }
        for i in 0..<binCount {
            magnitudes[i] = magnitudes[i] * smoothingFactor + newMagnitudes[i] * (1.0 - smoothingFactor)
            if newMagnitudes[i] > peakMagnitudes[i] { peakMagnitudes[i] = newMagnitudes[i] }
            else { peakMagnitudes[i] *= peakDecay }
        }
    }
    
    func reset() {
        magnitudes = Array(repeating: 0, count: binCount)
        peakMagnitudes = Array(repeating: 0, count: binCount)
    }
}

// MARK: - Spectrum Analyzer View

struct SpectrumAnalyzerView: View {
    var data: SpectrumData
    var barCount: Int = 32
    var showPeaks: Bool = true
    var colorScheme: SpectrumColorScheme = .gradient
    /// Display mapping. The live engine rate replaces this default.
    var sampleRate: Float = 44100

    enum SpectrumColorScheme { case gradient, rainbow, mono }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { context, size in
                let barWidth = size.width / CGFloat(barCount)
                let barSpacing: CGFloat = 2
                for index in 0..<barCount {
                    let magnitude = CGFloat(getMagnitude(forBar: index))
                    let width = max(1, barWidth - barSpacing)
                    let x = 4 + CGFloat(index) * barWidth
                    let barHeight = magnitude * size.height
                    let rect = CGRect(x: x, y: size.height - barHeight, width: width, height: max(0, barHeight))
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: barShading(index: index, magnitude: magnitude, rect: rect)
                    )
                    if showPeaks {
                        let peak = CGFloat(getPeakMagnitude(forBar: index))
                        let peakRect = CGRect(x: x, y: size.height - peak * size.height, width: width, height: 2)
                        context.fill(Path(peakRect), with: .color(AppleTheme.textSecondary.opacity(0.6)))
                    }
                }
            }
        }
        .background(spectrumChrome)
        .overlay(gridLines(size: .zero))
        .overlay(frequencyLabels(size: .zero))
        .frame(minWidth: 200, minHeight: 100)
    }

    private var spectrumChrome: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppleTheme.surfaceInset)
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 1, y: 2)
            .shadow(color: Color.white.opacity(0.8), radius: 2, x: -1, y: -1)
            .drawingGroup()
    }

    private func barShading(index: Int, magnitude: CGFloat, rect: CGRect) -> GraphicsContext.Shading {
        let colors: [Color]
        switch colorScheme {
        case .gradient:
            let mag = Double(magnitude)
            colors = [
                AppleTheme.accentEnvelope.opacity(mag),
                AppleTheme.accentModulation.opacity(mag),
                AppleTheme.accentOscillator.opacity(mag)
            ]
        case .rainbow:
            let hue = Double(index) / Double(barCount)
            colors = [Color(hue: hue, saturation: 0.6, brightness: 0.85)]
        case .mono:
            colors = [AppleTheme.accentBlue.opacity(0.7)]
        }
        return .linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint(x: rect.midX, y: rect.maxY),
            endPoint: CGPoint(x: rect.midX, y: rect.minY)
        )
    }
    
    private func getMagnitude(forBar barIndex: Int) -> Float {
        guard !data.magnitudes.isEmpty else { return 0 }
        let (startBin, endBin) = binRange(forBar: barIndex)
        var maxMag: Float = 0
        for i in startBin..<endBin { if i < data.magnitudes.count { maxMag = max(maxMag, data.magnitudes[i]) } }
        return maxMag
    }
    
    private func getPeakMagnitude(forBar barIndex: Int) -> Float {
        guard !data.peakMagnitudes.isEmpty else { return 0 }
        let (startBin, endBin) = binRange(forBar: barIndex)
        var maxMag: Float = 0
        for i in startBin..<endBin { if i < data.peakMagnitudes.count { maxMag = max(maxMag, data.peakMagnitudes[i]) } }
        return maxMag
    }
    
    private func binRange(forBar barIndex: Int) -> (Int, Int) {
        let binCount = data.magnitudes.count
        guard binCount > 0 else { return (0, 1) }
        let minFreq: Float = 20; let maxFreq: Float = 20000
        let t0 = Float(barIndex) / Float(barCount); let t1 = Float(barIndex + 1) / Float(barCount)
        let freq0 = minFreq * pow(maxFreq / minFreq, t0); let freq1 = minFreq * pow(maxFreq / minFreq, t1)
        let bin0 = Int(freq0 * Float(binCount) * 2 / sampleRate); let bin1 = Int(freq1 * Float(binCount) * 2 / sampleRate)
        return (max(0, min(bin0, binCount - 1)), max(bin0 + 1, min(bin1 + 1, binCount)))
    }
    
    private func gridLines(size: CGSize) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                Spacer()
                Rectangle().fill(Color.black.opacity(0.05)).frame(height: 1)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private func frequencyLabels(size: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                Text("20"); Spacer(); Text("100"); Spacer(); Text("1k"); Spacer(); Text("10k"); Spacer(); Text("20k")
            }
            .font(.system(size: 8, design: .rounded)).foregroundColor(AppleTheme.textTertiary)
            .padding(.horizontal, 8).offset(y: 12)
        }
    }
}

#Preview {
    SpectrumAnalyzerView(data: SpectrumData())
        .frame(width: 400, height: 150).padding()
        .background(AppleTheme.windowBackground)
}
