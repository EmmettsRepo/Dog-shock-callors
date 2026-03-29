import SwiftUI

@main
struct CollarControlApp: App {
    @StateObject private var bleManager = BLEManager.shared
    @StateObject private var dogStore = DogStore.shared

    var body: some Scene {
        WindowGroup {
            DogListView(dogStore: dogStore, bleManager: bleManager)
                .onAppear {
                    bleManager.connectAllPairedCollars(dogs: dogStore.dogs)
                }
        }
    }
}
