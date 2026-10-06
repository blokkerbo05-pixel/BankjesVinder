import SwiftUI

/// De tab "Instellingen": thema, weergave en (later meer) opties.
struct InstellingenScherm: View {
    @EnvironmentObject var thema: ThemaStore
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var account: AccountStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Haptiek.sleutel) private var trillingenAan = true
    @AppStorage("themaUitgeklapt") private var themaUitgeklapt = false   // onthoudt of de themakeuze open of dicht staat

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Instellingen")
                        .font(.display(30))
                        .foregroundStyle(Color.ink)

                    accountSectie

                    modusSectie

                    themaKaart

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
                        logoKop
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

    /// Inloggen of uitloggen.
    private var accountSectie: some View {
        sectie("Account") {
            kaart {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.isIngelogd ? "Ingelogd" : "Niet ingelogd")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.ink)
                        Text(account.email ?? "Log in om bankjes toe te voegen, te keuren en foto's te zetten.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)
                    }
                    Spacer(minLength: 8)
                    Button {
                        Haptiek.licht()
                        if account.isIngelogd {
                            Task { await account.logUit() }
                        } else {
                            account.toonLogin = true
                        }
                    } label: {
                        Text(account.isIngelogd ? "Uitloggen" : "Inloggen")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(account.isIngelogd ? Color.danger : Color.leaf)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
            }
        }
    }

    /// Open (alle bankjes) of Journey (alleen eigen bankjes). De keuze en de schakelaar zijn dezelfde instelling.
    private var modusSectie: some View {
        sectie("Modus") {
            VStack(spacing: 12) {
                Picker("Modus", selection: $store.toonAlle.animation(Animaties.veer)) {
                    Text("Open").tag(true)
                    Text("Journey").tag(false)
                }
                .pickerStyle(.segmented)
                Toggle(isOn: $store.toonAlle.animation(Animaties.veer)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alle bankjes tonen")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.ink)
                        Text(store.toonAlle
                             ? "Je ziet alle bankjes om je heen."
                             : "Je ziet alleen de bankjes die jij toevoegt.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)
                    }
                }
                .tint(Color.leaf)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, lineWidth: 1.5))
            .onChange(of: store.toonAlle) { Haptiek.selectie() }
        }
    }

    /// Het logo met de naam van de app eronder.
    private var logoKop: some View {
        VStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: KaartStijl.logoGrootte, height: KaartStijl.logoGrootte)
                .clipShape(RoundedRectangle(cornerRadius: KaartStijl.logoGrootte * KaartStijl.logoHoekVerhouding, style: .continuous))
                .zachteSchaduw()
                .accessibilityHidden(true)
            Text("Bankjesvinder")
                .font(.display(20))
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
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

    /// Eén kaartje voor het thema: ingeklapt een regel, uitgeklapt de thema's en Licht/Donker/Automatisch.
    private var themaKaart: some View {
        let huidig = Themas.thema(met: thema.themaID)
        return VStack(spacing: 0) {
            Button {
                withAnimation(Animaties.veer) { themaUitgeklapt.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text("Thema")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Spacer(minLength: 8)
                    Text(huidig.naam)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.muted)
                    Circle()
                        .fill(Color.leaf)
                        .frame(width: KaartStijl.themaStipKlein, height: KaartStijl.themaStipKlein)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.muted)
                        .rotationEffect(.degrees(themaUitgeklapt ? 90 : 0))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Thema, \(huidig.naam)")
            .accessibilityValue(themaUitgeklapt ? "uitgeklapt" : "ingeklapt")

            if themaUitgeklapt {
                VStack(spacing: 14) {
                    Divider().overlay(Color.line)
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(Themas.alle) { item in
                            themaBolletje(item)
                        }
                    }
                    Picker("Weergave", selection: $thema.weergave) {
                        ForEach(Weergave.allCases) { Text($0.titel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel))
    }

    /// Een thema als klein kleurbolletje (achtergrond met de hoofdkleur erin) en de naam eronder.
    private func themaBolletje(_ item: Thema) -> some View {
        let palet = colorScheme == .dark ? item.donker : item.licht
        let gekozen = thema.themaID == item.id
        return Button {
            Haptiek.selectie()
            thema.themaID = item.id
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color(hex: palet.appBg))
                    Circle().fill(Color(hex: palet.leaf))
                        .frame(width: KaartStijl.themaBolGrootte * 0.55, height: KaartStijl.themaBolGrootte * 0.55)
                }
                .frame(width: KaartStijl.themaBolGrootte, height: KaartStijl.themaBolGrootte)
                .overlay(Circle().stroke(Color.line, lineWidth: 1))
                .padding(4)
                .overlay(Circle().stroke(gekozen ? Color.leaf : Color.clear, lineWidth: 2.5))
                Text(item.naam)
                    .font(.system(size: 12, weight: gekozen ? .bold : .semibold))
                    .foregroundStyle(gekozen ? Color.ink : Color.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thema \(item.naam)")
        .accessibilityAddTraits(gekozen ? .isSelected : [])
    }
}
