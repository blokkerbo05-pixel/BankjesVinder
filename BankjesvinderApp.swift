import SwiftUI

@main
struct BankjesvinderApp: App {
    @StateObject private var store = BenchStore()
    @StateObject private var location = LocationManager()
    @StateObject private var keur = KeurStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(location)
                .environmentObject(keur)
                .tint(Color.leaf)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var keur: KeurStore
    @StateObject private var verrassing = VerrassingStatus()

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("Kaart", systemImage: "map") }
            ListScreen()
                .tabItem { Label("Bankjes", systemImage: "list.bullet") }
            KeurScherm()
                .tabItem { Label("Keuren", systemImage: "hand.thumbsup") }
        }
        .environmentObject(verrassing)
        .overlay { VerrassingOverlay(status: verrassing) }
        .onAppear {
            location.start()
            // De eindbeoordeling heeft het hele bankje nodig, niet alleen zijn ID.
            keur.zoekBankje = { id in store.all.first { $0.id == id } }
        }
        .onReceive(location.$location) { newLocation in
            // Zodra we weten waar je bent: één keer de bankjes rond jou ophalen.
            guard let newLocation, !store.didAutoLoad else { return }
            store.didAutoLoad = true
            store.loadTiles(around: newLocation.coordinate)
        }
    }
}
