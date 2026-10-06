// ============================================================
//  Edge Function "beoordeel": de eindbeoordeling van een bankje met de Anthropic API.
//
//  - Wordt door de app aangeroepen als een bankje genoeg stemmen heeft (status "in_beoordeling").
//  - De API-sleutel staat ALLEEN als geheim in Supabase (ANTHROPIC_API_KEY), nooit in de app of de repo.
//  - Geen sleutel, of de AI faalt? Dan beslist dezelfde rekenregel als de RegelAgent in de app.
//  - De instructie hieronder is een kopie van docs/agent-prompt.md. Pas je die aan,
//    kopieer hem dan ook hierheen (tussen de twee backticks van SYSTEEM_PROMPT).
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------- Instellingen ----------
const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-4-5-20251001";
const MAX_VOORBEELDEN = 6;          // zoveel eerdere bankjes als voorbeeld meegeven
const DUIDELIJK_GOED = 0.8;         // "duidelijk goed": minstens 80% stemde goed
const DUIDELIJK_FOUT = 0.2;         // "duidelijk fout": hooguit 20% stemde goed
const MIN_STEMMEN_VOORBEELD = 1;    // zet op 2 of hoger als er meer gebruikers zijn
const MAX_FOTOS = 2;                // zoveel foto's aan de AI laten zien
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const SYSTEEM_PROMPT = `Je bent de eindbeoordelaar van Bankjesvinder. Mensen sturen plekken in waar je buiten kunt zitten. Andere gebruikers swipen erop (goed / niet goed). Jij beslist samen met hun stemmen of de plek in de app komt.

Je krijgt: naam, plek (straat/plaats + coördinaten), kenmerken (rugleuning, schaduw, uitzicht, bij water, enz.), notitie, eventueel een foto, de stemmen (goed / niet goed), en een lijst eerdere voorbeelden die gebruikers duidelijk goed of fout vonden.

Beoordeel in deze volgorde:

1. Kun je er echt op zitten? (eis)
   Een "bankje" is breed: een gewone bank, maar ook een muurtje, boomstam of uitsparing in een rotswand kan tellen. Afkeuren als je er niet redelijk op kunt zitten of als het niet lijkt te bestaan.

2. Is het blijvend? (eis)
   De plek moet er over een tijdje nog zijn. Losse of tijdelijke zitplekken (een los houten bankje dat zo weggehaald kan worden, een tuinstoel, een evenementenbank) zijn niet handig voor de app.

3. Is het openbaar en netjes?
   Geen privétuin of terras waar je moet betalen, geen nep-locatie, geen beledigingen, persoonsgegevens, reclame of ongepaste foto's.

4. Hoe fijn is het? (geen eis, wel meewegen)
   Comfort, staat, rust, uitzicht. Een simpele maar echte en blijvende zitplek mag gewoon goedgekeurd worden.

5. Wat vinden gebruikers?
   Gebruik de stemmen en de eerdere voorbeelden om te begrijpen wat in deze app als goed bankje geldt. Volg de gebruikers meestal, maar wijk af als punt 1, 2 of 3 duidelijk niet klopt, en zeg dat dan in je reden.

Er zijn geen vaste "altijd goed" of "altijd fout" regels: kijk naar het geheel.
Bij twijfel over echtheid of ongepaste inhoud: afkeuren.

Antwoord alleen met JSON, reden kort en in het Nederlands:
{"oordeel": "goedgekeurd" | "afgekeurd", "reden": "max 1 zin", "zekerheid": 0.0-1.0}`;

type Oordeel = { goedgekeurd: boolean; reden: string };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/** De rekenregel (zelfde als de RegelAgent in de app en de database). */
function regel(goed: number, totaal: number, drempel: number): Oordeel {
  const aandeel = totaal > 0 ? goed / totaal : 0;
  const procent = Math.round(aandeel * 100);
  if (aandeel >= drempel) {
    return { goedgekeurd: true, reden: `${procent}% vond dit een goed bankje (${goed} van ${totaal})` };
  }
  return { goedgekeurd: false, reden: `Slechts ${procent}% vond dit een goed bankje (${goed} van ${totaal})` };
}

function beschrijf(b: any, goed: number, totaal: number): string {
  if (!b) return "Onbekend bankje (geen gegevens beschikbaar)";
  const tags = (b.tags ?? []).join(", ") || "geen";
  return `Naam: ${b.name}\nPlek: ${b.place} (${b.lat}, ${b.lon})\nKenmerken: ${tags}\nNotitie: ${b.note || "geen"}\nStemmen: ${goed} van ${totaal} goed`;
}

