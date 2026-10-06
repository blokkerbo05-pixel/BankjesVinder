import SwiftUI

/// Het scherm bij de allereerste start: kies Open of Journey.
struct WelkomScherm: View {
    /// `true` = Open, `false` = Journey.
    let kies: (Bool) -> Void
    @State private var zichtbaar = 0   // hoeveel onderdelen al zijn binnengekomen

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: KaartStijl.welkomLogoGrootte, height: KaartStijl.welkomLogoGrootte)
                        .clipShape(RoundedRectangle(cornerRadius: KaartStijl.welkomLogoGrootte * KaartStijl.logoHoekVerhouding, style: .continuous))
                        .kaartSchaduw()
                        .accessibilityHidden(true)
                    Text("Welkom bij Bankjesvinder")
                        .font(.display(28))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                    Text("Hoe wil je beginnen? Je kunt dit later altijd veranderen in Instellingen.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center)
                }
                .opacity(zichtbaar >= 1 ? 1 : 0)
                .offset(y: zichtbaar >= 1 || Animaties.beperkt ? 0 : 12)

                VStack(spacing: 14) {
                    keuzeKaart(icoon: KaartStijl.openIcoon, titel: "Open",
                               tekst: "Zie meteen alle bankjes om je heen, uit OpenStreetMap en later ook van anderen.",
                               open: true)
                        .opacity(zichtbaar >= 2 ? 1 : 0)
                        .offset(y: zichtbaar >= 2 || Animaties.beperkt ? 0 : 16)
                    keuzeKaart(icoon: KaartStijl.journeyIcoon, titel: "Journey",
                               tekst: "Begin met een lege kaart en bouw je eigen verzameling door zelf bankjes toe te voegen.",
                               open: false)
                        .opacity(zichtbaar >= 3 ? 1 : 0)
                        .offset(y: zichtbaar >= 3 || Animaties.beperkt ? 0 : 16)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .task {
            for stap in 1...3 {
                withAnimation(Animaties.veer) { zichtbaar = stap }
                try? await Task.sleep(nanoseconds: UInt64(KaartStijl.welkomStaffelSeconden * 1_000_000_000))
            }
        }
    }

    private func keuzeKaart(icoon: String, titel: String, tekst: String, open: Bool) -> some View {
        Button {
            Haptiek.licht()
            kies(open)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icoon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(open ? Color.leaf : Color.wood)
                    .frame(width: KaartStijl.welkomKaartIcoonGrootte, height: KaartStijl.welkomKaartIcoonGrootte)
                    .background(Circle().fill(open ? Color.leafSoft : Color.woodSoft))
                VStack(alignment: .leading, spacing: 4) {
                    Text(titel)
                        .font(.display(22))
                        .foregroundStyle(Color.ink)
                    Text(tekst)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(KaartStijl.welkomKaartPadding)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: KaartStijl.hoekGroot).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekGroot).stroke(Color.line, lineWidth: 1.5))
            .kaartSchaduw()
        }
        .buttonStyle(.indruk)
        .accessibilityLabel("\(titel). \(tekst)")
    }
}
