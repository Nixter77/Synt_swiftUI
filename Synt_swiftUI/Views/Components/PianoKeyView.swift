//
//  PianoKeyView.swift
//  Synt_swiftUI
//

import SwiftUI

struct PianoKeyView: View {
    @Environment(\.theme) private var theme
    let note: Note
    let isPressed: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        if note.isBlack {
            BlackKeyView(note: note, isPressed: isPressed, onPress: onPress, onRelease: onRelease, themeID: theme.id)
                .equatable()
        } else {
            WhiteKeyView(note: note, isPressed: isPressed, onPress: onPress, onRelease: onRelease, themeID: theme.id)
                .equatable()
        }
    }
}

struct WhiteKeyView: View, Equatable {
    @Environment(\.theme) private var theme
    let note: Note
    let isPressed: Bool
    var width: CGFloat = 36
    var height: CGFloat = 140
    let onPress: () -> Void
    let onRelease: () -> Void
    let themeID: ThemeID

    static func == (lhs: WhiteKeyView, rhs: WhiteKeyView) -> Bool {
        lhs.note == rhs.note && lhs.isPressed == rhs.isPressed && lhs.width == rhs.width && lhs.height == rhs.height
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 3D white key with realistic depth
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: isPressed
                            ? [theme.accent.opacity(0.15), theme.accent.opacity(0.08)]
                            : [Color.white, Color(white: 0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .compositingGroup()
                .shadow(
                    color: isPressed ? theme.accent.opacity(0.2) : theme.cardShadow.color,
                    radius: isPressed ? 1 : 4,
                    x: 0,
                    y: isPressed ? 1 : 3
                )
                .drawingGroup()
            
            // Top highlight for 3D bevel
            if !isPressed {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), Color.white.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }

            Text(note.name.prefix(note.name.count - 1))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(isPressed ? theme.accent : theme.textFaint)
                .padding(.bottom, 8)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

struct BlackKeyView: View, Equatable {
    @Environment(\.theme) private var theme
    let note: Note
    let isPressed: Bool
    var width: CGFloat = 24
    var height: CGFloat = 90
    let onPress: () -> Void
    let onRelease: () -> Void
    let themeID: ThemeID

    static func == (lhs: BlackKeyView, rhs: BlackKeyView) -> Bool {
        lhs.note == rhs.note && lhs.isPressed == rhs.isPressed && lhs.width == rhs.width && lhs.height == rhs.height
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        ZStack {
            // 3D black key with depth
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: isPressed
                            ? [theme.accent.opacity(0.8), theme.accent.opacity(0.5)]
                            : [Color(white: 0.22), Color(white: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .compositingGroup()
                .shadow(
                    color: isPressed ? theme.accent.opacity(0.3) : Color.black.opacity(0.4),
                    radius: isPressed ? 1 : 4,
                    x: 0,
                    y: isPressed ? 1 : 3
                )
                .drawingGroup()
            
            // Subtle top highlight
            VStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isPressed ? 0.15 : 0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 30)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#Preview {
    HStack {
        PianoKeyView(
            note: Note(midiNote: 60),
            isPressed: false,
            onPress: {},
            onRelease: {}
        )
        PianoKeyView(
            note: Note(midiNote: 61),
            isPressed: true,
            onPress: {},
            onRelease: {}
        )
    }
    .padding()
    .background(Theme.baseline.bg)
}
