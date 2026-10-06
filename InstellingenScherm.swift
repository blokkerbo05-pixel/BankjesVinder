import SwiftUI

/// De tab "Instellingen": thema, weergave en (later meer) opties.
struct InstellingenScherm: View {
    @EnvironmentObject var thema: ThemaStore
    @Environment(\.colorScheme) private var colorScheme

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Onderdelen

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
