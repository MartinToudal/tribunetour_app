# Design Tokens

## Formål
Dette dokument definerer et lille delt designsystem for Tribunetour på tværs af web og app.

Målet er ikke fælles kode, men fælles regler for:
- farver
- typografi
- spacing
- former
- komponentmønstre
- states

Det skal bruges som reference, når nye flader bygges på web, og når appen senere justeres mod samme retning.

## Designprincipper
- funktion før pynt
- tydelig status over dekoration
- information skal kunne scannes hurtigt
- filtre og valg skal være visuelt konsekvente
- progression og besøg skal være lette at aflæse

## Farver

### Base
- `bg/base`: `#0A0F0D`
- `bg/elevated`: `rgba(16, 24, 20, 0.92)`
- `surface/default`: `rgba(18, 26, 22, 0.88)`
- `surface/soft`: `rgba(30, 42, 36, 0.72)`
- `surface/strong`: `#141D19`

### Content
- `text/primary`: `#F5F7F2`
- `text/muted`: `#A8B4AD`
- `line/default`: `rgba(182, 210, 189, 0.16)`
- `line/strong`: `rgba(182, 210, 189, 0.30)`

### Accent
- `accent/default`: `#B8FF6A`
- `accent/strong`: `#7ED957`
- `accent/ink`: `#11200D`

### Status
- `status/visited`: brug `accent/default` eller `accent/strong`
- `status/unvisited`: brug `text/muted` + `line/default`
- `status/error`: reserveres til fejl og moderation, ikke som almindelig produktaccent

## Typografi

### Hierarki
- `display`: bruges sparsomt til overordnede overskrifter
- `section-title`: primær sektionstitel
- `body`: normal brødtekst
- `supporting`: forklarende tekst, labels, metadata
- `eyebrow`: små, uppercase labels til sektioner og status

### Regler
- overskrifter skal være korte og konkrete
- supporting text skal forklare funktion, ikke strategi
- ingen meta-copy om platform, designproces eller intern roadmapping på produktflader

## Spacing

Brug en enkel scale:
- `4`
- `8`
- `12`
- `16`
- `20`
- `24`
- `32`
- `40`

Regler:
- tætte elementer: `8` eller `12`
- standard intern card-spacing: `16` eller `20`
- sektionsafstand: `24` eller `32`
- store skift mellem blokke: `40`

## Radius
- `control/small`: `16`
- `control/default`: `20`
- `card/default`: `24`
- `card/hero`: `28`
- `pill/full`: `9999`

Regler:
- filtre og knapper skal føles som samme familie
- cards må gerne være bløde, men ikke oppustede

## Shadow og dybde
- standard card-shadow skal være blød og mørk
- dybde bruges til at adskille lag, ikke til pynt
- brug ikke mange forskellige skyggetyper i samme view

Web-reference:
- `shadow/default`: `0 24px 80px rgba(0, 0, 0, 0.35)`

## Komponentmønstre

### Cards
Cards bruges til:
- oversigter
- grupperede lister
- fremhævede stats
- login og brugerhandlinger

Et card skal normalt have:
- mørk surface
- diskret border
- afrundet form
- tydelig indre rytme

### Pills og filtre
Pills bruges til:
- navigation
- liga-filtre
- tidsfiltre
- statusfiltre

Aktiv state skal vises med:
- tydelig baggrundsændring
- tydelig border
- højere kontrast i tekst

### Knapper
Primær handling:
- accent-farve
- accent ink-tekst
- bruges til vigtigste næste skridt

Sekundær handling:
- neutral mørk surface
- tydelig border
- bruges til alternative handlinger

### Inputs
Inputs skal:
- ligge på mørk overflade
- have diskret border
- få tydelig fokusstate
- være visuelt beslægtede med cards og filtre

## Produktstates

### Empty
Skal forklare:
- hvad der mangler
- hvad brugeren kan gøre nu

Må ikke:
- lyde teknisk
- lyde som intern systemtilstand

### Loading
Skal være rolig og kort.
Undgå store blokke med unødig tekst.

### Success
Skal være tydelig, men lavmælt.
Brug accent og kort tekst, ikke store fejringseffekter.

### Error
Skal forklare:
- hvad der gik galt
- hvad brugeren kan gøre nu

Fejl må ikke forveksles med almindelig produktaccent.

### Locked / Login-gated
Skal forklare:
- hvad login giver adgang til
- hvorfor brugeren ser denne state

Ikke:
- "teknisk fallback"
- "ikke konfigureret" som brugerrettet sprog

## Mapping til nuværende web

Eksisterende web-tokens matcher allerede store dele af denne retning:
- `--bg`
- `--bg-elevated`
- `--surface`
- `--surface-strong`
- `--surface-soft`
- `--line`
- `--line-strong`
- `--text`
- `--muted`
- `--accent`
- `--accent-strong`
- `--accent-ink`

Eksisterende web-klasser matcher også designretningen:
- `.site-card`
- `.site-card-soft`
- `.pill-nav`
- `.stat-chip`
- `.label-eyebrow`
- `.cta-primary`
- `.cta-secondary`
- `.field-input`

## Regler for næste iterationer
1. nye produktflader skal bruge dette ordforråd og disse tokens som udgangspunkt
2. nye komponenter skal helst passe ind i card/pill/button/input-familierne
3. hvis web afviger bevidst fra app-retningen, skal det være en klar produktbeslutning
4. når appen senere justeres, skal denne token-spec bruges som sammenligningsgrundlag

## Næste arbejde
1. dokumentere fælles dataejerskab og auth-retning
2. konvergere `Stadions`, `Kampe` og `Min tur` yderligere på web
3. definere hvilke app-komponenter der senere skal oversættes til samme designfamilie
