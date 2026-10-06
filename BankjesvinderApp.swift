import SwiftUI

@main
struct BankjesvinderApp: App {
    @StateObject private var store = BenchStore()
    @StateObject private var location = LocationManager()
    @StateObject private var keur = KeurStore()
    @StateObject private var thema = ThemaStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(location)
                .environmentObject(keur)
                .environmentObject(thema)
                .tint(Color.leaf)
                .preferredColorScheme(thema.weergave.colorScheme)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var keur: KeurStore
    @EnvironmentObject var thema: ThemaStore
    @StateObject private var verrassing = VerrassingStatus()
    @State private var tab = 0
    @State private var kaartGeheugen = KaartGeheugen()

    var body: some View {
        TabView(selection: $tab) {
            MapScreen(geheugen: kaartGeheugen)
                .tabItem { Label("Kaart", systemImage: "map") }
                .tag(0)
            ListScreen()
                .tabItem { Label("Bankjes", systemImage: "list.bullet") }
                .tag(1)
            KeurScherm()
                .tabItem { Label("Keuren", systemImage: "hand.thumbsup") }
                .tag(2)
            InstellingenScherm()
                .tabItem { Label("Instellingen", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Color.leaf)
        // Bij een ander thema worden de schermen één keer opnieuw opgebouwd, zodat alle kleuren meegaan.
        .id(thema.themaID)
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
