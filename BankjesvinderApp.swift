import SwiftUI

@main
struct BankjesvinderApp: App {
    @StateObject private var store = BenchStore()
    @StateObject private var location = LocationManager()
    @StateObject private var keur = KeurStore()
    @StateObject private var thema = ThemaStore()
    @StateObject private var favorieten = FavorietenStore()
    @StateObject private var account = AccountStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(location)
                .environmentObject(keur)
                .environmentObject(thema)
                .environmentObject(favorieten)
                .environmentObject(account)
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
    @EnvironmentObject var account: AccountStore
    @StateObject private var verrassing = VerrassingStatus()
    @State private var tab = 0
    @State private var kaartGeheugen = KaartGeheugen()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("welkomGezien") private var welkomGezien = false

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
        .sheet(isPresented: $account.toonLogin) { LoginScherm().environmentObject(account) }
        .alert("Even geduld", isPresented: Binding(get: { account.melding != nil }, set: { if !$0 { account.melding = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(account.melding ?? "")
        }
        .overlay {
            if !welkomGezien {
                WelkomScherm { open in
                    store.toonAlle = open
                    withAnimation(Animaties.fade) { welkomGezien = true }
                }
                .transition(.opacity)
            }
        }
        .overlay { VerrassingOverlay(status: verrassing) }
        .onAppear {
            location.start()
            // De eindbeoordeling heeft het hele bankje nodig, niet alleen zijn ID.
            store.account = account
            keur.account = account
        }
        .onReceive(account.$gebruiker) {
            store.accountGewijzigd($0?.id)
            keur.accountGewijzigd($0?.id)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await store.ververs() }
                Task { await keur.ververs() }
            }
        }
        .onReceive(location.$location) { newLocation in
            // Zodra we weten waar je bent: één keer de bankjes rond jou ophalen.
            guard let newLocation, store.toonAlle, !store.didAutoLoad else { return }
            store.didAutoLoad = true
            store.loadTiles(around: newLocation.coordinate)
        }
    }
}
