import SwiftUI

// MARK: - DetailPagePalette
//
// Drives the per-activity brand color used in the redesigned detail
// pages (Wave 0+). Each palette case resolves to a single `primary`
// color that is reused across the Hero card background, content card
// 1px stroke, giant time text, activity name text, floating "AI Coach"
// label, and the TabBar "此刻" active tint.
//
// Values come directly from
// `/home/jun/future_ego/.pm/2026-04-06/ground-truth.md` §3 "品牌色集合"
// and §"关键结构决策候选 #3 品牌色映射".
//
//  - green  (#38B000) → exercising
//  - blue   (#3986FE) → outing
//  - orange (#F85509) → eating (delivery / cook / eatOut)
//  - purple (#B239EA) → concentrating
//
// NOTE: `eating-outside` (EatOutDetail) uses orange even though the
// Figma source renders the activity-name label in blue. That is a known
// Figma bug confirmed at the 2026-04-06 Phase 2b gate; the iOS
// implementation uses orange for every brand-color touchpoint on the
// eating pages.

enum DetailPagePalette {
    case green    // exercising
    case blue     // outing
    case orange   // eating (delivery / cook / eatOut)
    case purple   // concentrating

    /// The single source-of-truth tint for this palette. Used by Hero
    /// card fill, content card stroke, giant time, activity name,
    /// "AI Coach" floating label, and TabBar "此刻" active tint.
    var primary: Color {
        switch self {
        case .green:
            return Color(red: 0x38 / 255.0, green: 0xB0 / 255.0, blue: 0x00 / 255.0)
        case .blue:
            return Color(red: 0x39 / 255.0, green: 0x86 / 255.0, blue: 0xFE / 255.0)
        case .orange:
            return Color(red: 0xF8 / 255.0, green: 0x55 / 255.0, blue: 0x09 / 255.0)
        case .purple:
            return Color(red: 0xB2 / 255.0, green: 0x39 / 255.0, blue: 0xEA / 255.0)
        }
    }
    var light: Color {
        switch self{
        case .green:
            return Color(red: 0x6E / 255.0,green: 0xC6 / 255.0,blue:0x45 / 255.0)
        case .blue:
            return Color(red: 0x87 / 255.0, green: 0xB6 / 255.0, blue: 0x48 / 255.0)
        case .orange:
            return Color(red:0xFF / 255.0, green:0x82 / 255.0,blue:0x48 / 255.0)
        case .purple:
            return Color(red:0xCA / 255.0,green:0x72 / 255.0,blue: 0xF2 / 255.0)
        }
    }
}
