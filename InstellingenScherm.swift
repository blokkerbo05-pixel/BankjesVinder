import SwiftUI

/// De tab "Instellingen": thema, weergave en (later meer) opties.
struct InstellingenScherm: View {
    @EnvironmentObject var thema: ThemaStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Haptiek.sleutel) private var trillingenAan = true

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Instellingen")
                        .font(.display(30))
                        .foregroundStyle(Color.ink)

                    sectie("Thema") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(Themas.alle) { item in
                                themaTegel(item)
                            }
                        }
                    }

                    sectie("Weergave") {
                        Picker("Weergave", selection: $thema.weergave) {
                            ForEach(Weergave.allCases) { Text($0.titel).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    sectie("Trillingen") {
                        Toggle(isOn: $trillingenAan) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trillingen")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.ink)
                                Text("Een kleine tik bij keuzes in de app")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.muted)
                            }
                        }
                        .tint(Color.leaf)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
                        .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, lineWidth: 1.5))
                        .onChange(of: trillingenAan) { Haptiek.licht() }
                    }

                    sectie("Binnenkort") {
                        kaart {
                            ForEach(Array(Binnenkort.items.enumerated()), id: \.element.id) { index, item in
                                binnenkortRij(item)
                                if index < Binnenkort.items.count - 1 { Divider().overlay(Color.line) }
                            }
                        }
                    }

                    sectie("Over") {
                        kaart {
                            overRij("Versie", versie)
                            Divider().overlay(Color.line)
                            overRij("Build", BuildInfo.buildnummer)
                            Divider().overlay(Color.line)
                            overRij("Commit", BuildInfo.commit)
                            Divider().overlay(Color.line)
                            overRij("Datum", BuildInfo.datum)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    private var versie: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    // MARK: Onderdelen

    /// Kaartje om een groepje rijen heen.
    private func kaart<Inhoud: View>(@ViewBuilder _ inhoud: () -> Inhoud) -> some View {
        VStack(spacing: 0) { inhoud() }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, lineWidth: 1.5))
    }

    /// Een toekomstige functie: niet aantikbaar, met een klein "binnenkort"-label.
    private func binnenkortRij(_ item: BinnenkortItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icoon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.muted)
                .frame(width: 24)
            Text(item.titel)
                .font(.system(size: 16))
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            Text("binnenkort")
                .font(.system(size: KaartStijl.binnenkortLabelGrootte, weight: .bold))
                .foregroundStyle(Color.leaf)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.leafSoft))
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func overRij(_ titel: String, _ waarde: String) -> some View {
        HStack {
            Text(titel)
                .font(.system(size: 16))
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            Text(waarde)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Color.muted)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func sectie<Inhoud: View>(_ titel: String, @ViewBuilder _ inhoud: () -> Inhoud) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel.uppercased())
                .font(.system(size: KaartStijl.instellingKopGrootte, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.muted)
            inhoud()
        }
    }

    private func themaTegel(_ item: Thema) -> some View {
        let palet = colorScheme == .dark ? item.donker : item.licht
        let gekozen = thema.themaID == item.id
        return Button {
            Haptiek.selectie()
            thema.themaID = item.id
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: -6) {
                    ForEach([palet.appBg, palet.leaf, palet.wood], id: \.self) { kleur in
                        Circle()
                            .fill(Color(hex: kleur))
                            .frame(width: KaartStijl.themaStipGrootte, height: KaartStijl.themaStipGrootte)
                            .overlay(Circle().stroke(Color.line, lineWidth: 1))
                    }
                }
                Text(item.naam)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 0)
                if gekozen {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.leaf)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: KaartStijl.themaTegelHoogte)
            .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel)
                .stroke(gekozen ? Color.leaf : Color.line, lineWidth: gekozen ? 2 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thema \(item.naam)")
        .accessibilityAddTraits(gekozen ? .isSelected : [])
    }
}
