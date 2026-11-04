import SwiftUI

/// Original ChordCrack characters, drawn as vectors so small social badges stay crisp.
/// No downloaded artwork, external assets, animation, or network dependencies.
struct AvatarCharacterArtwork: View {
    let avatar: ProfileAvatar
    var body: some View {
        Canvas { context, size in
            var scaled = context
            scaled.scaleBy(x: size.width / 100, y: size.height / 100)
            CharacterPainter(context: scaled).draw(avatar)
        }.accessibilityHidden(true)
    }
}

private struct CharacterPainter {
    let context: GraphicsContext
    let ink = Color(red: 0.07, green: 0.13, blue: 0.20)
    let cream = Color(red: 1, green: 0.95, blue: 0.78)
    let mint = Color(red: 0.34, green: 0.91, blue: 0.73)
    let violet = Color(red: 0.69, green: 0.61, blue: 1)
    let pink = Color(red: 1, green: 0.46, blue: 0.64)
    let gold = Color(red: 1, green: 0.78, blue: 0.28)
    let coral = Color(red: 1, green: 0.51, blue: 0.35)
    let aqua = Color(red: 0.31, green: 0.81, blue: 0.94)

    func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat, _ color: Color) {
        context.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius), with: .color(color))
    }
    func shape(_ color: Color, _ build: (inout Path) -> Void) {
        var path = Path(); build(&path); context.fill(path, with: .color(color))
    }
    func line(_ color: Color, width: CGFloat = 3, _ build: (inout Path) -> Void) {
        var path = Path(); build(&path)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    func polygon(_ points: [CGPoint], _ color: Color) {
        shape(color) { p in p.addLines(points); p.closeSubpath() }
    }
    func eyes(y: CGFloat = 51, apart: CGFloat = 12, wink: Bool = false) {
        ellipse(50 - apart - 3.5, y, 7, 10, ink)
        ellipse(50 - apart - 2, y + 1.5, 2, 2.5, cream)
        if wink {
            line(ink) { p in p.move(to: CGPoint(x: 50 + apart - 4, y: y + 5)); p.addQuadCurve(to: CGPoint(x: 50 + apart + 4, y: y + 5), control: CGPoint(x: 50 + apart, y: y + 1)) }
        } else {
            ellipse(50 + apart - 3.5, y, 7, 10, ink)
            ellipse(50 + apart - 2, y + 1.5, 2, 2.5, cream)
        }
    }
    func smile(y: CGFloat = 68, width: CGFloat = 8) {
        line(ink, width: 2.8) { p in p.move(to: CGPoint(x: 50 - width, y: y)); p.addQuadCurve(to: CGPoint(x: 50 + width, y: y), control: CGPoint(x: 50, y: y + 8)) }
    }
    func cheeks(y: CGFloat = 65) { ellipse(27, y, 10, 5, pink.opacity(0.7)); ellipse(63, y, 10, 5, pink.opacity(0.7)) }

    func draw(_ avatar: ProfileAvatar) {
        // A tiny ground shadow anchors each silhouette inside the circular badge.
        ellipse(22, 82, 56, 8, ink.opacity(0.22))
        switch avatar {
        case .initial: break
        case .guitar: fox()
        case .keys: cat()
        case .headphones: bunny()
        case .note: bird()
        case .wave: wave()
        case .bolt: robot()
        case .star: star()
        case .sparkle: moth()
        }
    }
    func fox() {
        polygon([CGPoint(x: 19,y: 47),CGPoint(x: 18,y: 15),CGPoint(x: 43,y: 33)], coral)
        polygon([CGPoint(x: 57,y: 33),CGPoint(x: 82,y: 15),CGPoint(x: 81,y: 47)], coral)
        polygon([CGPoint(x: 25,y: 34),CGPoint(x: 25,y: 24),CGPoint(x: 35,y: 34)], pink)
        polygon([CGPoint(x: 65,y: 34),CGPoint(x: 75,y: 24),CGPoint(x: 75,y: 34)], pink)
        shape(coral) { p in
            p.move(to: CGPoint(x: 17,y: 44)); p.addQuadCurve(to: CGPoint(x: 83,y: 44),control: CGPoint(x: 50,y: 15))
            p.addQuadCurve(to: CGPoint(x: 50,y: 86),control: CGPoint(x: 94,y: 68))
            p.addQuadCurve(to: CGPoint(x: 17,y: 44),control: CGPoint(x: 7,y: 68))
        }
        shape(cream) { p in
            p.move(to: CGPoint(x: 19,y: 57)); p.addQuadCurve(to: CGPoint(x: 50,y: 66),control: CGPoint(x: 39,y: 48))
            p.addQuadCurve(to: CGPoint(x: 81,y: 57),control: CGPoint(x: 61,y: 48))
            p.addQuadCurve(to: CGPoint(x: 50,y: 84),control: CGPoint(x: 78,y: 78))
            p.addQuadCurve(to: CGPoint(x: 19,y: 57),control: CGPoint(x: 22,y: 78))
        }
        eyes(y: 48); ellipse(45, 63, 10, 7, ink); smile(y: 72, width: 5)
        polygon([CGPoint(x: 36,y: 82),CGPoint(x: 64,y: 82),CGPoint(x: 52,y: 94)], violet)
        polygon([CGPoint(x: 36,y: 82),CGPoint(x: 24,y: 83),CGPoint(x: 29,y: 92)], violet)
    }
    func cat() {
        polygon([CGPoint(x: 20,y: 50),CGPoint(x: 21,y: 17),CGPoint(x: 44,y: 34)], violet)
        polygon([CGPoint(x: 56,y: 34),CGPoint(x: 79,y: 17),CGPoint(x: 80,y: 50)], violet)
        polygon([CGPoint(x: 27,y: 36),CGPoint(x: 27,y: 26),CGPoint(x: 37,y: 36)], pink)
        polygon([CGPoint(x: 63,y: 36),CGPoint(x: 73,y: 26),CGPoint(x: 73,y: 36)], pink)
        ellipse(17, 30, 66, 56, violet); ellipse(35, 58, 30, 20, cream)
        eyes(y: 47, wink: true)
        polygon([CGPoint(x: 46,y: 61),CGPoint(x: 54,y: 61),CGPoint(x: 50,y: 66)], pink)
        smile(y: 69, width: 5)
        line(ink, width: 2) { p in
            p.move(to: CGPoint(x: 22,y: 61)); p.addLine(to: CGPoint(x: 33,y: 64))
            p.move(to: CGPoint(x: 20,y: 69)); p.addLine(to: CGPoint(x: 32,y: 69))
            p.move(to: CGPoint(x: 67,y: 64)); p.addLine(to: CGPoint(x: 78,y: 61))
            p.move(to: CGPoint(x: 68,y: 69)); p.addLine(to: CGPoint(x: 80,y: 69))
        }
        box(31, 80, 38, 10, 4, cream)
        for x in [39.0, 49.0, 59.0] { box(x, 80, 4, 6, 1, ink) }
    }
    func bunny() {
        ellipse(27, 8, 17, 49, mint); ellipse(56, 12, 17, 45, mint)
        ellipse(32, 15, 7, 30, pink); ellipse(61, 19, 7, 26, pink)
        ellipse(22, 40, 56, 48, mint)
        line(gold, width: 5) { p in p.move(to: CGPoint(x: 18,y: 64)); p.addCurve(to: CGPoint(x: 82,y: 64),control1: CGPoint(x: 14,y: 24),control2: CGPoint(x: 86,y: 24)) }
        box(13, 55, 12, 25, 6, gold); box(75, 55, 12, 25, 6, gold)
        eyes(y: 55); cheeks(y: 69); ellipse(47, 67, 6, 5, pink); smile(y: 74, width: 5)
    }
    func bird() {
        ellipse(22, 31, 56, 57, gold)
        ellipse(9, 53, 25, 26, pink); ellipse(66, 53, 25, 26, pink)
        shape(violet) { p in
            p.move(to: CGPoint(x: 37,y: 34)); p.addQuadCurve(to: CGPoint(x: 41,y: 15),control: CGPoint(x: 29,y: 12))
            p.addQuadCurve(to: CGPoint(x: 50,y: 29),control: CGPoint(x: 51,y: 14))
            p.addQuadCurve(to: CGPoint(x: 64,y: 20),control: CGPoint(x: 57,y: 9))
            p.addQuadCurve(to: CGPoint(x: 59,y: 36),control: CGPoint(x: 71,y: 34)); p.closeSubpath()
        }
        eyes(y: 47); polygon([CGPoint(x: 41,y: 64),CGPoint(x: 59,y: 64),CGPoint(x: 50,y: 74)], coral)
        box(32, 84, 14, 6, 3, coral); box(54, 84, 14, 6, 3, coral)
        ellipse(38, 76, 24, 7, cream.opacity(0.65))
    }
    func wave() {
        shape(aqua) { p in
            p.move(to: CGPoint(x: 16,y: 62)); p.addCurve(to: CGPoint(x: 58,y: 27),control1: CGPoint(x: 15,y: 15),control2: CGPoint(x: 40,y: 20))
            p.addCurve(to: CGPoint(x: 84,y: 71),control1: CGPoint(x: 88,y: 23),control2: CGPoint(x: 82,y: 48))
            p.addQuadCurve(to: CGPoint(x: 65,y: 84),control: CGPoint(x: 94,y: 95))
            p.addQuadCurve(to: CGPoint(x: 46,y: 88),control: CGPoint(x: 56,y: 99))
            p.addQuadCurve(to: CGPoint(x: 28,y: 83),control: CGPoint(x: 35,y: 95))
            p.addQuadCurve(to: CGPoint(x: 16,y: 62),control: CGPoint(x: 8,y: 95))
        }
        ellipse(23, 32, 14, 8, cream.opacity(0.55)); eyes(y: 49, apart: 13); cheeks(); smile(y: 68, width: 11)
        ellipse(70, 14, 12, 12, mint); ellipse(21, 13, 7, 7, violet)
    }
    func robot() {
        line(violet, width: 4) { p in p.move(to: CGPoint(x: 50,y: 30)); p.addLine(to: CGPoint(x: 50,y: 17)) }
        polygon([CGPoint(x: 53,y: 6),CGPoint(x: 43,y: 19),CGPoint(x: 51,y: 19),CGPoint(x: 47,y: 29),CGPoint(x: 60,y: 14),CGPoint(x: 52,y: 14)], gold)
        box(11, 48, 13, 22, 5, violet); box(76, 48, 13, 22, 5, violet)
        box(20, 29, 60, 57, 16, coral); box(28, 41, 44, 24, 10, ink)
        box(36, 48, 7, 10, 3, mint); box(57, 48, 7, 10, 3, mint)
        box(39, 72, 22, 7, 3, cream)
        line(coral, width: 2) { p in p.move(to: CGPoint(x: 47,y: 72)); p.addLine(to: CGPoint(x: 47,y: 79)); p.move(to: CGPoint(x: 54,y: 72)); p.addLine(to: CGPoint(x: 54,y: 79)) }
        box(29, 82, 12, 9, 4, violet); box(59, 82, 12, 9, 4, violet)
    }
    func star() {
        var points: [CGPoint] = []
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5 - .pi / 2
            let radius: Double = i.isMultiple(of: 2) ? 43 : 25
            points.append(CGPoint(x: 50 + cos(angle) * radius, y: 53 + sin(angle) * radius))
        }
        polygon(points, gold)
        box(25, 43, 22, 15, 6, ink); box(53, 43, 22, 15, 6, ink)
        line(ink, width: 4) { p in p.move(to: CGPoint(x: 45,y: 48)); p.addLine(to: CGPoint(x: 55,y: 48)) }
        line(violet, width: 3) { p in p.move(to: CGPoint(x: 32,y: 47)); p.addLine(to: CGPoint(x: 38,y: 47)); p.move(to: CGPoint(x: 60,y: 47)); p.addLine(to: CGPoint(x: 66,y: 47)) }
        smile(y: 65, width: 9); ellipse(65, 61, 9, 5, pink)
    }
    func moth() {
        ellipse(8, 25, 38, 43, violet); ellipse(54, 25, 38, 43, violet)
        ellipse(15, 59, 33, 27, pink); ellipse(52, 59, 33, 27, pink)
        ellipse(17, 34, 19, 20, mint); ellipse(64, 34, 19, 20, mint)
        ellipse(23, 40, 7, 8, ink); ellipse(70, 40, 7, 8, ink)
        line(gold, width: 3) { p in
            p.move(to: CGPoint(x: 44,y: 36)); p.addQuadCurve(to: CGPoint(x: 35,y: 17),control: CGPoint(x: 44,y: 17))
            p.move(to: CGPoint(x: 56,y: 36)); p.addQuadCurve(to: CGPoint(x: 65,y: 17),control: CGPoint(x: 56,y: 17))
        }
        ellipse(32, 14, 6, 6, gold); ellipse(62, 14, 6, 6, gold)
        ellipse(37, 43, 26, 43, cream); ellipse(34, 32, 32, 29, cream)
        eyes(y: 42, apart: 7); smile(y: 60, width: 4)
        line(gold, width: 3) { p in p.move(to: CGPoint(x: 43,y: 73)); p.addLine(to: CGPoint(x: 57,y: 73)) }
    }
}
