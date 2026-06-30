import SwiftUI

@main
struct BuzzlieTestApp: App {
    @StateObject private var vm = BuzzlieViewModel()

    var body: some Scene {
        WindowGroup {
            BuzzlieApp(vm: vm)
                .environment(\.colorScheme, .light)
        }
    }
}
