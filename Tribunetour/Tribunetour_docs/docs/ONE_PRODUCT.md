# One Product

## Formål
Tribunetour skal opleves som ét produkt på tværs af app og web, ikke som to parallelle projekter.

App og web skal derfor:
- bruge samme kernebegreber
- prioritere de samme brugerflows
- dele samme produktlogik, hvor det giver mening
- være tydelige om, hvad der er reference-data, og hvad der er brugerdata

Dette dokument definerer fundamentet for den retning.

## Produktprincipper

### 1. Ét produkt, to flader
App og web er to indgange til samme univers:
- `Stadions`
- `Kampe`
- `Min tur`

Brugeren skal kunne skifte mellem web og app uden at skulle lære navigation, ordvalg eller funktioner på ny.

### 2. Appen er reference for kerneoplevelsen
Den nuværende iOS-app er det mest modne produktspor.

Det betyder:
- appens informationsarkitektur er udgangspunktet
- web må gerne være enklere i perioder
- web må ikke opfinde et andet produkt-sprog end appen

### 3. Web er ikke marketing først
Tribunetour-web må gerne have support/privacy og en enkel introduktion, men dens primære rolle er produktflade.

Det betyder:
- mindre hero/marketing-copy
- mere reel produktfunktionalitet
- færre dekorative sektioner uden brugerformål

### 4. Delt logik vigtigere end delt kode
Vi skal ikke presse SwiftUI og web ind i kunstig fælles kode for enhver pris.

Vi skal i stedet dele:
- begreber
- dataformer
- regler
- UI-principper

## Kerneflader

### Stadions
Formål:
- opdage stadions
- søge og filtrere
- se status for besøg
- gå videre til detaljer

Minimum på tværs:
- søgning
- league/område-filtre
- besøgt/ikke besøgt
- tydelig statusmarkering

### Kampe
Formål:
- se kommende kampe
- filtrere på tid og liga
- bruge kampe som indgang til stadioner og ture

Minimum på tværs:
- kommende kampe
- tidsfiltre
- liga-filtre
- sammenhæng til stadion

### Min tur
Formål:
- give overblik over progression
- samle brugerens besøg, noter, planer og senere stats

Minimum på tværs:
- antal besøgte stadions
- antal tilbage
- progression
- liste eller grupperet oversigt over brugerens steder

## Fælles navigation
Primær navigation skal konvergere mod:
- `Stadions`
- `Kampe`
- `Min tur`

Sekundære flader:
- `Kort`
- `Support`
- `Privacy`
- `Login`

Bemærk:
- `Kort` er vigtig, men ikke nødvendigvis primær første-nav på alle flader
- support/privacy er driftsflader, ikke kerneprodukt

## Fælles ordforråd
Disse begreber skal bruges konsekvent:
- `Stadion`
- `Kamp`
- `Besøgt`
- `Ikke besøgt`
- `Min tur`
- `Plan`

Undgå på brugerflader:
- intern meta-copy om web-beta
- beskrivelser af arkitektur eller designproces
- forskellige labels for samme funktion på web og app

## Dataopdeling

### Reference-data
Dette er fælles, læsbare produktdata:
- stadions
- klubber
- fixtures/kampe
- ligaer

Krav:
- samme identitet på tværs af app og web
- stabile nøgler
- tydelig kilde/versionering

### Brugerdata
Dette er personlige data:
- besøg
- visited date
- noter
- anmeldelser
- billeder
- planer

Krav:
- tydelig ejer: brugeren
- tydelig sync-model
- samme forventning i app og web til hvad der findes og hvad der ikke findes endnu

### Produktmatrix for brugerdata
For at Tribunetour kan opleves som ét produkt uden at love for meget, gælder denne opdeling lige nu:

- `Shared nu`: `visited`, `visitedDate`
- `App-only`: noter, reviews, billeder, weekend-plan, achievements
- `Shared senere`: noter, reviews, weekend-plan og evt. billeder, hvis scope og backend-kontrakt besluttes

Det betyder i praksis:
- web og app skal føles ens omkring besøgsstatus
- web må gerne være enklere på richer brugerdata, så længe det er bevidst
- appen må gerne være dybere, men ikke kommunikere som om alle data allerede deles på tværs

## Auth-retning
Mål:
- samme identitet på web og app
- samme adgang til brugerens egne data

Principper:
- login skal være enkelt og lavfriktions
- magic link er fint som første model
- auth må ikke føles som en særskilt web-feature; det er adgang til brugerens egen Tribunetour

Indtil fuld paritet findes:
- login UI må godt være enklere på web end i app
- men brugerens forventning til "min data" skal være ens

## Designretning
Vi skal have et delt designsprog, ikke nødvendigvis et delt komponentbibliotek.

Fælles byggesten:
- farver
- typografisk hierarki
- spacing-scale
- cards
- chips/filtre
- knapper
- states: tom, loading, fejl, succes, locked

Designprincipper:
- funktion før pynt
- tydelig informationsstruktur
- stærke filtre og statusmarkeringer
- samme visuelle sprog for besøg, progression og kampstatus

## Roadmap-prioritet

### Fase 1: Konvergens
- fælles navigation
- fælles copy
- fælles design-tokens
- web som reel produktflade, ikke marketing-shell

### Fase 2: Data og auth
- samme loginretning på tværs
- samme visited-state mellem flader
- afklaring af source of truth for brugerdata

### Fase 3: Feature-paritet
- kampe
- stadiondetaljer
- min tur/statistik
- plan-flow

### Fase 4: Drift og skalering
- tydelig backend-model
- versionsstyrede reference-data
- mere robust sync og conflict-handling på tværs af flader

## Beslutninger lige nu
- iOS-appen røres ikke, mens App Store-sporet stabiliseres
- web må gerne udvikles videre som næste produktflade
- nye webfeatures skal måles op mod appens kerneoplevelse
- vi bygger ikke mere meta-/marketing-copy ind i produktfladerne

## Næste konkrete arbejde
1. dokumentere et lille delt designsystem
2. gøre `Stadions`, `Kampe` og `Min tur` konsistente på web
3. definere auth- og dataejerskab mellem app og web
4. planlægge første egentlige paritetsspor fra app til web

Se også `DESIGN_TOKENS.md` for den konkrete token-spec.
