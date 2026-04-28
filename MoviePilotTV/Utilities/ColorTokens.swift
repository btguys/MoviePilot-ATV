import SwiftUI

/// Semantic color tokens for consistent coloring across the app.
enum ColorTokens {
    // MARK: - Backgrounds

    static let appBackground: Color = .black

    /// Default card / row surface (white 5%)
    static let surfaceCard: Color = .white.opacity(0.05)

    /// Subtle hover surface (white 8%)
    static let surfaceHover: Color = .white.opacity(0.08)

    /// Focused surface (white 12%)
    static let surfaceFocused: Color = .white.opacity(0.12)

    // MARK: - Text

    static let textPrimary: Color = .white
    static let textSecondary: Color = .white.opacity(0.7)
    static let textMuted: Color = .gray
    static let textDim: Color = .white.opacity(0.5)

    // MARK: - Semantic

    static let accent: Color = .blue
    static let success: Color = .green
    static let warning: Color = .orange
    static let danger: Color = .red
    static let info: Color = .cyan

    // MARK: - Dividers

    static let divider: Color = .white.opacity(0.2)

    // MARK: - Focus

    static let focusBorder: Color = .blue
    static let focusGlow: Color = .blue.opacity(0.6)
    static let focusCardGlow: Color = .white.opacity(0.35)

    // MARK: - Tag backgrounds

    static let tagBlue: Color = .blue.opacity(0.3)
    static let tagGreen: Color = .green.opacity(0.35)
    static let tagPurple: Color = .purple.opacity(0.3)

    // MARK: - Progress

    static let progressTrack: Color = .white.opacity(0.1)
}
