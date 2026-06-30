import SwiftUI

/// Fixed-height title row so every screen's title sits at the same Y regardless of a trailing
/// button (Android: Box height 48, top padding 12, title CenterStart, trailing CenterEnd).
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        ZStack {
            HStack {
                Text(title).font(BzFont.headlineLarge).foregroundStyle(BzColor.onSurface)
                Spacer(minLength: 0)
            }
            HStack {
                Spacer(minLength: 0)
                trailing()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .padding(.top, 12)
    }
}
