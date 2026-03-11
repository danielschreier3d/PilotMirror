import SwiftUI

/// Simple radar/spider chart for trait visualization.
struct TraitRadarChart: View {
    let traits: [(label: String, value: Double)]  // value 0.0–1.0
    var color: Color = Color(hex: "4A9EF8")

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 24
            let count = traits.count
            let angleStep = 2 * Double.pi / Double(count)

            ZStack {
                // Grid circles
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                    radarPolygon(sides: count, radius: radius * fraction, center: center, filled: false)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }

                // Filled area
                radarShape(values: traits.map(\.value), radius: radius, center: center)
                    .fill(color.opacity(0.25))

                radarShape(values: traits.map(\.value), radius: radius, center: center)
                    .stroke(color, lineWidth: 2)

                // Dots
                ForEach(traits.indices, id: \.self) { i in
                    let angle = Double(i) * angleStep - Double.pi / 2
                    let r = radius * traits[i].value
                    let pt = CGPoint(
                        x: center.x + r * cos(angle),
                        y: center.y + r * sin(angle)
                    )
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .position(pt)
                }

                // Labels
                ForEach(traits.indices, id: \.self) { i in
                    let angle = Double(i) * angleStep - Double.pi / 2
                    let labelR = radius + 18.0
                    let pt = CGPoint(
                        x: center.x + labelR * cos(angle),
                        y: center.y + labelR * sin(angle)
                    )
                    Text(traits[i].label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .position(pt)
                }
            }
        }
    }

    private func radarShape(values: [Double], radius: CGFloat, center: CGPoint) -> Path {
        let count = values.count
        let angleStep = 2 * Double.pi / Double(count)
        var path = Path()
        for i in 0..<count {
            let angle = Double(i) * angleStep - Double.pi / 2
            let r = radius * CGFloat(values[i])
            let pt = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func radarPolygon(sides: Int, radius: CGFloat, center: CGPoint, filled: Bool) -> Path {
        let angleStep = 2 * Double.pi / Double(sides)
        var path = Path()
        for i in 0..<sides {
            let angle = Double(i) * angleStep - Double.pi / 2
            let pt = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color(hex: "0A1628").ignoresSafeArea()
        TraitRadarChart(traits: [
            ("Teamwork", 0.8),
            ("Stress", 0.6),
            ("Responsibility", 0.9),
            ("Communication", 0.7),
            ("Reliability", 0.85),
        ])
        .frame(width: 280, height: 280)
        .padding()
    }
}
