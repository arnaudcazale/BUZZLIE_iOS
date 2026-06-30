import SwiftUI

/// Shared banner recipe (ImportedBanner / SyncStatusBanner): 16pt corner, tint at 10% alpha
/// background, 18pt icon in a 20pt box, 12/10 padding, 10pt gap, optional trailing close.
struct Banner: View {
    let icon: String
    let tint: Color
    let text: String
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
            Text(text)
                .font(BzFont.bodyMedium)
                .foregroundStyle(BzColor.onSurface)
            Spacer(minLength: 0)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundStyle(BzColor.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BzRadius.medium, style: .continuous))
    }
}
