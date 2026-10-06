import SwiftUI
import CoreLocation

/// De lijst: ziet eruit zoals de web-versie (titel, zoeken, filters, kaartjes).
struct ListScreen: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager

    @State private var query = ""
    @State private var sort: SortMode = .nearby
    @State private var activeTags: Set<String> = []
    @State private var showAdd = false

    enum SortMode: String, CaseIterable, Identifiable {
        case nearby = "Dichtstbij"
        case newest = "Nieuwste"
        case rating = "Beste eerst"
        case az = "A–Z"
        var id: String { rawValue }
    }

    private var rows: [Bench] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = store.all.filter { bench in
            if !q.isEmpty && !"\(bench.name) \(bench.place) \(bench.note)".lowercased().contains(q) { return false }
            return activeTags.allSatisfy { bench.tags.contains($0) }
        }
        let here = location.location
        switch sort {
        case .nearby:
            return filtered.sorted { ($0.distance(from: here) ?? .infinity) < ($1.distance(from: here) ?? .infinity) }
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .rating:
            return filtered.sorted { $0.rating > $1.rating }
        case .az:
            return filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchRow
                    FlowLayout(spacing: 8) {
                        ForEach(BenchTags.all, id: \.self) { tag in
                            Chip(title: tag, isOn: activeTags.contains(tag)) {
                                if activeTags.contains(tag) { activeTags.remove(tag) } else { activeTags.insert(tag) }
                            }
                        }
                    }
                    list
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }

            AddBenchButton { showAdd = true }
                .padding(.bottom, 14)
        }
        .sheet(isPresented: $showAdd) {
            AddBenchSheet(start: location.location?.coordinate)
                .environmentObject(store)
                .environmentObject(location)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bankjesvinder")
                    .font(.display(36))
                    .foregroundStyle(Color.ink)
                    .verrassing()
                Slats()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(store.all.count)")
                    .font(.display(28))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                Text("BANKJES")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.muted)
            }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            TextField("Zoek op naam of plek", text: $query)
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1.5))

            Menu {
                Picker("Sorteren", selection: $sort) {
                    ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sort.rawValue)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ink)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1.5))
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if store.all.isEmpty {
            EmptyStateView(
                title: store.toonAlle && store.isLoadingOSM ? "Bankjes zoeken…" : "Nog geen bankjes",
                message: store.toonAlle
                    ? "Sta je locatie toe om de bankjes in de buurt te zien, of voeg zelf een bankje toe."
                    : "Hier staan de bankjes die jij toevoegt. Voeg je eerste bankje toe via de kaart."
            )
        } else if rows.isEmpty {
            EmptyStateView(title: "Geen bankjes gevonden", message: "Probeer een andere zoekterm of zet een filter uit.")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(rows) { bench in
                    BenchCard(bench: bench, distance: bench.distance(from: location.location))
                }
            }
        }
    }
}
