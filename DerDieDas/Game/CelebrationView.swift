import SwiftUI

struct CelebrationView: View {
    let winners: [Player]
    let onClose: () -> Void

    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🏆")
                    .font(.system(size: 64))
                    .scaleEffect(burst ? 1.12 : 0.86)
                    .rotationEffect(.degrees(burst ? 8 : -8))

                Text(title)
                    .font(AppTheme.brandFont)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)

                ForEach(winners) { winner in
                    Text("\(winner.name) · \(winner.score) pts")
                        .font(AppTheme.bodyFont.weight(.bold))
                        .foregroundStyle(AppTheme.accentStrong)
                }

                Button("Play again", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(AppTheme.skyBottom)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.18), radius: 24, y: 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45).repeatForever(autoreverses: true)) {
                burst = true
            }
        }
    }

    private var title: String {
        if winners.count > 1 {
            return "It's a tie!"
        }
        return "Winner!"
    }
}
