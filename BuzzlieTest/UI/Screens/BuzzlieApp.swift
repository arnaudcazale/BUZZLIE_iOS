import SwiftUI
import UIKit

private enum Tab: Hashable { case rappels, bracelet, debug }

private enum EditorTarget: Identifiable {
    case new
    case edit(String)
    var id: String { switch self { case .new: return "new"; case .edit(let i): return i } }
}

struct BuzzlieApp: View {
    @ObservedObject var vm: BuzzlieViewModel
    @State private var tab: Tab = .rappels
    @State private var connectOpen = false
    @State private var editorFor: EditorTarget?

    init(vm: BuzzlieViewModel) {
        self.vm = vm
        // Avec 2 onglets, UITabBar les etale aux extremites (25 %/75 %) :
        // items resserres vers le centre, comme la NavigationBar Android
        // (fillMaxWidth(0.62f) centree).
        UITabBar.appearance().itemPositioning = .centered
        UITabBar.appearance().itemWidth = 120
        UITabBar.appearance().itemSpacing = 24
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                RappelsScreen(
                    vm: vm,
                    onAddReminder: { editorFor = .new },
                    onEditReminder: { editorFor = .edit($0) },
                    onConnect: { connectOpen = true }
                )
            }
            .tabItem { Label("Rappels", systemImage: "bell") }
            .tag(Tab.rappels)

            NavigationStack {
                BraceletScreen(vm: vm, onConnect: { connectOpen = true })
            }
            .tabItem { Label("Bracelet", systemImage: "applewatch") }
            .tag(Tab.bracelet)

            // Onglet Debug masqué par défaut (même en build Debug), comme Android
            // (flag SHOW_DEBUG_TAB). Pour le réactiver : ajouter SHOW_DEBUG_TAB aux
            // Active Compilation Conditions de la cible dans Xcode.
            #if SHOW_DEBUG_TAB
            NavigationStack {
                DebugScreen(vm: vm, onConnect: { connectOpen = true })
            }
            .tabItem { Label("Debug", systemImage: "ladybug") }
            .tag(Tab.debug)
            #endif
        }
        .tint(BzColor.primary)
        .onChange(of: vm.connState) { _, newValue in
            if newValue == .ready { connectOpen = false }
        }
        .sheet(isPresented: $connectOpen, onDismiss: { vm.stopScan() }) {
            ConnectSheet(vm: vm)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editorFor) { target in
            ReminderEditorSheet(
                vm: vm,
                reminderId: { if case .edit(let id) = target { return id } else { return nil } }(),
                onDismiss: { editorFor = nil }
            )
            .presentationDetents([.large])
        }
    }
}
