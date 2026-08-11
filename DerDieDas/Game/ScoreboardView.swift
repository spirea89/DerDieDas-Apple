import SwiftUI

struct ScoreboardView: View {
    let players: [Player]
    let currentPlayerID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ranked) { player in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name)
                            .font(AppTheme.captionFont.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        Text("\(player.score)")
                            .font(AppTheme.titleFont)
                            .foregroundStyle(player.id == currentPlayerID ? AppTheme.accentStrong : AppTheme.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(player.id == currentPlayerID ? AppTheme.gold.opacity(0.28) : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(player.id == currentPlayerID ? AppTheme.gold : AppTheme.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var ranked: [Player] {
        players.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }
}
