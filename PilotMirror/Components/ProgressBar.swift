import SwiftUI

struct PilotProgressBar: View {
    let value: Double       // 0.0 – 1.0
    var color: Color = Color(hex: "4A9EF8")
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.white.opacity(0.1))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(value, 1.0)), height: height)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    ZStack {
        Color(hex: "0A1628").ignoresSafeArea()
        VStack(spacing: 20) {
            PilotProgressBar(value: 0.3)
            PilotProgressBar(value: 0.7, color: Color(hex: "34C759"))
            PilotProgressBar(value: 1.0, color: Color(hex: "FF9F0A"), height: 12)
        }
        .padding()
    }
}
