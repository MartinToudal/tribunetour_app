# Achievements Strategy

Formål: gøre achievements mere motiverende, mere relevante for den enkelte bruger og mere skalerbare, når Tribunetour udvides med flere lande.

## Problem i dag

Achievements fungerer, men opleves stadig for meget som en lang liste.

Det giver tre konkrete problemer:

- `Min tur` bliver for tung, hvis vi bare lægger flere achievements ind.
- landespecifikke og række-specifikke achievements drukner blandt generelle mål.
- produktet mangler en tydelig forskel på:
  - hvad der er dit næste realistiske mål nu
  - hvad der findes som større samling eller katalog på længere sigt

## Produktprincip

`Min tur` skal ikke være hele achievement-systemet.

`Min tur` skal være den motiverende overflade, hvor brugeren ser:

- næste achievement
- få aktive achievements
- relevant progression i hjemland og åbne lande

En fremtidig dedikeret achievements-flade skal være stedet, hvor brugeren kan se hele samlingen.

## Foreslået model

Achievements deles i fem spor:

### 1. Rejse

Generelle achievements, som giver mening uanset land.

Eksempler:

- Første stadion
- 5 stadions
- 25 stadions
- Første note
- Første anmeldelse
- Første billede
- 5 byer
- 3 forskellige rækker

### 2. Hjemland

Achievements for brugerens valgte hjemland.

Eksempler:

- Første stadion i Danmark
- 10 danske stadions
- Fuldfør en dansk række
- Besøg halvdelen af de danske stadions i scope

Det her spor bør være det primære for nye brugere.

### 3. Lande

Generiske land-achievements, som kan bruges på tværs af alle lande.

Det skal ikke være en særlig “Tyrkiet-idé” eller “Tyskland-idé”.
Det skal være en fælles model, som automatisk virker for alle lande.

Eksempler:

- Første stadion i et nyt land
- 3 stadions i et land
- 10 stadions i et land
- Fuldfør én række i et land
- Fuldfør alle stadions i et land

Visningsregel:

- vis kun achievements for hjemlandet og for lande, som brugeren faktisk har åbne eller allerede har besøgt noget i
- skjul achievements for irrelevante/lukkede lande, så produktet ikke peger mod utopiske mål

### 4. Rækker

Generiske række-achievements, som kan bruges på tværs af alle ligaer.

Eksempler:

- Første stadion i en række
- Halvvejs i en række
- Fuldfør en række
- Fuldfør 3 rækker

Visningsregel:

- fremhæv især rækker i hjemlandet først
- vis internationale række-achievements, når brugeren har åbne lande eller aktiv progression der

### 5. Særlige

Tværgående eller mere legende achievements.

Eksempler:

- Besøg stadion i 3 lande
- Besøg stadion i både top- og lavere rækker
- Playoff-jæger
- Derby-jæger
- Weekendtriple

De bør være krydderi, ikke rygraden i systemet.

## Hvad skal blive i Min tur

`Min tur` bør vise en meget lille, aktiv del af achievement-systemet:

- `Næste achievement`
- `Aktive achievements`
  - 1-2 fra `Rejse`
  - 1 fra `Hjemland`
  - evt. 1 fra `Lande` eller `Rækker`, hvis det er relevant
- små status-tal pr. spor
  - fx `Din rejse`, `Danmark`, `Flere lande`

`Min tur` skal hjælpe brugeren videre nu.
Den skal ikke være et komplet katalog.

## Hvad skal flyttes til en separat achievements-flade

En fremtidig achievements-side bør rumme:

- alle unlocked achievements
- alle locked achievements
- filtrering pr. kategori
- filtrering pr. land
- filtrering pr. række
- evt. “nær ved at unlocke”

Den side er den rigtige løsning, hvis vi vil have mange achievements uden at gøre `Min tur` tung.

## Synlighedsregler

For at gøre systemet mere bevidst og skalerbart bør vi følge disse regler:

### Ny bruger

- fokus på `Rejse` og `Hjemland`
- ingen støj fra irrelevante internationale mål

### Bruger med åbne ekstra lande

- vis `Flere lande`
- vis kun de lande, som faktisk er åbne eller allerede besøgt

### Bruger med premium og mange lande

- stadig begrænset antal aktive achievements i `Min tur`
- resten hører hjemme i achievements-fladen

## Første konkrete roadmap

### Fase 1

- behold `Min tur` som aktiv achievements-flade
- gør `Næste achievement` tydelig
- vis få aktive achievements pr. spor

### Fase 2

- tilføj generiske land-achievements
- tilføj generiske række-achievements
- brug samme model for alle lande

### Fase 3

- byg separat achievements-flade
- flyt den fulde liste ud af `Min tur`

## Beslutning

Achievements bør skaleres som et kategoriseret system, ikke som en længere og længere liste i `Min tur`.

Retningen bør være:

- `Min tur` = retning og motivation
- `Achievements` = samling og dybde

Det gør det muligt at tilføje mange flere achievements for lande og rækker uden at miste fokus i kerneproduktet.
