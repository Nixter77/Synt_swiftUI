import SwiftUI

struct KeyboardView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var keyboardHandler: KeyboardHandler
    @ObservedObject var keyDisplay: PressedKeysModel
    private var pressedKeys: Set<Int> { keyDisplay.keys }
    let startNote: Int
    let numberOfOctaves: Int

    @State private var dragOffset: CGFloat = 0

    private let whiteKeySpacing: CGFloat = 2

    init(keyboardHandler: KeyboardHandler, keyDisplay: PressedKeysModel, startNote: Int = 48, numberOfOctaves: Int = 2) {
        self.keyboardHandler = keyboardHandler
        self.keyDisplay = keyDisplay
        self.startNote = startNote
        self.numberOfOctaves = numberOfOctaves
    }

    private var notes: [Note] {
        let endNote = startNote + (numberOfOctaves * 12)
        return (startNote..<endNote).map { Note(midiNote: $0) }
    }
    private var whiteNotes: [Note] { notes.filter { !$0.isBlack } }

    var body: some View {
        VStack(spacing: 12) {
            // Header Controls
            HStack(spacing: 12) {
                Button {
                    keyboardHandler.octaveDown()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.textDim)
                }
                .buttonStyle(.plain)

                Text("Octave \(keyboardHandler.baseOctave)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.text)
                    .frame(minWidth: 70)

                Button {
                    keyboardHandler.octaveUp()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.textDim)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .foregroundColor(theme.textFaint)
                    Text("Drag Blue Zone")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(theme.accent)
                    
                    Text(" | Z/X: Octave | A-L: Play")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textFaint)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.panel)
                .cornerRadius(6)
            }
            .padding(.horizontal)

            // Piano Keys Area
            GeometryReader { geo in
                let totalWhiteKeys = CGFloat(numberOfOctaves * 7)
                let totalSpacing = max(0, (totalWhiteKeys - 1) * whiteKeySpacing)
                let availableWidth = max(0, geo.size.width - 16) // Inner padding
                let whiteKeyWidth = max(10, (availableWidth - totalSpacing) / totalWhiteKeys)
                let blackKeyWidth = whiteKeyWidth * 0.65
                let whiteKeyHeight: CGFloat = 140
                let blackKeyHeight: CGFloat = 90
                
                ZStack(alignment: .topLeading) {
                    // 1. White Keys Layer
                    HStack(spacing: whiteKeySpacing) {
                        ForEach(whiteNotes, id: \.midiNote) { note in
                            WhiteKeyView(
                                note: note,
                                isPressed: pressedKeys.contains(note.midiNote),
                                width: whiteKeyWidth,
                                height: whiteKeyHeight,
                                onPress: { keyboardHandler.noteOn(midiNote: note.midiNote) },
                                onRelease: { keyboardHandler.noteOff(midiNote: note.midiNote) },
                                themeID: theme.id
                            )
                            .equatable()
                        }
                    }

                    // 2. Black Keys Layer
                    ForEach(0..<numberOfOctaves, id: \.self) { octave in
                        let baseNote = startNote + (octave * 12)
                        let blackKeyMappings = [
                            (offset: 1, whiteIndex: 0),
                            (offset: 3, whiteIndex: 1),
                            (offset: 6, whiteIndex: 3),
                            (offset: 8, whiteIndex: 4),
                            (offset: 10, whiteIndex: 5)
                        ]
                        
                        ForEach(blackKeyMappings, id: \.offset) { mapping in
                            let midiNote = baseNote + mapping.offset
                            let note = Note(midiNote: midiNote)
                            
                            // Calculate exact horizontal position
                            let globalWhiteIndex = (octave * 7) + mapping.whiteIndex
                            let seamCenter = CGFloat(globalWhiteIndex + 1) * (whiteKeyWidth + whiteKeySpacing) - (whiteKeySpacing / 2.0)
                            let leadingX = seamCenter - (blackKeyWidth / 2.0)
                            
                            BlackKeyView(
                                note: note,
                                isPressed: pressedKeys.contains(midiNote),
                                width: blackKeyWidth,
                                height: blackKeyHeight,
                                onPress: { keyboardHandler.noteOn(midiNote: midiNote) },
                                onRelease: { keyboardHandler.noteOff(midiNote: midiNote) },
                                themeID: theme.id
                            )
                            .equatable()
                            .offset(x: leadingX, y: 0)
                        }
                    }
                    
                    // 3. Active Zone Highlight Layer
                    let octaveWidth = 7 * (whiteKeyWidth + whiteKeySpacing)
                    let activeZoneWidth = 10 * whiteKeyWidth + 9 * whiteKeySpacing
                    let keyboardStartOctave = (startNote / 12) - 1
                    let baseOctaveOffset = keyboardHandler.baseOctave - keyboardStartOctave
                    
                    let activeZoneX = CGFloat(baseOctaveOffset) * octaveWidth + dragOffset
                    
                    // Visual only — a full-key hit target here stole piano onEnded
                    // and left notes hanging after release.
                    if activeZoneX + activeZoneWidth > -50 && activeZoneX < availableWidth + 50 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.kbZone)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.kbZoneBorder, lineWidth: 2)
                            )
                            .overlay(
                                VStack {
                                    HStack {
                                        Image(systemName: "macwindow")
                                        Text("Mac Keyboard")
                                    }
                                    .themeCaption(theme, size: 10, weight: .bold)
                                    .foregroundColor(theme.kbZoneBorder)
                                    .padding(.top, 6)
                                    Spacer()

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.kbZoneBorder.opacity(0.45))
                                        .frame(width: 40, height: 4)
                                        .padding(.bottom, 6)
                                }
                            )
                            .frame(width: activeZoneWidth, height: whiteKeyHeight)
                            .offset(x: activeZoneX, y: 0)
                            .allowsHitTesting(false)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.kbZoneBorder)
                            .frame(width: 44, height: 12)
                            .offset(
                                x: activeZoneX + (activeZoneWidth - 44) / 2,
                                y: whiteKeyHeight - 18
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation.width
                                    }
                                    .onEnded { _ in
                                        let draggedOctaves = Int(round(dragOffset / octaveWidth))
                                        let newOctave = keyboardHandler.baseOctave + draggedOctaves

                                        if newOctave != keyboardHandler.baseOctave {
                                            if newOctave > keyboardHandler.baseOctave {
                                                for _ in 0..<(newOctave - keyboardHandler.baseOctave) { keyboardHandler.octaveUp() }
                                            } else {
                                                for _ in 0..<(keyboardHandler.baseOctave - newOctave) { keyboardHandler.octaveDown() }
                                            }
                                        }

                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            dragOffset = 0
                                        }
                                    }
                            )
                    }
                }
                .padding(8) // Inner padding to prevent clipping shadows
                .clipped()  // Ensure active zone doesn't overflow outside the keyboard container
            }
            .frame(height: 140 + 16) // Explicit height since GeometryReader collapses in ScrollView
            .background(
                RoundedRectangle(cornerRadius: theme.rHeader)
                    .fill(theme.panel)
                    .compositingGroup()
                    .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
                    .drawingGroup()
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
        .appleCard(cornerRadius: theme.rHeader)
    }
}

#Preview {
    KeyboardView(keyboardHandler: KeyboardHandler(), keyDisplay: PressedKeysModel(), startNote: 36, numberOfOctaves: 4)
        .frame(height: 250)
        .background(Theme.baseline.bg)
        .padding()
}
