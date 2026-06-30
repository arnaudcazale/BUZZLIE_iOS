import SwiftUI

/// Shared screen container: vertical scroll, 20pt horizontal padding, 16pt stack spacing,
/// background fill (mirrors the Android `Column.verticalScroll().padding(screenH)`).
struct ScreenScaffold<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BzSpacing.stack) {
                content()
            }
            .padding(.horizontal, BzSpacing.screenH)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BzColor.background)
        .scrollDismissesKeyboard(.interactively)
    }
}
