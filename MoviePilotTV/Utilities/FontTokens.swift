import SwiftUI

/// Semantic font tokens for consistent typography across the app.
enum FontTokens {
    /// Page titles — all tab pages (44pt bold)
    static let pageTitle: Font = .system(size: 44, weight: .bold)

    /// Section headers within pages (34pt bold)
    static let sectionTitle: Font = .system(size: 34, weight: .bold)

    /// Hero / detail screen main title (42pt bold)
    static let heroTitle: Font = .system(size: 42, weight: .bold)

    /// Card item titles in grids/rows (23pt medium)
    static let cardTitle: Font = .system(size: 23, weight: .medium)

    /// Card item subtitles — year, meta (18pt regular)
    static let cardSubtitle: Font = .system(size: 18, weight: .regular)

    /// Detail screen body text (26pt regular)
    static let detailBody: Font = .system(size: 26, weight: .regular)

    /// Primary button labels (22pt semibold)
    static let buttonText: Font = .system(size: 22, weight: .semibold)

    /// Small button labels (20pt semibold)
    static let buttonSmall: Font = .system(size: 20, weight: .semibold)

    /// Cast / crew member names (20pt semibold)
    static let castName: Font = .system(size: 20, weight: .semibold)

    /// Cast character / role names (18pt regular)
    static let castCharacter: Font = .system(size: 18, weight: .regular)

    /// System status card labels (16pt regular)
    static let systemLabel: Font = .system(size: 16, weight: .regular)

    /// System status card values (18pt semibold)
    static let systemValue: Font = .system(size: 18, weight: .semibold)

    /// Settings section headers (30pt bold)
    static let settingsSectionTitle: Font = .system(size: 30, weight: .bold)

    /// Settings field values (20pt regular)
    static let settingsValue: Font = .system(size: 20, weight: .regular)

    /// Small helper text / captions (18pt regular)
    static let caption: Font = .system(size: 18, weight: .regular)

    /// Section subtitle / description (18pt regular)
    static let sectionSubtitle: Font = .system(size: 18, weight: .regular)
}
