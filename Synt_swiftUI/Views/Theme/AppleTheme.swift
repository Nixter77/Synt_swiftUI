//
//  AppleTheme.swift
//  Synt_swiftUI
//
//  Apple-inspired light theme design system with 3D neumorphic elements.
//

import SwiftUI

// MARK: - Apple Theme Namespace

enum AppleTheme {
    
    // MARK: - Background Colors
    
    /// Main window background — warm off-white
    static let windowBackground = Color(red: 0.96, green: 0.96, blue: 0.97)
    
    /// Card / panel surface — pure white with translucency feel
    static let cardSurface = Color.white
    
    /// Secondary surface for nested elements
    static let surfaceSecondary = Color(red: 0.95, green: 0.95, blue: 0.96)
    
    /// Tertiary / inset well background
    static let surfaceInset = Color(red: 0.93, green: 0.93, blue: 0.94)
    
    // MARK: - Text Colors
    
    static let textPrimary = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let textSecondary = Color(red: 0.44, green: 0.44, blue: 0.46)
    static let textTertiary = Color(red: 0.64, green: 0.64, blue: 0.66)
    
    // MARK: - Accent Palette (soft, Apple-style)
    
    /// Primary accent — refined blue
    static let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    /// Oscillator accent — warm coral
    static let accentOscillator = Color(red: 1.0, green: 0.38, blue: 0.28)
    
    /// Envelope / ADSR accent — teal
    static let accentEnvelope = Color(red: 0.20, green: 0.78, blue: 0.64)
    
    /// Filter accent — soft violet
    static let accentFilter = Color(red: 0.58, green: 0.39, blue: 0.88)
    
    /// LFO accent — sky blue
    static let accentLFO = Color(red: 0.32, green: 0.70, blue: 0.96)
    
    /// Effects accent — rose
    static let accentEffects = Color(red: 0.94, green: 0.42, blue: 0.56)
    
    /// Modulation accent — amber
    static let accentModulation = Color(red: 0.98, green: 0.72, blue: 0.20)
    
    /// Sequencer accent — indigo
    static let accentSequencer = Color(red: 0.35, green: 0.34, blue: 0.84)
    
    /// Positive / active — green
    static let accentPositive = Color(red: 0.22, green: 0.78, blue: 0.35)
    
    /// Destructive — red
    static let accentDestructive = Color(red: 1.0, green: 0.27, blue: 0.23)
    
    // MARK: - Knob Colors
    
    /// Knob body gradient top
    static let knobTop = Color(red: 0.96, green: 0.96, blue: 0.97)
    
    /// Knob body gradient bottom
    static let knobBottom = Color(red: 0.86, green: 0.86, blue: 0.88)
    
    /// Knob indicator line
    static let knobIndicator = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    /// Knob indicator active
    static let knobIndicatorActive = Color(red: 1.0, green: 0.38, blue: 0.28)
    
    // MARK: - 3D Shadow System
    
    /// Outer drop shadow (creates "raised" effect)
    static func dropShadow(radius: CGFloat = 8) -> some View {
        Color.clear // placeholder, use modifier instead
    }
    
    /// Light source shadow color (top-left highlight)
    static let shadowLight = Color.white.opacity(0.7)
    
    /// Dark shadow color (bottom-right depth)
    static let shadowDark = Color(red: 0.70, green: 0.70, blue: 0.73).opacity(0.45)
    
    /// Intense shadow for 3D pop
    static let shadowDeep = Color(red: 0.60, green: 0.60, blue: 0.65).opacity(0.35)
    
    // MARK: - Corner Radius
    
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 20
    static let radiusXL: CGFloat = 28
}

// MARK: - Card 3D Modifier

struct AppleCard3D: ViewModifier {
    var cornerRadius: CGFloat = AppleTheme.radiusMedium
    var accentColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppleTheme.cardSurface)
                    .shadow(color: AppleTheme.shadowDark, radius: 10, x: 4, y: 6)
                    .shadow(color: AppleTheme.shadowLight, radius: 6, x: -3, y: -4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                // Subtle accent line at top
                Group {
                    if let accent = accentColor {
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accent)
                                .frame(height: 3)
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                }
            )
    }
}

// MARK: - Inset Well Modifier (for graphs, displays)

struct AppleInsetWell: ViewModifier {
    var cornerRadius: CGFloat = AppleTheme.radiusSmall
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppleTheme.surfaceInset)
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 1, y: 2)
                    .shadow(color: Color.white.opacity(0.9), radius: 2, x: -1, y: -1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            )
    }
}

// MARK: - Floating Pill Button

struct ApplePillButton: ViewModifier {
    var isActive: Bool = false
    var accentColor: Color = AppleTheme.accentBlue
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? accentColor.opacity(0.15) : AppleTheme.surfaceSecondary)
                    .shadow(color: AppleTheme.shadowDark, radius: isActive ? 2 : 6, x: 2, y: 3)
                    .shadow(color: AppleTheme.shadowLight, radius: isActive ? 1 : 4, x: -2, y: -2)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? accentColor.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func appleCard(cornerRadius: CGFloat = AppleTheme.radiusMedium, accent: Color? = nil) -> some View {
        self.modifier(AppleCard3D(cornerRadius: cornerRadius, accentColor: accent))
    }
    
    func appleInset(cornerRadius: CGFloat = AppleTheme.radiusSmall) -> some View {
        self.modifier(AppleInsetWell(cornerRadius: cornerRadius))
    }
    
    func applePill(isActive: Bool = false, accent: Color = AppleTheme.accentBlue) -> some View {
        self.modifier(ApplePillButton(isActive: isActive, accentColor: accent))
    }
}

// MARK: - Section Header Style

struct AppleSectionHeader: View {
    let title: String
    var accent: Color = AppleTheme.accentBlue
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppleTheme.textPrimary)
            
            RoundedRectangle(cornerRadius: 1)
                .fill(accent.opacity(0.2))
                .frame(height: 1)
        }
    }
}
