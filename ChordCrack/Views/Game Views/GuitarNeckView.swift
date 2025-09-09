import SwiftUI

/// Professional guitar neck visualization component
/// Displays chord fingerings with controlled animations and no shadows for stability
struct GuitarNeckView: View {
    let chord: ChordType?
    let currentAttempt: Int
    let jumbledPositions: [Int]
    let revealedFingerIndex: Int
    
    @State private var showFingers = false
    @State private var showStrings = false
    @State private var stringShake = false
    
    // MARK: - Computed Properties
    
    private var shouldShowFingers: Bool {
        return currentAttempt >= 5
    }
    
    private var shouldShowJumbledFingers: Bool {
        return currentAttempt == 5 && !jumbledPositions.isEmpty
    }
    
    private var shouldShowRevealedFinger: Bool {
        return currentAttempt == 6 && revealedFingerIndex >= 0
    }
    
    // MARK: - Main Body
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                neckBackground
                FretWiresView()
                FretMarkersView()
                StringsView(showStrings: showStrings, stringShake: stringShake)
                
                if let chord = chord, shouldShowFingers {
                    fingeringView(for: chord)
                }
            }
            .frame(width: 350, height: 280)
        }
        .onAppear {
            setupInitialDisplay()
        }
        .onChange(of: chord) { _, newValue in
            handleChordChange(newValue)
        }
        .onChange(of: currentAttempt) { _, newValue in
            handleAttemptChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerStringShake)) { _ in
            triggerStringShake()
        }
    }
    
    // MARK: - View Components
    
    private var neckBackground: some View {
        let woodGradient = LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.2, blue: 0.1),
                Color(red: 0.45, green: 0.3, blue: 0.15),
                Color(red: 0.4, green: 0.25, blue: 0.12),
                Color(red: 0.5, green: 0.35, blue: 0.2),
                Color(red: 0.4, green: 0.25, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        return RoundedRectangle(cornerRadius: 12)
            .fill(woodGradient)
            .frame(width: 320, height: 250)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func fingeringView(for chord: ChordType) -> some View {
        if shouldShowJumbledFingers {
            JumbledFingeringView(
                chord: chord,
                jumbledPositions: jumbledPositions,
                animate: showFingers
            )
        } else if shouldShowRevealedFinger {
            RevealedFingerView(
                chord: chord,
                revealedIndex: revealedFingerIndex,
                animate: showFingers
            )
        } else {
            ChordFingeringView(chord: chord, animate: showFingers)
        }
    }
    
    // MARK: - State Management
    
    private func setupInitialDisplay() {
        showStrings = true
        if chord != nil && shouldShowFingers {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showFingers = true
            }
        }
    }
    
    private func handleChordChange(_ newChord: ChordType?) {
        if newChord != nil {
            withAnimation(.easeInOut(duration: 0.5)) {
                showStrings = true
            }
            
            if shouldShowFingers {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showFingers = true
                    }
                }
            }
        } else {
            showFingers = false
        }
    }
    
    private func handleAttemptChange() {
        showFingers = false
        if shouldShowFingers {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showFingers = true
                }
            }
        }
    }
    
    private func triggerStringShake() {
        stringShake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            stringShake = false
        }
    }
}

// MARK: - Supporting Views

/// Fret wires component - clean lines without shadows
struct FretWiresView: View {
    private let fretSpacing: [CGFloat] = [0, 55, 100, 140, 175, 205]
    
    var body: some View {
        ZStack {
            // Nut (position 0)
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 8, height: 200)
                .position(x: 50 + fretSpacing[0], y: 125)
            
            // Fret wires (positions 1-5)
            ForEach(1..<fretSpacing.count, id: \.self) { fretIndex in
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2.5, height: 200)
                    .position(x: 50 + fretSpacing[fretIndex], y: 125)
            }
        }
        .frame(width: 320, height: 250)
    }
}

/// Fret position markers - minimal design without shadows
struct FretMarkersView: View {
    var body: some View {
        ZStack {
            // 3rd fret marker
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 12, height: 12)
                .position(x: 50 + 120, y: 125)
            
            // 5th fret marker
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 12, height: 12)
                .position(x: 50 + 190, y: 125)
        }
        .frame(width: 320, height: 250)
    }
}

/// Guitar strings component with controlled shake animation
struct StringsView: View {
    let showStrings: Bool
    let stringShake: Bool
    
    private let stringPositions: [CGFloat] = [75, 95, 115, 135, 155, 175]
    
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { stringIndex in
                StringView(
                    stringIndex: stringIndex,
                    yPosition: stringPositions[stringIndex],
                    showStrings: showStrings,
                    stringShake: stringShake
                )
            }
        }
        .frame(width: 320, height: 250)
    }
}

/// Individual guitar string with subtle animation
struct StringView: View {
    let stringIndex: Int
    let yPosition: CGFloat
    let showStrings: Bool
    let stringShake: Bool
    
    private var stringColors: [Color] {
        [
            Color(red: 0.7, green: 0.6, blue: 0.3),
            Color(red: 0.75, green: 0.65, blue: 0.35),
            Color(red: 0.8, green: 0.7, blue: 0.4),
            Color(red: 0.85, green: 0.75, blue: 0.45),
            Color(red: 0.9, green: 0.8, blue: 0.5),
            Color(red: 0.9, green: 0.8, blue: 0.5)
        ]
    }
    
    private var stringWidths: [CGFloat] {
        [2.5, 2.0, 1.8, 1.5, 1.2, 1.0]
    }
    
