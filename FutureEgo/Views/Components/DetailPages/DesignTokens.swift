import SwiftUI

// MARK: - Design Tokens
//
// Shared color + font tokens for the redesigned activity detail pages
// (Wave 1 / task #2). These replace the ad-hoc `Color(hex: "…")` and
// `.system(size:…)` call sites scattered across the old card views.
//
// Token values come straight from the Figma source and the global
// taskboard (`/home/jun/.pm/2026-04-06/taskboard.md`). Do NOT fold the
// old `#34C759` call sites into `brandGreen` yet — that global replace
// is scheduled for Wave 4.
//
// The `Color(hex:)` initializer these tokens rely on is defined in
// `FutureEgo/Models/EventTypes.swift` and is intentionally not redeclared
// here.

// MARK: - Color tokens

extension Color {
    /// Brand primary green `#38B000`. Replaces the legacy `#34C759`
    /// accent in Wave 4; new detail-page components should use this.
    static let brandGreen = Color(hex: "38B000")

    /// Subtle surface fill `#EDF4F4` used for the inspiration quote
    /// block and menu-item style rows.
    static let surfaceSubtle = Color(hex: "EDF4F4")

    /// Divider / hairline color `#D9D9D9`, also used as the unchecked
    /// checkbox stroke.
    static let divider = Color(hex: "D9D9D9")

    /// Muted gray-green text `rgba(78, 94, 73, 0.56)` used for location
    /// labels and secondary metadata under page titles.
    static let mutedTextGreen = Color(
        .sRGB,
        red: 78.0 / 255.0,
        green: 94.0 / 255.0,
        blue: 73.0 / 255.0,
        opacity: 0.56
    )
}

// MARK: - Font tokens
//
// All sizes map to SF Pro / SF Pro Display. Figma "weight 590" is the
// Apple system semibold, so we use `.semibold` here.

extension Font {
    /// 24 pt semibold — page-level title (e.g. activity name at the top
    /// of a detail page).
    static let pageTitle = Font.system(size: 24, weight: .semibold)

    /// 19 pt semibold — in-page section headings.
    static let sectionTitle = Font.system(size: 19, weight: .semibold)

    /// 17 pt semibold — emphasized body text (primary list row title).
    static let bodyEmphasis = Font.system(size: 17, weight: .semibold)

    /// 17 pt regular — default body text.
    static let bodyRegular = Font.system(size: 17, weight: .regular)

    /// 15 pt regular — caption / metadata text.
    ///
    /// NOTE: named `captionRegular` rather than `caption` because
    /// `Font.caption` already exists in SwiftUI (dynamic-type caption,
    /// ~12pt) and shadowing it would both fail to compile and silently
    /// break anywhere the system value was expected. The spec uses the
    /// bare name `caption`; call sites in this codebase use
    /// `.captionRegular`.
    static let captionRegular = Font.system(size: 15, weight: .regular)
}

// MARK: - Preview
//
// Visual smoke-test for every token so later waves can eyeball them in
// Xcode previews.

#Preview("Design tokens") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Colors")
                    .font(.sectionTitle)

                swatch("brandGreen", .brandGreen)
                swatch("surfaceSubtle", .surfaceSubtle)
                swatch("divider", .divider)
                swatch("mutedTextGreen", .mutedTextGreen)
            }

            Divider()

            Group {
                Text("Fonts")
                    .font(.sectionTitle)

                Text("pageTitle · 24 semibold").font(.pageTitle)
                Text("sectionTitle · 19 semibold").font(.sectionTitle)
                Text("bodyEmphasis · 17 semibold").font(.bodyEmphasis)
                Text("bodyRegular · 17 regular").font(.bodyRegular)
                Text("captionRegular · 15 regular").font(.captionRegular)
            }
        }
        .padding(24)
    }
}

@ViewBuilder
private func swatch(_ name: String, _ color: Color) -> some View {
    HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 48, height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        Text(name).font(.bodyRegular)
    }
}
