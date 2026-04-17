# Map UI Review

Dette dokument samler den kritiske UX-vurdering af kortfunktionen på tværs af app og web.

Målet er at forstå:

- hvor kortet fungerer godt i dag
- hvor det allerede er presset
- hvad der bliver et problem, når flere lande kommer på
- hvilken retning vi bør tage for at gøre kortet skalerbart

## Kort konklusion

Kortet fungerer i dag som en nyttig supplementær visning, men det er endnu ikke en skalerbar oplevelse til flere lande.

Det største problem er ikke teknikken. Det er informationsmængden og manglen på tydeligt hierarki.

Når flere lande aktiveres, bliver kortet hurtigt:

- visuelt støjende
- sværere at forstå
- mindre nyttigt som beslutningsværktøj
- mere et “data-lag” end en hjælpsom produktflade

## Kritisk vurdering af app-kortet

### Styrker

- kortet ligger tæt på den primære stadiumliste
- mini-kortet i bunden giver hurtig handling
- visited-status er synlig direkte på pins
- det er let at hoppe videre til detalje eller Apple Maps

### Svagheder

- mange pins giver hurtigt visuelt rod
- pin-labels med klubnavn oven over pin presser kortet meget
- der er ikke nok visuel prioritering mellem “vigtigt nu” og “alt”
- kortet er stadig mere en rå oversigt end en guidet oplevelse
- landefilteret ligger i samme menulogik som øvrige listefiltre og føles ikke som et særligt “scope”-valg

### Særligt problem ved flere lande

Når flere lande aktiveres, bliver `zoomToFitAll()` hurtigt upræcist.

Kortet risikerer at:

- zoome så langt ud, at pins mister mening
- få for mange overlappende annotationer
- gøre det svært at bruge mini-kortet som relevant “næste handling”

## Kritisk vurdering af web-kortet

### Styrker

- hero og introduktion er tydeligere end i appen
- country-filteret er mere synligt
- popups er enkle og forståelige
- de fremhævede stadium-kort under kortet er en god bro mellem kort og indhold

### Svagheder

- kortet er meget højt og meget dominerende
- Leaflet-markers bliver hurtigt tætte og uoverskuelige
- `Alle` + mange lande vil blive for bredt som standardvisning
- brugeren får ikke tydeligt hjælp til hvad kortet er bedst til
- de fremhævede kort under kortet er kun de første 6 stadioner, ikke nødvendigvis de bedste eller mest relevante

### Særligt problem ved flere lande

Web-kortet er endnu mere sårbart over for mange pins end appen, fordi:

- der ikke er clustering
- alle marker er visuelt meget ens
- center/zoom er meget groft baseret på landekode
- kortet bliver hurtigt et “se alt på én gang”-værktøj, som mister værdi

## Fælles hovedproblemer

### 1. For mange ting på samme niveau

Alle pins er næsten lige vigtige.

Der mangler prioritering mellem:

- ubesøgte vs besøgte
- nærmeste vs fjerne
- aktive muligheder vs bare referencepunkter

### 2. Scope er ikke stærkt nok

Når flere lande kommer til, er det ikke nok bare at have “alle” og et landefilter.

Kortet skal forstå scope som en central del af oplevelsen, ikke som en sekundær kontrol.

### 3. Kortet hjælper ikke nok med beslutning

I dag svarer kortet mest på:

- “hvor ligger stadions”

Det burde i højere grad hjælpe med:

- “hvad er næste oplagte stadion”
- “hvilke stadions er relevante i mit aktive scope”
- “hvad er tæt på mig eller min næste rejse”

### 4. Visuel støj bliver værre med vækst

Flere lande betyder:

- flere pins
- større geografisk område
- mere behov for zoom- og clustering-logik
- større risiko for at kortet mister fokus

## Farver og visuel retning

Brugerens observation er vigtig: web har i dag en pænere og mere sammenhængende farveretning end appen.

Det har betydning for kortet, fordi kortet er ekstra følsomt over for:

- kontrast
- badge-farver
- pin-hierarki
- lag mellem baggrund, kontroller og informationskort

Min vurdering er:

- web bør være reference for den mere modne visuelle retning
- app-kortet bør løftes tættere på den samme brandfølelse
- farverne skal bruges mere semantisk

Det betyder især:

- visited skal have én tydelig farverolle
- “næste mulighed” eller anbefalet stadion bør kunne få sin egen accent
- kort-overlays og mini-kort skal bruge bevidste surfaces i både light og dark mode

## Anbefalet retning

Kortet bør udvikle sig fra:

- “vis alle stadions på et kort”

til:

- “hjælp mig med at udforske relevante stadions i mit aktuelle scope”

Det er en vigtig forskel.

## Fremtidig model for kortet

### Lag 1: Scope først

Kortet skal først og fremmest tage udgangspunkt i:

- hjemland
- aktive lande/pakker
- evt. kun ubesøgte

Standardvisningen bør ikke nødvendigvis være “alle”.

### Lag 2: Prioriterede pins

Pins bør på sigt have tydeligere hierarki:

- anbefalede eller relevante
- ubesøgte
- besøgte

Det kan ske via:

- farve
- størrelse
- clustering
- sekundær fading

### Lag 3: Relevanspanel

Kortet bør ledsages af en tydelig liste eller panel med de mest relevante stadions i den aktuelle visning.

Ikke bare de første 6.
Men fx:

- nærmeste
- næste oplagte
- ubesøgte i dette område

### Lag 4: Zoomstrategi

Når flere lande er aktive, skal kortet ikke bare zoome ud til alt.

Det bør i stedet:

- starte i hjemland eller valgt scope
- evt. have hurtig skift mellem områder
- undgå at “hele Europa” bliver defaultoplevelsen

## Konkrete anbefalinger

### App

1. Gør kortet til en mere tydelig “udforsk”-sektion
2. Reducér visuel støj i annotationerne
3. Bevar mini-kortet, men gør det mere relevant for det valgte scope
4. Overvej på sigt clustering eller enklere pin-visning uden altid-synlige labels

### Web

1. Behold intro og cards under kortet
2. Gør kortets underliste mere relevant og ikke bare de første 6
3. Indfør bedre default-scope end “alt”
4. Overvej clustering før endnu flere lande

## Definition af succes

Kortoplevelsen er lykkedes, når:

- brugeren forstår hvilket scope kortet viser
- kortet hjælper med at finde næste relevante stadion
- visningen ikke kollapser, når flere lande aktiveres
- app og web føles som samme produktlogik
- farver og overlays føles bevidst designet, ikke tilfældigt systemstyrede