    var body: some View {
        let scaleX = showStrings ? (stringShake ? 1.1 : 1.0) : 0.9
        let scaleY = showStrings ? (stringShake ? 1.2 : 1.0) : 0.8
        let offsetX = stringShake ? CGFloat.random(in: -2...2) : 0
        let offsetY = stringShake ? CGFloat.random(in: -0.5...0.5) : 0
        
        let animation = stringShake ?
            Animation.easeInOut(duration: 0.08).repeatCount(8, autoreverses: true) :
            Animation.easeInOut(duration: 0.3)
        
        return Rectangle()
            .fill(stringColors[stringIndex])
            .frame(width: 230, height: stringWidths[stringIndex])
            .position(x: 160, y: yPosition)
            .scaleEffect(x: scaleX, y: scaleY)
            .offset(x: offsetX, y: offsetY)
            .animation(animation, value: stringShake)
    }
}

// MARK: - Chord Fingering Views

/// Standard chord fingering display
struct ChordFingeringView: View {
    let chord: ChordType
    let animate: Bool
    
    private var fingerPositions: [(string: Int, fret: Int)] {
        let positions = chord.fingerPositions
        let stringMap = ["E2": 0, "A3": 1, "D3": 2, "G3": 3, "B4": 4, "E4": 5]
        
        return positions.compactMap { position in
            if let stringIndex = stringMap[position.string], position.fret > 0 {
                return (stringIndex, position.fret)
            }
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(fingerPositions.enumerated()), id: \.offset) { index, position in
                FingerDotView(
                    position: position,
                    animate: animate,
                    index: index,
                    color: ColorTheme.primaryGreen
                )
            }
        }
        .frame(width: 320, height: 250)
    }
}

/// Jumbled fingering display for hints
struct JumbledFingeringView: View {
    let chord: ChordType
    let jumbledPositions: [Int]
    let animate: Bool
    
    var body: some View {
        ZStack {
            ForEach(Array(jumbledPositions.enumerated()), id: \.offset) { index, position in
                JumbledFingerDotView(
                    position: position,
                    animate: animate,
                    index: index
                )
            }
        }
        .frame(width: 320, height: 250)
    }
}

/// Single revealed finger display
struct RevealedFingerView: View {
    let chord: ChordType
    let revealedIndex: Int
    let animate: Bool
    
    private var fingerPositions: [(string: Int, fret: Int)] {
        let positions = chord.fingerPositions
        let stringMap = ["E2": 0, "A3": 1, "D3": 2, "G3": 3, "B4": 4, "E4": 5]
        
        return positions.compactMap { position in
            if let stringIndex = stringMap[position.string], position.fret > 0 {
                return (stringIndex, position.fret)
            }
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            if revealedIndex < fingerPositions.count {
                let position = fingerPositions[revealedIndex]
                FingerDotView(
                    position: position,
                    animate: animate,
                    index: 0,
                    color: Color.yellow
                )
            }
        }
        .frame(width: 320, height: 250)
    }
}

// MARK: - Finger Dot Components

/// Professional finger position dot without shadows
struct FingerDotView: View {
    let position: (string: Int, fret: Int)
    let animate: Bool
    let index: Int
    let color: Color
    
    private let stringPositions: [CGFloat] = [75, 95, 115, 135, 155, 175]
    private let fretPositions: [CGFloat] = [55, 100, 140, 175, 205]
    
    var body: some View {
        let size = animate ? 26.0 : 18.0
        let scale = animate ? 1.0 : 0.75
        let opacity = animate ? 1.0 : 0.7
        
        let fretIndex = min(position.fret - 1, fretPositions.count - 1)
        let xPosition: CGFloat = 50 + fretPositions[fretIndex]
        let yPosition = stringPositions[position.string]
        let animationDelay = Double(index) * 0.1
        
        return Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.8), lineWidth: 2)
            )
            .position(x: xPosition, y: yPosition)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7)
                .delay(animationDelay),
                value: animate
            )
    }
}

/// Jumbled finger dot for hints
struct JumbledFingerDotView: View {
    let position: Int
    let animate: Bool
    let index: Int
    
    private let stringPositions: [CGFloat] = [75, 95, 115, 135, 155, 175]
    private let fretPositions: [CGFloat] = [55, 100, 140, 175, 205]
    
    var body: some View {
        let size = animate ? 24.0 : 16.0
        let scale = animate ? 1.0 : 0.75
        let opacity = animate ? 0.8 : 0.5
        
        let randomString = Int.random(in: 0..<6)
        let randomFret = Int.random(in: 0..<5)
        let xPosition: CGFloat = 50 + fretPositions[randomFret]
        let yPosition = stringPositions[randomString]
        let animationDelay = Double(index) * 0.15
        
        return Circle()
            .fill(Color.orange)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
            )
            .position(x: xPosition, y: yPosition)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7)
                .delay(animationDelay),
                value: animate
            )
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let triggerStringShake = Notification.Name("triggerStringShake")
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Guitar Neck Examples")
            .font(.title)
            .foregroundColor(ColorTheme.textPrimary)
        
        GuitarNeckView(
            chord: .cMajor,
            currentAttempt: 5,
            jumbledPositions: [1, 2, 3],
            revealedFingerIndex: -1
        )
        
        GuitarNeckView(
            chord: .cMajor,
            currentAttempt: 6,
            jumbledPositions: [],
            revealedFingerIndex: 0
        )
    }
    .background(ColorTheme.background)
}
