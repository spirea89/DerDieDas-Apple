import SwiftUI

enum AppTheme {
    static let ink = Color(red: 0x14 / 255, green: 0x2A / 255, blue: 0x36 / 255)
    static let muted = Color(red: 0x5B / 255, green: 0x70 / 255, blue: 0x7C / 255)
    static let line = Color(red: 0xC9 / 255, green: 0xD8 / 255, blue: 0xDE / 255)
    static let skyTop = Color(red: 0xD7 / 255, green: 0xEE / 255, blue: 0xF7 / 255)
    static let skyBottom = Color(red: 0xEE / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
    static let surface = Color.white.opacity(0.88)
    static let accent = Color(red: 0x17 / 255, green: 0x85 / 255, blue: 0x6B / 255)
    static let accentStrong = Color(red: 0x0F / 255, green: 0x65 / 255, blue: 0x52 / 255)
    static let der = Color(red: 0x1F / 255, green: 0x6F / 255, blue: 0xBF / 255)
    static let die = Color(red: 0xC4 / 255, green: 0x3B / 255, blue: 0x5B / 255)
    static let das = Color(red: 0xD9 / 255, green: 0x8E / 255, blue: 0x1A / 255)
    static let success = Color(red: 0x1F / 255, green: 0x9D / 255, blue: 0x55 / 255)
    static let danger = Color(red: 0xC9 / 255, green: 0x3C / 255, blue: 0x37 / 255)
    static let gold = Color(red: 0xE8 / 255, green: 0xB8 / 255, blue: 0x3A / 255)

    static func articleColor(_ article: Article) -> Color {
        switch article {
        case .der: return der
        case .die: return die
        case .das: return das
        }
    }

    static let brandFont = Font.custom("AvenirNext-Heavy", size: 28)
    static let displayFont = Font.custom("AvenirNext-Bold", size: 42)
    static let titleFont = Font.custom("AvenirNext-DemiBold", size: 22)
    static let bodyFont = Font.custom("AvenirNext-Medium", size: 17)
    static let captionFont = Font.custom("AvenirNext-DemiBold", size: 13)
}

struct PrimaryButtonStyle: ButtonStyle {
    var disabled = false
    var color: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.titleFont)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(disabled ? AppTheme.muted : (configuration.isPressed ? AppTheme.accentStrong : color))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed && !disabled ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.captionFont)
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(configuration.isPressed ? AppTheme.line.opacity(0.7) : AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.captionFont)
            .foregroundStyle(AppTheme.muted)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(configuration.isPressed ? AppTheme.line.opacity(0.45) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
