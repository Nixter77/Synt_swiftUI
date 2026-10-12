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
                            ? [theme.keyPressed, theme.keyPressed]
                            : [theme.keyWhite, theme.keyWhiteEdge],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .compositingGroup()
                .shadow(color: theme.cardShadow.color, radius: 2, x: 0, y: 1)
                .drawingGroup()
            
            // Top highlight for 3D bevel
            if !isPressed {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        LinearGradient(
                            colors: [theme.keyHighlight.opacity(0.9), theme.keyHighlight.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }

            Text(note.name.prefix(note.name.count - 1))
                .font(theme.captionFont(size: 10))
                .foregroundColor(theme.keyLabel)
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
                            ? [theme.keyPressed, theme.keyPressed]
                            : [theme.keyBlack, theme.keyBlackEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .compositingGroup()
                .shadow(color: theme.cardShadow.color, radius: 2, x: 0, y: 1)
                .drawingGroup()
            
            // Subtle top highlight
            VStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [theme.keyHighlight.opacity(isPressed ? 0.15 : 0.2), Color.clear],
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