Deno.serve(async (req) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1. Alleen ingelogde gebruikers.
  const userClient = createClient(url, anon, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "niet ingelogd" }, 401);

  let benchId = "";
  try { benchId = String((await req.json()).bench_id ?? "").toLowerCase(); } catch { /* leeg */ }
  if (!benchId) return json({ error: "bench_id ontbreekt" }, 400);

  const db = createClient(url, service);

  // 2. Alleen bankjes die op "in_beoordeling" staan (zo kan niets dubbel of te vroeg beslist worden).
  const { data: status } = await db.from("keur_status").select("*").eq("bench_id", benchId).maybeSingle();
  if (!status || status.status !== "in_beoordeling") return json({ status: status?.status ?? null });

  const { data: instellingen } = await db.from("keur_instellingen").select("goedkeur_drempel").eq("id", 1).maybeSingle();
  const drempel = Number(instellingen?.goedkeur_drempel ?? 0.7);
  const goed = status.aantal_goed as number;
  const totaal = status.aantal_stemmen as number;

  let oordeel: Oordeel = regel(goed, totaal, drempel);   // terugval
  let door = "regel";

  // 3. De AI, als er een sleutel is en het bankje bekend is (bankjes uit OpenStreetMap beoordelen we met de regel).
  const sleutel = Deno.env.get("ANTHROPIC_API_KEY");
  if (sleutel && UUID.test(benchId)) {
    try {
      const { data: bench } = await db.from("benches").select("*").eq("id", benchId).maybeSingle();
      if (bench) {
        const { data: fotos } = await db.from("bench_photos").select("path").eq("bench_id", benchId)
          .eq("verborgen", false).order("created_at").limit(MAX_FOTOS);

        // Voorbeelden: recente bankjes waar gebruikers duidelijk over waren.
        const { data: eerdere } = await db.from("keur_status")
          .select("bench_id,status,aantal_stemmen,aantal_goed").in("status", ["goedgekeurd", "afgekeurd"])
          .gte("aantal_stemmen", MIN_STEMMEN_VOORBEELD).neq("bench_id", benchId)
          .order("updated_at", { ascending: false }).limit(40);
        const duidelijk = (eerdere ?? []).filter((e: any) => {
          const aandeel = e.aantal_goed / e.aantal_stemmen;
          return aandeel >= DUIDELIJK_GOED || aandeel <= DUIDELIJK_FOUT;
        }).filter((e: any) => UUID.test(e.bench_id)).slice(0, MAX_VOORBEELDEN);
        const { data: voorbeeldBankjes } = duidelijk.length
          ? await db.from("benches").select("*").in("id", duidelijk.map((e: any) => e.bench_id))
          : { data: [] };
        const voorbeeldTekst = duidelijk.map((e: any) => {
          const b = (voorbeeldBankjes ?? []).find((x: any) => x.id === e.bench_id);
          return `--- Voorbeeld (${e.status === "goedgekeurd" ? "duidelijk goed" : "duidelijk fout"})\n${beschrijf(b, e.aantal_goed, e.aantal_stemmen)}`;
        }).join("\n\n");

        const inhoud: any[] = (fotos ?? []).map((f: any) => ({
          type: "image",
          source: { type: "url", url: `${url}/storage/v1/object/public/bankjes-fotos/${f.path}` },
        }));
        inhoud.push({
          type: "text",
          text: `Te beoordelen bankje:\n${beschrijf(bench, goed, totaal)}\n\nEerdere voorbeelden:\n${voorbeeldTekst || "(nog geen)"}`,
        });

        const antwoord = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: { "x-api-key": sleutel, "anthropic-version": "2023-06-01", "content-type": "application/json" },
          body: JSON.stringify({ model: MODEL, max_tokens: 300, system: SYSTEEM_PROMPT, messages: [{ role: "user", content: inhoud }] }),
          signal: AbortSignal.timeout(25000),
        });
        if (antwoord.ok) {
          const tekst: string = (await antwoord.json()).content?.[0]?.text ?? "";
          const uitkomst = JSON.parse(tekst.match(/\{[\s\S]*\}/)?.[0] ?? "");
          if (uitkomst.oordeel === "goedgekeurd" || uitkomst.oordeel === "afgekeurd") {
            oordeel = { goedgekeurd: uitkomst.oordeel === "goedgekeurd", reden: String(uitkomst.reden ?? "").slice(0, 300) || "Beoordeeld door de AI" };
            door = "ai";
          }
        }
      }
    } catch (_) { /* AI mislukt: de rekenregel blijft gelden */ }
  }

  // 4. Opslaan. Goedgekeurd: reden voor iedereen. Afgekeurd: reden alleen voor de maker (keur_afwijzing).
  const { data: bijgewerkt } = await db.from("keur_status").update({
    status: oordeel.goedgekeurd ? "goedgekeurd" : "afgekeurd",
    reden: oordeel.goedgekeurd ? oordeel.reden : null,
    updated_at: new Date().toISOString(),
  }).eq("bench_id", benchId).eq("status", "in_beoordeling").select();
  if (bijgewerkt && bijgewerkt.length > 0 && !oordeel.goedgekeurd) {
    await db.from("keur_afwijzing").upsert({ bench_id: benchId, reden: oordeel.reden, updated_at: new Date().toISOString() });
  }
  return json({ status: oordeel.goedgekeurd ? "goedgekeurd" : "afgekeurd", door });
});
