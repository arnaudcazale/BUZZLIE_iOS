import SwiftUI

struct EmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundStyle(BzColor.onSurfaceVariant.opacity(0.4))
            Text("Aucun rappel")
                .font(BzFont.titleLarge).foregroundStyle(BzColor.onSurface)
            Text("Programmez un rappel pour faire vibrer le bracelet à l'heure voulue.")
                .font(BzFont.bodyMedium)
                .foregroundStyle(BzColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Button(action: onAdd) {
                Text("Ajouter un rappel").font(BzFont.labelLarge)
            }
            .buttonStyle(.borderedProminent)
            .tint(BzColor.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }
}
