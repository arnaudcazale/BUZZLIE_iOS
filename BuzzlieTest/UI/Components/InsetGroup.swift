import SwiftUI

/// iOS "inset grouped" section: optional caption header + rounded card + optional footer note.
struct InsetGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(BzFont.labelSmall)
                    .foregroundStyle(BzColor.onSurfaceVariant)
                    .padding(.leading, BzSpacing.cardInset)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BzColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: BzRadius.large, style: .continuous))
            if let footer {
                Text(footer)
                    .font(BzFont.bodySmall)
                    .foregroundStyle(BzColor.onSurfaceVariant)
                    .padding(.horizontal, BzSpacing.cardInset)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Thin inset divider between rows (left-padded under the row text).
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(BzColor.outline)
            .frame(height: 0.5)
            .padding(.leading, BzSpacing.cardInset)
    }
}

/// A tappable settings row with leading icon box, title, optional value/trailing.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var icon: String? = nil
    var iconTint: Color = BzColor.primary
    var value: String? = nil
    var enabled: Bool = true
    var onClick: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, icon: String? = nil, iconTint: Color = BzColor.primary,
         value: String? = nil, enabled: Bool = true, onClick: (() -> Void)? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.icon = icon
        self.iconTint = iconTint
        self.value = value
        self.enabled = enabled
        self.onClick = onClick
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(enabled ? iconTint : BzColor.onSurfaceVariant)
                    .frame(width: BzSpacing.iconBox, height: BzSpacing.iconBox)
            }
            Text(title)
                .font(BzFont.bodyLarge)
                .foregroundStyle(enabled ? BzColor.onSurface : BzColor.onSurfaceVariant)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value).font(BzFont.bodyMedium).foregroundStyle(BzColor.onSurfaceVariant)
            }
            trailing()
        }
        .padding(.horizontal, BzSpacing.cardInset)
        .padding(.vertical, 10)
        .frame(minHeight: BzSpacing.rowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { if let onClick, enabled { onClick() } }
    }
}
