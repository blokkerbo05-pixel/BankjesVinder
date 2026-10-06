import SwiftUI

/// Swipebare galerij met de foto's van een bankje. Laat niets zien als er geen foto's zijn.
struct FotoGalerij: View {
    @EnvironmentObject var fotos: FotoStore
    @EnvironmentObject var account: AccountStore
    let bench: Bench
    /// Hoogte van de galerij; `nil` = vul de ruimte die er is.
    let hoogte: CGFloat?

    @State private var pagina = 0
    @State private var gekozen: BenchFoto?
    @State private var vraagVerwijderen = false
    @State private var vraagMelden = false

    var body: some View {
        let items = fotos.items(voor: bench)
        if !items.isEmpty {
            let huidig = min(pagina, items.count - 1)
            ZStack(alignment: .topTrailing) {
                if items.count > 1 {
                    TabView(selection: $pagina) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            FotoPagina(item: item).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                } else {
                    FotoPagina(item: items[0])
                }
                if account.isIngelogd, case .online(let foto) = items[huidig] {
                    menu(voor: foto)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: hoogte)
            .clipShape(RoundedRectangle(cornerRadius: KaartStijl.hoekKlein))
            .confirmationDialog("Foto verwijderen?", isPresented: $vraagVerwijderen, titleVisibility: .visible) {
                Button("Verwijder foto", role: .destructive) {
                    if let foto = gekozen { Task { await fotos.verwijder(foto) } }
                }
                Button("Annuleren", role: .cancel) {}
            }
            .confirmationDialog("Deze foto melden?", isPresented: $vraagMelden, titleVisibility: .visible) {
                Button("Meld deze foto", role: .destructive) {
                    if let foto = gekozen { Task { await fotos.meld(foto) } }
                }
                Button("Annuleren", role: .cancel) {}
            } message: {
                Text("De foto wordt direct verborgen tot hij is bekeken.")
            }
        }
    }

    private func menu(voor foto: BenchFoto) -> some View {
        Menu {
            if foto.userID == account.userID {
                Button("Verwijder foto", systemImage: "trash", role: .destructive) {
                    gekozen = foto
                    vraagVerwijderen = true
                }
            } else {
                Button("Meld deze foto", systemImage: "flag", role: .destructive) {
                    gekozen = foto
                    vraagMelden = true
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: KaartStijl.fotoMenuKnopGrootte, height: KaartStijl.fotoMenuKnopGrootte)
                .zwevendeAchtergrond(Circle())
        }
        .padding(8)
        .accessibilityLabel("Foto-opties")
    }
}

/// Eén foto in de galerij.
private struct FotoPagina: View {
    let item: GalerijItem
    @State private var beeld: UIImage?

    var body: some View {
        ZStack {
            KaartStijl.keurAfbeeldingPlaceholder
            if let beeld {
                Image(uiImage: beeld)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: item.id) { beeld = await FotoCache.shared.afbeelding(voor: item) }
    }
}
