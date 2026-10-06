# Bankjesvinder – iPhone-app

Wat de app nu kan:

- Kaart met je eigen locatie (blauwe stip)
- Bestaande bankjes in de buurt uit OpenStreetMap (groene speldjes)
- Zelf bankjes toevoegen door de kaart te schuiven tot het speldje goed staat (oranje speldjes). Straat en plaats vult de app zelf in.
- Onderaan "Dichtbij": de 10 dichtstbijzijnde bankjes, met afstand en looptijd
- "Zoek hier naar bankjes" als je de kaart naar een andere plek schuift
- Lijst-tab, net als de web-versie: zoeken, filters, sorteren (ook op dichtstbij), sterren en route via Apple Kaarten of Google Maps

Let op: zelf toegevoegde bankjes staan nu alleen op jouw iPhone. Delen met anderen, beoordelen en foto's komen in de volgende stap (online database).

## Zo zet je hem op je iPhone (zonder Mac)

GitHub bouwt de app voor je op een Mac in de cloud. Daarna installeer je hem met Signulous.

1. Pak de zip uit.
2. Ga naar github.com → **New repository** → noem hem `bankjesvinder` → **Create repository**.
3. Klik op **uploading an existing file** en sleep de inhoud van de map erin: `Sources`, `project.yml` en `LEESMIJ.md`. Klik op **Commit changes**.
4. Map `.github` wordt vaak niet meegenomen omdat hij verborgen is. Maak hem daarom met de hand:
   - Klik op **Add file → Create new file**
   - Typ als naam precies: `.github/workflows/build.yml`
   - Open het bestand `build.yml` uit de zip, kopieer alles en plak het erin
   - Klik op **Commit changes**
5. Ga naar het tabblad **Actions**. Je ziet "Bouw iPhone-app" draaien. Dat duurt zo'n 5–10 minuten. Een groen vinkje betekent dat het gelukt is.
6. Klik op die run. Onderaan bij **Artifacts** staat `Bankjesvinder-ipa`. Download hem en pak hem uit. Daarin zit `Bankjesvinder.ipa`.
7. Upload `Bankjesvinder.ipa` in Signulous en installeer hem zoals je gewend bent.
8. Open de app en tik op **Sta toe tijdens gebruik** als hij om je locatie vraagt.

Rood kruisje bij stap 5? Klik op de mislukte stap, kopieer de foutmelding en stuur die naar Claude.

Elke keer dat je later iets aanpast in GitHub, bouwt hij automatisch een nieuwe versie.
