import SwiftUI

@main
struct DerDieDasApp: App {
    @StateObject private var wordStore = WordStore()

    var body: some Scene {
        WindowGroup {
            ContentView(wordStore: wordStore)
                .preferredColorScheme(.light)
        }
    }
}
