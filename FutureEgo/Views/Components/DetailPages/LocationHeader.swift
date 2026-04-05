import SwiftUI

// MARK: - LocationHeader
//
// Header block used by every activity detail page. Shows the activity
// title (24pt semibold) with an optional location / metadata subtitle
// directly under it in muted gray-green, prefixed with a `location.fill`
// glyph when `showMapIcon` is true.
//
// Layout:
//   - `VStack(alignment: .leading)` so multi-line titles stay flush left
//   - horizontal padding 24, vertical padding 16 (matches the spec; the
//     enclosing `ActivityPageScaffold` will additionally provide its own
//     horizontal padding, but callers frequently drop the header outside
//     the scaffold, so we bake it in here too)
//
// Spec: `/home/jun/.pm/2026-04-06/task-2/spec.md`.

struct LocationHeader: View {
    let title: String
    var subtitle: String? = nil
    var showMapIcon: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.pageTitle)
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, !subtitle.isEmpty {
                HStack(spacing: 4) {
                    if showMapIcon {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.mutedTextGreen)
                    }
                    Text(subtitle)
                        .font(.captionRegular)
                        .foregroundColor(.mutedTextGreen)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Preview

#Preview("LocationHeader") {
    VStack(alignment: .leading, spacing: 12) {
        LocationHeader(
            title: "和客户开会",
            subtitle: "上海中心大厦 · 陆家嘴"
        )

        Divider()

        LocationHeader(
            title: "专注写周报",
            subtitle: nil
        )

        Divider()

        LocationHeader(
            title: "跑步",
            subtitle: "徐汇滨江",
            showMapIcon: false
        )
    }
}
