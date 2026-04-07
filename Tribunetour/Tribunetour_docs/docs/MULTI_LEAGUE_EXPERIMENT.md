# Multi-League Experiment

## Formål
Dette dokument beskriver en kontrolleret måde at udvide Tribunetour med flere ligaer uden at gøre Danmark-sporet skrøbeligt.

Målet er:
- at kunne aktivere ekstra ligaer som et udvidelseslag
- at kunne begrænse funktionen til bestemte brugere
- at kunne skjule eller fjerne funktionen igen uden stor refaktorering
- at kunne genbruge samme model senere til premium

Første tænkte pakke er England:
- Premier League
- Championship
- League One
- League Two

## Produktprincip
- Danmark er altid kerneproduktet.
- Ekstra ligaer er et sidecar-spor, ikke en omskrivning af den nuværende model.
- Første version er intern/eksperimentel.
- Senere kan samme mekanisme bruges som premium-adgang.

Det betyder:
- default-oplevelsen er stadig Danmark
- ekstra ligaer skal kunne slås til og fra centralt
- UI må ikke antage, at alle brugere har adgang til alle ligaer

## Adgangsmodel
Multi-league skal være brugerafhængig, ikke global.

Det gælder især på web:
- hvis brugeren ikke er logget ind, ser de kun Danmark
- hvis brugeren er logget ind, læses deres aktive league packs
- kun aktive packs må påvirke data, navigation, filtre og progression

Det er den rigtige retning af tre grunde:
- det gør det muligt at køre intern test på udvalgte brugere
- det gør funktionen let at pakke som premium senere
- det undgår at anonyme brugere får en anden dataverden end forventet

## Foreslået model

### League packs
Brug et centralt begreb for adgangspakker:

```ts
type LeaguePackId =
  | "core_denmark"
  | "england_full_pyramid";
```

### Brugeradgang

```ts
type UserLeagueAccess = {
  enabledPacks: LeaguePackId[];
};
```

### Competition scope
Klubber, stadions, fixtures og progression bør have tydelig metadata:

```ts
type CompetitionScope = {
  countryCode: string;
  leagueCode: string;
  leaguePack: LeaguePackId;
};
```

Pointen er:
- ingen hårdkodet `if england`
- filtrering sker på metadata
- samme model kan udvides med flere lande senere

## Reference-data
England bør ikke bare lægges oveni nuværende danske data uden struktur.

Anbefalet retning:
- `clubs.denmark.json`
- `clubs.england.json`
- `fixtures.denmark.json`
- `fixtures.england.json`

Alternativt:
- én samlet outputfil med tydelig `leaguePack`-tagging

Uanset format skal følgende være sandt:
- hvert stadion og hver klub har stabilt id
- hver fixture har tydelig liga- og landekontekst
- data kan filtreres uden særlogik i UI

## App-adfærd
Når ekstra ligaer er inaktive:
- engelske klubber vises ikke
- engelske fixtures vises ikke
- weekendplan tæller dem ikke med
- progression og achievements beregnes kun på Danmark

Når ekstra ligaer er aktive:
- engelske data bliver en del af oplevelsen
- filtre og sektioner skal være tydelige
- progression skal kunne vise både samlet status og status pr. liga/land

Første version kan styres via en intern toggle i `Interne Værktøjer`.
Den toggle bør dog afspejle en central access-model og ikke leve som ren lokal særlogik for evigt.

## Web-adfærd
På web bør funktionen være login-bundet fra starten.

Det betyder:
- ikke-loggede brugere ser kun Danmark
- loggede brugere kan få ekstra ligaer via deres profil/adgang
- server og klient skal begge respektere aktive league packs

Første version kan være et internt brugerflag.
Senere kan samme felt eller mekanisme udvides til premium-entitlements.

## Anbefalet backend-retning
Gem brugerens adgang til league packs centralt.

Eksempel:

```json
{
  "enabledLeaguePacks": ["core_denmark", "england_full_pyramid"]
}
```

Det kan bo i brugerprofilen eller et separat entitlement-lag.

Krav:
- app og web skal kunne læse samme adgangskilde
- adgang skal kunne ændres uden ny app-release
- det skal være muligt at give interne testere adgang uden at åbne funktionen for alle

## Feature-flag strategi

### Fase 1: Intern eksperimentel adgang
- intern toggle i app
- centralt brugerflag på web
- kun udvalgte brugere ser ekstra ligaer

### Fase 2: Samlet access-model
- app og web læser samme centrale access-state
- lokal toggle bliver kun debug/test-hjælp

### Fase 3: Premium
- samme mekanisme bruges til køb/adgang
- gratis brugere beholder Danmark
- premium-brugere får ekstra league packs

## UX-principper
- behold Danmark som standardoplevelse
- undgå at blande alle ligaer uden struktur
- brug tydelige filtre som land, liga eller league pack
- progression bør kunne vises:
  - samlet
  - pr. land
  - pr. liga

Hvis oplevelsen bliver for rodet, skal eksperimentet kunne slås helt fra uden at skade kerneproduktet.

## Arkitekturprincip
Dette skal bygges som et udvidelseslag, ikke som en kerneomskrivning.

Det betyder:
- én central feature gate
- én central adgangsmodel
- ingen spredte specialcases i views
- reference-data pipelines pr. league pack
- mulighed for at fjerne data og UI igen uden bred oprydning

## Foreslået implementeringsrækkefølge
1. Definér `league pack`-modellen
2. Tilføj metadata på klubber, stadions og fixtures
3. Opret central adgangsmodel for app og web
4. Læg intern toggle i `Interne Værktøjer`
5. Gør web-adgang login-bundet
6. Tilføj England som separat reference-data-pack
7. Opdatér filtre, lister og weekendplan
8. Opdatér progression og achievements
9. Kør intern evaluering
10. Beslut om funktionen skal videre som premium eller fjernes igen

## Beslutningsregel
Eksperimentet er kun en succes hvis:
- datakvaliteten holder
- UI stadig føles overskueligt
- performance ikke bliver mærkbart dårligere
- brugerne faktisk oplever værdi

Hvis ikke, skal sporet kunne lukkes ned ved at:
- deaktivere league pack-adgang
- skjule ekstra UI
- beholde Danmark som uændret baseline
