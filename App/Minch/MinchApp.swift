import SwiftUI
import MinchUI

@main
struct MinchApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Minch") {
            ContentView(model: model)
                .frame(minWidth: 960, minHeight: 600)
                .modelContainer(model.container)
                .onOpenURL { url in
                    Task { await model.ingestExternalMagnet(url.absoluteString) }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 740)

        MenuBarExtra("Minch", systemImage: "bolt.fill") {
            MenuBarView(model: model)
                .modelContainer(model.container)
        }
        .menuBarExtraStyle(.window)
    }
}
