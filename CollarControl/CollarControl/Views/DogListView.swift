import SwiftUI

/// Main screen showing all dogs with per-dog connection status.
struct DogListView: View {
    @ObservedObject var dogStore: DogStore
    @ObservedObject var bleManager: BLEManager
    @State private var showingAddDog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if dogStore.dogs.isEmpty {
                    ContentUnavailableView {
                        Label("No Dogs", systemImage: "dog")
                    } description: {
                        Text("Add your first dog and pair their BLE collar.")
                    } actions: {
                        Button("Add Dog") { showingAddDog = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(dogStore.dogs) { dog in
                            NavigationLink(value: dog) {
                                DogCard(
                                    dog: dog,
                                    connectionState: bleManager.connectionState(for: dog.peripheralUUID)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Dogs")
            .navigationDestination(for: Dog.self) { dog in
                DogControlView(dog: dog, bleManager: bleManager, dogStore: dogStore)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionSummaryView(collarStates: bleManager.collarStates)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddDog = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDog) {
                AddDogView(dogStore: dogStore, bleManager: bleManager)
            }
            .onAppear {
                bleManager.connectAllPairedCollars(dogs: dogStore.dogs)
            }
        }
    }
}

/// A card representing a dog in the grid with connection indicator.
struct DogCard: View {
    let dog: Dog
    let connectionState: CollarConnectionState

    var body: some View {
        VStack(spacing: 10) {
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

            if dog.isPaired {
                CollarStatusBadge(state: connectionState)
            } else {
                Text("Not paired")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
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
