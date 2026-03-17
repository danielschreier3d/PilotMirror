import SwiftUI

struct SplashView: View {
    var onComplete: () -> Void

    @State private var fadeOut = false

    private let bg     = Color(hex: "0A1628")
    private let accent = Color(hex: "4A9EF8")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.45), radius: 24)

                Text("PilotMirror")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    fadeOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}
