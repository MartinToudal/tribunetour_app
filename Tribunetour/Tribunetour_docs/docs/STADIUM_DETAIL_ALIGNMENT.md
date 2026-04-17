# Stadium Detail Alignment

Dette dokument er den første konkrete pilot under `UI_CONTRACT.md`.

Målet er at ensrette stadiondetaljen på tværs af app og web, så brugeren møder samme produktlogik og samme historie, selv om layoutet ikke er identisk.

## Hvor vi står nu

### App

Den nuværende stadiondetalje i appen er funktionelt stærk:

- hovedinfo om klub, division, stadion og by
- besøgt-status
- næste kamp
- kommende kampe her
- noter
- billeder
- anmeldelser

Styrke:

- meget direkte og nyttig
- gode personlige funktioner
- næste kamp og kommende kampe er på plads

Svaghed:

- oplevelsen starter lidt som en dataliste
- hero/overblik er relativt svagt
- personlig relevans kommer senere end den burde
- informationshierarkiet føles mere “settings og indhold” end “historie og handling”

### Web

Den nuværende stadiondetalje på web er mere redaktionel:

- tydelig hero
- fakta-chips
- næste kamp som særskilt sektion
- stadionoplysninger
- kommende kampe her
- client-del med personligt indhold længere nede

Styrke:

- god introduktion og orientering
- stærkt førstehåndsindtryk
- tydelige CTA’er

Svaghed:

- personligt indhold er mindre integreret i den første del af oplevelsen
- mere opdelt mellem “offentlig reference” og “min brug”
- næste handling kan være lidt bred i stedet for helt konkret

## Kritisk vurdering

App og web viser næsten de samme informationer, men de gør det i forskellig fortælling.

App siger i praksis:

1. her er stadionet
2. her er status
3. her er kampene
4. her er dit eget indhold

Web siger i praksis:

1. her er stadionets identitet
2. her er næste muligheder
3. her er fakta
4. her er kampene

Det skaber to problemer:

- brugeren lærer ikke helt samme logik
- den personlige værdi er stærkere i appen, mens den redaktionelle værdi er stærkere på web

Den rigtige løsning er ikke at gøre dem ens i pixel. Den rigtige løsning er at lade dem fortælle samme historie i samme rækkefølge.

## Fælles målstruktur

Stadiondetaljen bør på begge platforme følge denne rækkefølge:

1. identitet og status
2. næste bedste handling
3. kommende muligheder
4. personligt indhold
5. fakta og metadata

## Fælles indholdsmodel

### 1. Identitet og status

Skal indeholde:

- klubnavn
- stadionnavn
- by
- liga
- land hvis relevant
- besøgt-status

Brugeren skal på få sekunder forstå:

- hvilket stadion det er
- hvor det hører hjemme
- om det er en del af deres rejse endnu

### 2. Næste bedste handling

Skal normalt være:

- næste kamp på stadionet

Hvis der ikke er en kommende kamp:

- fallback til en mere passiv besked
- eller en alternativ handling som “se alle kampe”

Formålet er, at stadionet ikke kun er et datapunkt, men et sted med en næste oplagt mulighed.

### 3. Kommende muligheder

Skal være en separat sektion med:

- kommende kampe her
- tydelig adgang til kampdetaljer

Denne sektion skal fungere som bro mellem reference og planlægning.

### 4. Personligt indhold

Skal samle brugerens egen relation til stadionet:

- noter
- billeder
- anmeldelser
- evt. besøgsdato

Det personlige indhold må ikke føles som en teknisk rest nederst.
Det er en central del af produktets værdi.

### 5. Fakta og metadata

Skal indeholde:

- koordinater
- intern kode hvis relevant
- evt. andre sekundære metadata

Disse oplysninger er nyttige, men ikke det første brugeren kommer for.

## Før / Efter

### Før: App

Nu:

1. header med klub/division/stadion/by
2. status
3. næste kamp
4. kommende kampe
5. noter
6. billeder
7. anmeldelser
8. fakta spredt implicit i toppen

Problem:

- toppen føles mere som en liste af felter end som en tydelig hero
- status står lidt isoleret fra resten
- personligt indhold er nyttigt, men ikke tydeligt prioriteret som brugerens egen historie

### Efter: App

Foreslået struktur:

1. hero-kort
2. status og besøg
3. næste kamp
4. kommende kampe her
5. min relation til stadion
6. fakta

Det betyder konkret:

- hero-kort med klub, stadion, by, liga og evt. land
- besøgt-status som tydelig del af heroområdet eller lige under
- næste kamp som den første handlingssektion
- noter, billeder og anmeldelser samles under én tydelig overskrift
- koordinater og andre sekundære oplysninger flyttes længere ned

### Før: Web

Nu:

1. hero
2. stats-chips
3. næste kamp
4. fakta
5. kommende kampe
6. client-del med personligt indhold

Problem:

- hero er stærk, men personligt indhold føles mere som noget sekundært
- fakta ligger før brugerens relation til stadionet

### Efter: Web

Foreslået struktur:

1. hero og status
2. næste kamp
3. kommende kampe her
4. min relation til stadion
5. fakta

Det betyder konkret:

- behold den stærke hero
- få besøgt-status og personlig relevans tydeligere op
- flyt “min relation” op før de mere tørre faktafelter

## Konkrete UX-regler

### Hero

Hero skal på begge platforme besvare:

- hvad er dette stadion
- hvor ligger det i pyramiden
- er det en del af min rejse

### CTA-regler

Primær CTA bør normalt være én af:

- `Se næste kamp`
- `Se alle kampe her`
- `Markér som besøgt`

Vi bør undgå for mange lige stærke handlinger i toppen.

### Kampsektioner

`Næste kamp` og `Kommende kampe her` skal være tydeligt adskilt:

- `Næste kamp` er anbefalingen
- `Kommende kampe her` er oversigten

### Personligt indhold

På begge platforme bør sektionen hedde noget i retning af:

- `Min relation til stadion`

Den titel er bedre end at sprede noter, billeder og anmeldelser ud som tre tekniske blokke uden fælles fortælling.

## Foreslået komponentmap

Dette er de komponenter vi bør ende med at have både på web og app:

- `StadiumHero`
- `VisitStatusCard`
- `NextFixtureCard`
- `UpcomingFixturesList`
- `PersonalStadiumContent`
- `StadiumFactsCard`

De behøver ikke hedde det samme i koden, men de skal repræsentere samme logik.

## Hvad vi bør ændre først

### App først

Mindste men mest værdifulde skridt:

1. byg et tydeligere hero-kort
2. saml noter, billeder og anmeldelser under én fælles sektion
3. flyt sekundære fakta længere ned

### Web derefter

Mindste men mest værdifulde skridt:

1. flyt personligt indhold op før fakta
2. gør besøgt-status mere synlig i den første del af siden
3. gør næste kamp til mere tydelig primær handling

## Definition af succes

Vi er lykkedes med stadiondetaljen, når:

- app og web fortæller samme historie i samme rækkefølge
- brugeren hurtigt forstår både stadionets identitet og sin egen relation til det
- næste kamp føles som den naturlige næste handling
- personligt indhold føles som en central del af oplevelsen
- fakta stadig findes, men ikke stjæler fokus
