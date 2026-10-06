import SwiftUI

/// Inloggen met e-mail en een 6-cijferige code.
struct LoginScherm: View {
    @EnvironmentObject var account: AccountStore
    @Environment(\.dismiss) private var dismiss

    private enum Stap { case email, code }

    @State private var stap: Stap = .email
    @State private var email = ""
    @State private var code = ""
    @State private var bezig = false
    @State private var fout: String?
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button("Sluiten") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.muted)
                }

                Text(stap == .email ? "Inloggen" : "Vul de code in")
                    .font(.display(30))
                    .foregroundStyle(Color.ink)
                Text(stap == .email
                     ? "Vul je e-mailadres in. Je krijgt een code van \(SupabaseConfig.codeLengte) cijfers. Een wachtwoord heb je niet nodig."
                     : "We hebben een code van \(SupabaseConfig.codeLengte) cijfers gestuurd naar \(email). Check ook je spam.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)

                Group {
                    if stap == .email {
                        TextField("E-mailadres", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        TextField("Code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .onChange(of: code) {
                                code = String(code.filter(\.isNumber).prefix(SupabaseConfig.codeLengte))
                                if code.count == SupabaseConfig.codeLengte { Task { await controleer() } }
                            }
                    }
                }
                .focused($focus)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
                .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, lineWidth: 1.5))

                if let fout {
                    Text(fout)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.danger)
                        .transition(.opacity)
                }

                Button {
                    Task {
                        if stap == .email { await stuur() } else { await controleer() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if bezig { ProgressView().tint(Color.appBg) }
                        Text(stap == .email ? "Stuur code" : "Inloggen")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.appBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.leaf))
                }
                .buttonStyle(.indruk)
                .disabled(bezig)

                if stap == .code {
                    Button("Andere e-mail of nieuwe code") {
                        withAnimation(Animaties.veer) { stap = .email; code = ""; fout = nil }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.leaf)
                }
                Spacer()
            }
            .padding(20)
        }
        .animation(Animaties.fade, value: fout)
        .onAppear { focus = true }
        .onChange(of: account.isIngelogd) { if account.isIngelogd { dismiss() } }
    }

    private func stuur() async {
        let schoon = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard schoon.contains("@"), schoon.contains(".") else {
            fout = "Vul een geldig e-mailadres in."
            return
        }
        email = schoon
        bezig = true
        fout = nil
        defer { bezig = false }
        do {
            try await account.stuurCode(naar: schoon)
            Haptiek.licht()
            withAnimation(Animaties.veer) { stap = .code }
            focus = true
        } catch {
            fout = Netwerk.melding(voor: error, standaard: "De code versturen lukte niet. Check het adres en probeer het later opnieuw.")
        }
    }

    private func controleer() async {
        guard code.count == SupabaseConfig.codeLengte, !bezig else { return }
        bezig = true
        fout = nil
        defer { bezig = false }
        do {
            try await account.controleer(code: code, voor: email)
            Haptiek.licht()
            dismiss()
        } catch {
            code = ""
            fout = Netwerk.melding(voor: error, standaard: "Die code klopt niet of is verlopen. Vraag een nieuwe aan.")
        }
    }
}
