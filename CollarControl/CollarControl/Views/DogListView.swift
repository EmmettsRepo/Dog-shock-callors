import SwiftUI

/// Main screen showing all dogs with quick-action buttons.
struct DogListView: View {
    @ObservedObject var dogStore: DogStore
    @ObservedObject var bleManager: BLEManager
    @State private var showingAddDog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(dogStore.dogs) { dog in
                        NavigationLink(value: dog) {
                            DogCard(dog: dog, isConnected: bleManager.connectionState == .connected)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("My Dogs")
            .navigationDestination(for: Dog.self) { dog in
                DogControlView(dog: dog, bleManager: bleManager, dogStore: dogStore)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionStatusView(bleManager: bleManager)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddDog = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDog) {
                AddDogView(dogStore: dogStore)
            }
        }
    }
}

/// A card representing a dog in the grid.
struct DogCard: View {
    let dog: Dog
    let isConnected: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(dog.color.gradient)
                    .frame(width: 64, height: 64)
                Text(String(dog.name.prefix(1)).uppercased())
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }

            Text(dog.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Collar \(dog.collarID)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(dog.color.opacity(0.3), lineWidth: 1)
        )
    }
}
