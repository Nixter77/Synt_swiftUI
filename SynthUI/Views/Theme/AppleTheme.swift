//
//  Card, inset, pill, and section header modifiers.
//  Colors and the single shadow come from the environment theme.
//

import SwiftUI
import SynthCore

struct AppleCard3D: ViewModifier {
    var cornerRadius: CGFloat?
    var accentColor: Color?
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.rCard
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(theme.card)
                    .shadow(
                        color: theme.cardShadow.color,
                        radius: theme.cardShadow.radius,
                        x: 0,
                        y: theme.cardShadow.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.border, lineWidth: 1)
            )
            .overlay(
                Group {
                    if let accent = accentColor {
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accent)
                                .frame(height: theme.accentBar)
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                    }
                }
            )
    }
}

struct AppleInsetWell: ViewModifier {
    var cornerRadius: CGFloat?
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.rSmall
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(theme.inset)
                    .shadow(
                        color: theme.cardShadow.color,
                        radius: theme.cardShadow.radius,
                        x: 0,
                        y: theme.cardShadow.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

struct ApplePillButton: ViewModifier {
    var isActive: Bool = false
    var accentColor: Color?
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let accent = accentColor ?? theme.accent
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? accent.opacity(0.15) : theme.panel)
                    .shadow(
                        color: theme.cardShadow.color,
                        radius: theme.cardShadow.radius,
                        x: 0,
                        y: theme.cardShadow.y
                    )
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? accent.opacity(0.4) : theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func appleCard(cornerRadius: CGFloat? = nil, accent: Color? = nil) -> some View {
        modifier(AppleCard3D(cornerRadius: cornerRadius, accentColor: accent))
    }

    func appleInset(cornerRadius: CGFloat? = nil) -> some View {
        modifier(AppleInsetWell(cornerRadius: cornerRadius))
    }

    func applePill(isActive: Bool = false, accent: Color? = nil) -> some View {
        modifier(ApplePillButton(isActive: isActive, accentColor: accent))
    }
}

struct AppleSectionHeader: View {
    let title: String
    var accent: Color?
    var icon: String?
    @Environment(\.theme) private var theme

    var body: some View {
        let bar = accent ?? theme.accent
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(bar)
            }

            Text(title)
                .font(theme.headerFont)
                .tracking(theme.labelTracking)
                .textCase(theme.uppercaseLabels ? .uppercase : nil)
                .foregroundColor(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            RoundedRectangle(cornerRadius: 1)
                .fill(bar.opacity(0.2))
                .frame(height: 1)
        }
    }
}
