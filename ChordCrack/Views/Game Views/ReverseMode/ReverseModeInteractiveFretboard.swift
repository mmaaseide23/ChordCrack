import SwiftUI

// MARK: - Interactive Reverse Mode Fretboard
struct ReverseModeInteractiveFretboard: View {
    @Binding var placedFingers: Set<FingerPosition>
    @Binding var openStrings: Set<Int>
    @Binding var mutedStrings: Set<Int>
    
    let showCorrectPositions: Bool
    let correctPositions: [(string: String, fret: Int)]
    let incorrectPositions: Set<FingerPosition>
    let missingPositions: Set<FingerPosition>
    let showTheoryHints: Bool
    let isDisabled: Bool
    
    let onToggleFinger: (Int, Int) -> Void
    let onToggleString: (Int) -> Void
    
    // Fret positions for standard scale length
    private let fretPositions: [CGFloat] = [
        0,    // Nut
        60,   // 1st fret
        116,  // 2nd
        168,  // 3rd
        216,  // 4th
        261,  // 5th
        303,  // 6th
        342,  // 7th
        379,  // 8th
        413,  // 9th
        445,  // 10th
        475,  // 11th
        503   // 12th
    ]
    
    private let stringYPositions: [CGFloat] = [50, 90, 130, 170, 210, 250]
    private let stringNames = ["E", "B", "G", "D", "A", "E"]
    private let stringNotes = ["E4", "B4", "G3", "D3", "A3", "E2"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                fretboardBackground
                
                // Fret markers
                fretMarkers
                
                // Frets
                frets
                
                // Strings
                strings
                
                // String labels
                stringLabels
                
                // Open/Mute indicators
                openMuteIndicators
                
                // Theory hints
                if showTheoryHints {
                    theoryHintOverlay
                }
                
                // Correct positions feedback
                if showCorrectPositions {
                    correctPositionsFeedback
                }
                
                // Placed fingers
                placedFingerDots
                
                // Interactive layer
                if !isDisabled {
                    interactiveTouchLayer
                }
                
                // Fret numbers
                fretNumbers
            }
            .frame(width: geometry.size.width, height: 300)
        }
    }
    
    // MARK: - Fretboard Background
    private var fretboardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.15, blue: 0.30), // Purple-tinted wood
                        Color(red: 0.30, green: 0.18, blue: 0.35),
                        Color(red: 0.28, green: 0.16, blue: 0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.primaryPurple.opacity(0.3), lineWidth: 2)
            )
    }
    
    // MARK: - Fret Markers
    private var fretMarkers: some View {
        ZStack {
            // Single dots at 3rd, 5th, 7th, 9th frets
            ForEach([3, 5, 7, 9], id: \.self) { fretNumber in
                Circle()
                    .fill(ColorTheme.primaryPurple.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .position(
                        x: (fretPositions[fretNumber - 1] + fretPositions[fretNumber]) / 2,
                        y: 150
                    )
            }
            
            // Double dots at 12th fret
            Circle()
                .fill(ColorTheme.primaryPurple.opacity(0.3))
                .frame(width: 12, height: 12)
                .position(
                    x: (fretPositions[11] + fretPositions[12]) / 2,
                    y: 120
                )
            
            Circle()
                .fill(ColorTheme.primaryPurple.opacity(0.3))
                .frame(width: 12, height: 12)
                .position(
                    x: (fretPositions[11] + fretPositions[12]) / 2,
                    y: 180
                )
        }
    }
    
    // MARK: - Frets
    private var frets: some View {
        ZStack {
            // Nut (thicker)
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 6, height: 240)
                .position(x: 30, y: 150)
            
            // Regular frets
            ForEach(1..<13) { fret in
                Rectangle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 2, height: 240)
                    .position(x: fretPositions[fret], y: 150)
            }
        }
    }
    
    // MARK: - Strings
    private var strings: some View {
        ZStack {
            ForEach(0..<6) { string in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.9 - Double(string) * 0.05,
                                      green: 0.8 - Double(string) * 0.05,
                                      blue: 0.6 - Double(string) * 0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: UIScreen.main.bounds.width - 80, height: CGFloat(1 + string))
                    .position(x: UIScreen.main.bounds.width / 2 - 40, y: stringYPositions[string])
            }
        }
    }
    
    // MARK: - String Labels
    private var stringLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<6) { string in
                Text(stringNames[string])
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorTheme.brightPurple)
                    .frame(height: 40)
            }
        }
        .position(x: 10, y: 150)
    }
    
    // MARK: - Open/Mute Indicators
    private var openMuteIndicators: some View {
        ZStack {
            ForEach(0..<6) { string in
                Button(action: {
                    if !isDisabled {
                        onToggleString(string)
                    }
                }) {
                    ZStack {
                        if openStrings.contains(string) {
                            Circle()
                                .stroke(ColorTheme.success, lineWidth: 2)
                                .frame(width: 24, height: 24)
                        } else if mutedStrings.contains(string) {
                            Text("×")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorTheme.error)
                        } else {
                            Circle()
                                .stroke(ColorTheme.textTertiary.opacity(0.3), lineWidth: 1)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .position(x: 30, y: stringYPositions[string])
                .disabled(isDisabled)
            }
        }
    }
    
    // MARK: - Theory Hint Overlay
    private var theoryHintOverlay: some View {
        ZStack {
            // Highlight important fret positions
            ForEach(correctPositions.indices, id: \.self) { index in
                let position = correctPositions[index]
                let stringIndex = stringNameToIndex(position.string)
                
                if position.fret > 0 {
                    Circle()
                        .fill(ColorTheme.primaryPurple.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .position(
                            x: (fretPositions[position.fret - 1] + fretPositions[position.fret]) / 2,
                            y: stringYPositions[stringIndex]
                        )
                }
            }
        }
    }
    
    // MARK: - Correct Positions Feedback
    private var correctPositionsFeedback: some View {
        ZStack {
            // Show correct positions in green
            ForEach(correctPositions.indices, id: \.self) { index in
                let position = correctPositions[index]
                let stringIndex = stringNameToIndex(position.string)
                
                if position.fret > 0 {
                    Circle()
                        .fill(ColorTheme.success.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(ColorTheme.success, lineWidth: 2)
                        )
                        .position(
                            x: (fretPositions[position.fret - 1] + fretPositions[position.fret]) / 2,
                            y: stringYPositions[stringIndex]
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Show missing positions with pulsing effect
            ForEach(Array(missingPositions), id: \.self) { position in
                Circle()
                    .stroke(ColorTheme.warning, lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .position(
                        x: position.fret == 0 ? 30 : (fretPositions[position.fret - 1] + fretPositions[position.fret]) / 2,
                        y: stringYPositions[position.string]
                    )
                    .opacity(0.8)
            }
        }
    }
    
    // MARK: - Placed Finger Dots
    private var placedFingerDots: some View {
        ZStack {
            ForEach(Array(placedFingers), id: \.self) { position in
                let xPos = position.fret == 0 ? 30 :
                           (fretPositions[position.fret - 1] + fretPositions[position.fret]) / 2
                let yPos = stringYPositions[position.string]
                
                let isIncorrect = showCorrectPositions && incorrectPositions.contains(position)
                let fingerColor = isIncorrect ? ColorTheme.error : ColorTheme.primaryPurple
                
                Circle()
                    .fill(fingerColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .overlay(
                        Text("\(getFingerNumber(for: position))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .position(x: xPos, y: yPos)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: placedFingers)
            }
        }
    }
    
    // MARK: - Interactive Touch Layer
    private var interactiveTouchLayer: some View {
        ZStack {
            ForEach(0..<6) { string in
                ForEach(1..<13) { fret in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 45, height: 38)
                        .position(
                            x: (fretPositions[fret - 1] + fretPositions[fret]) / 2,
                            y: stringYPositions[string]
                        )
                        .onTapGesture {
                            onToggleFinger(string, fret)
                        }
                }
            }
        }
    }
    
    // MARK: - Fret Numbers
    private var fretNumbers: some View {
        ZStack {
            ForEach(0..<13) { fret in
                Text("\(fret)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorTheme.textTertiary)
                    .position(
                        x: fret == 0 ? 30 : fretPositions[fret],
                        y: 285
                    )
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func stringNameToIndex(_ stringName: String) -> Int {
        switch stringName {
        case "E4": return 0
        case "B4": return 1
        case "G3": return 2
        case "D3": return 3
        case "A3": return 4
        case "E2": return 5
        default: return 0
        }
    }
    
    private func getFingerNumber(for position: FingerPosition) -> Int {
        // Simple finger numbering based on position in set
        let sortedFingers = placedFingers.sorted {
            if $0.fret == $1.fret {
                return $0.string < $1.string
            }
            return $0.fret < $1.fret
        }
        return (sortedFingers.firstIndex(of: position) ?? 0) + 1
    }
}
