import SwiftUI

/// Native controls share one radius scale: 12 for keys, 20 for grouped surfaces.
struct StudioPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct StudioSectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2.weight(.bold)).foregroundStyle(ColorTheme.textPrimary)
            Text(subtitle).font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A pick with six strings: a direct echo of the existing ChordCrack mark.
struct StudioPickShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.28), control1: CGPoint(x: rect.width * 0.25, y: rect.height * 0.83), control2: CGPoint(x: rect.minX, y: rect.height * 0.50))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.28), control1: CGPoint(x: rect.minX, y: rect.minY - rect.height * 0.07), control2: CGPoint(x: rect.maxX, y: rect.minY - rect.height * 0.07))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.height * 0.50), control2: CGPoint(x: rect.width * 0.75, y: rect.height * 0.83))
        return path
    }
}

struct StudioPickMark: View {
    var color: Color = ColorTheme.background
    var body: some View {
        ZStack {
            StudioPickShape().fill(color.opacity(0.10))
            StudioPickShape().stroke(color.opacity(0.40), lineWidth: 2)
            HStack(spacing: 7) {
                ForEach(0..<6) { index in
                    Capsule().fill(color.opacity(0.5))
                        .frame(width: index < 3 ? 1.5 : 2.5, height: CGFloat([42, 60, 73, 73, 60, 42][index]))
                }
            }
            VStack(spacing: 16) {
                ForEach(0..<3) { _ in Rectangle().fill(color.opacity(0.30)).frame(height: 1.5) }
            }.padding(.horizontal, 16).padding(.bottom, 27)
        }
        .frame(width: 84, height: 100)
        .rotationEffect(.degrees(12))
        .accessibilityHidden(true)
    }
}

/// Filled musical badges keep icon size stable while nearby labels scale.
struct StudioModeIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 48, height: 48)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
            .accessibilityHidden(true)
    }
}
