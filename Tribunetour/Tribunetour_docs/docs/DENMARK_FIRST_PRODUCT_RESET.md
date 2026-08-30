# Danmark-først: produktmål og migrationsplan

Senest opdateret: 2026-08-30

Dette dokument er den styrende beslutning for den næste version af Tribunetour.

Det skal læses før ændringer i navigation, adgang, kampprogrammer, landedata, `Min tur`, achievements eller webdrift.

## 1. Produktbeslutningen

Tribunetour bliver et iOS-produkt med Danmark som tydelig kerne.

Kerneoplevelsen er:

- danske stadions
- danske kampe
- brugerens danske stadionrejse
- frivilligt login med sync af personlige data

Internationalt indhold er et sekundært stadionarkiv:

- alle understøttede lande er tilgængelige for alle
- internationale lande indeholder stadions og klubhistorik, men ikke kampprogrammer
- internationale lande indlæses først, når brugeren vælger dem
- internationale besøg og achievements vises som et tilvalg, ikke som hovedprogression

## 2. Beslutninger der er låst

### Platform

- iOS-appen er den eneste fremtidige produktflade
- webfladen udfases som brugerprodukt
- web-repoet må først lukkes, når nødvendige datajobs, mails og driftsfunktioner er flyttet eller bevidst fjernet

### Konto

- login og sync bevares
- appen kan fortsat bruges uden login
- login skal forklares som backup og sync, ikke som adgang til funktioner

### Adgang

- premium udfases
- alle lande er gratis og tilgængelige for alle
- eksisterende premium-tabeller og adminfunktioner slettes ikke i første migrationstrin
- premium-backend fjernes først, når appen ikke længere afhænger af den, og rollback ikke længere er nødvendig

### Kampprogram

- kun danske kampe vises i produktet
- målet er automatisk opdatering via en stabil datakilde eller API
- appen skal ikke kalde en tredjeparts fodbold-API direkte
- et lille backend-/cachelag skal hente, validere og udstille danske kampe til appen
- nuværende fixture-flow bevares som fallback, indtil API-sporet er valideret

### Navigation

- hovedfaner bliver `Stadions`, `Kampe` og `Min tur`
- `Plan` fjernes som produktflade
- eksisterende plandata slettes ikke under første oprydning

### Min tur og achievements

- hovedtal og hovedprogression handler om Danmark
- international statistik vises som et aktivt tilvalg
- achievements opdeles i danske og internationale spor
- internationale achievements skal ikke fylde den primære `Min tur`-flade

## 3. Fremtidig brugeroplevelse

### Stadions

Ved opstart ser brugeren Danmark med det samme.

Når brugeren vælger et andet land:

1. landets stadionpakke indlæses
2. seneste valide lokale cache vises straks, hvis den findes
3. data kan opdateres i baggrunden
4. landets kort, liste og progression følger valget

Der vises ikke kampprogram for internationale klubber.

### Kampe

`Kampe` er et dansk produktområde.

Det indeholder kun rækker, som vi aktivt understøtter i Danmark. En række må ikke stå som dækket, før både hold og tilgængeligt kampprogram er valideret.

### Min tur

Standardvisningen indeholder:

- besøgte danske stadions
- fremdrift i danske rækker
- næste danske milepæl
- danske achievements
- seneste danske besøg

En sekundær international visning indeholder:

- besøgte lande
- besøgte internationale stadions
- landefremdrift
- internationale achievements

### Konto

Login er frivilligt og giver:

- backup af markeringer
- sync mellem brugerens enheder
- sikker opbevaring af noter, anmeldelser og billeder, hvor sync er understøttet

Login ændrer ikke hvilke lande brugeren må se.

## 4. Målarkitektur

### Appen

Appen skal have tre adskilte dataområder:

1. `DenmarkStadiumStore`
   - indlæses ved opstart
   - indeholder danske klubber og stadions

2. `DenmarkFixtureStore`
   - indlæses asynkront efter den første stadionvisning
   - indeholder kun danske kampe
   - bruger cache og seneste validerede feed

3. `InternationalStadiumStore`
   - indlæser ét valgt land ad gangen
   - indeholder ingen fixtures
   - cacher senest anvendte lande lokalt

Navnene er målbilledet. Eksisterende typer kan migreres gradvist frem for at blive omskrevet på én gang.

### Backend og drift

Et lille driftslag skal på sigt eje:

- hentning af danske fixtures
- normalisering af klubnavne og ids
- validering mod den aktive danske sæson
- publicering af et versionsstyret feed
- status og fejlrapportering

Supabase bevares til:

- login
- sync af brugerdata
- eventuel senere udvidelse af produktet

Web-repoets jobs må gerne være midlertidig vært for fixture-driften, men det skal dokumenteres som overgang og ikke som fremtidig produktarkitektur.

## 5. API-spor for danske kampe

Før vi vælger en leverandør, skal en teknisk prøve bevise:

- dækning af alle danske rækker, vi vil vise
- korrekt sæson og dato
- stabile klub-id'er
- kampflytninger og aflysninger
- rimelige brugs- og visningsrettigheder
- en gratis kvote der kan bruges til en central daglig drift

API-prøven 2026-08-30 gav følgende resultat:

- `football-data.org` dækker Superligaen, men ikke de lavere danske rækker, og Superligaen er ikke blandt turneringerne i den gratis plan
- `TheSportsDB` har dansk ligadata og en gratis API, men vilkårene tillader ikke brug af gratis API-data i en app udgivet gennem App Store
- der er derfor ikke fundet en gratis, lovlig og tilstrækkeligt komplet produktions-API til dansk niveau 1-4

Kilder til beslutningen:

- https://www.football-data.org/coverage
- https://www.football-data.org/pricing
- https://www.thesportsdb.com/docs_api_guide
- https://www.thesportsdb.com/docs_terms_of_use.php

Den nuværende produktionsbeslutning er derfor:

- behold den eksisterende Tribunetour-genererede danske fixturekæde som overgang
- udstil på sigt et separat, versionsstyret dansk feed frem for det fælles europæiske feed
- lad appen validere dansk scope og kamp-id'er før brug
- gem seneste valide danske feed lokalt og brug en dansk bundle som sidste fallback
- behold kildeadapteren, så en senere betalt eller bedre licenseret API kan indføres uden at ændre produktfladen

Hvis ingen gratis API dækker hele det danske scope, skal vi vælge mellem:

- mindre række-scope
- kombination af flere lovlige kilder
- en betalt leverandør

Den beslutning tages på baggrund af en dokumenteret prøve, ikke en antagelse.

## 6. Migration i kontrollerede faser

### Fase 0: Dokumentation og sikkerhed

- lås dette målbillede
- registrer eksisterende driftsafhængigheder i web-repoet
- undgå sletning af brugerdata og fungerende fallback

Færdigt når:

- beslutninger og åbne risici står i backloggen
- hver ændring kan placeres i app, sync eller midlertidig drift

### Fase 1: Enkel iOS-navigation

- fjern `Plan` fra fanebaren
- behold eksisterende plandata midlertidigt
- behold login/sync

Færdigt når:

- appen har tre hovedfaner
- eksisterende build kan åbne uden datatab eller crash

Status 2026-08-26:

- `Plan` er fjernet fra fanebaren
- eksisterende plandata og synckode er bevaret
- ikke-signeret iOS-build er gennemført med succes i Xcode Beta

### Fase 2: Gratis adgang og land-on-demand

- fjern premium-copy og anmodningsflow fra brugerfladen
- gør alle stadionlande valgbare uden login
- indlæs Danmark ved opstart
- indlæs kun valgt internationalt land efter brugerhandling

Færdigt når:

- gæst og logget ind ser samme lande
- opstart indlæser Danmark uden internationale pakker
- landeskift henter og viser det valgte land stabilt

Status 2026-08-29:

- premium-copy, adgangsgates og anmodningsflow er fjernet fra produktfladerne
- alle stadionlande er tilgængelige uafhængigt af login
- login og sync af brugerdata er bevaret
- kun Danmark indlæses ved opstart
- et valgt internationalt land indlæses først ved brugerens valg og bevares i hukommelsen resten af sessionen
- den gamle premium-backend er midlertidigt bevaret som ubrugt rollback-lag
- landvælgeren har en dedikeret navigationsskærm og påvirker ikke hovedlayoutets bredde
- oversigt, landvælger, kortknap og kort er separate responsive rækker; kortets højde følger den tilgængelige bredde
- et land valgt under den indledende Danmark-load køres efterfølgende og kan ikke blive overskrevet af opstarten
- iOS-build og enhedstests er grønne
- UI-automationen gennemfører valg og indlæsning af et internationalt land uden login
- portrait-layoutet er geometrisk verificeret inden for viewporten ved 390, 402 og 440 punkters bredde

### Fase 3: Kun danske fixtures

- filtrer internationale fixtures ud af produktet
- fjern fixture-afhængighed fra internationale stadionpakker
- gennemfør API-prøve og vælg dansk fixturekilde
- indfør versionsstyret dansk fixture-feed med cache og fallback

Færdigt når:

- `Kampe` viser Danmark og intet andet
- internationale stadions kan bruges uden fixtures
- en datakildefejl efterlader seneste valide kampprogram i appen

Status 2026-08-30:

- `Kampe` viser kun Danmark, uanset hvilket stadionland brugeren har valgt
- landefilteret er fjernet fra `Kampe`, og dansk scope er synligt i brugerfladen
- remote-, cache- og bundledata valideres mod det danske klubscope og deduplikeres før brug
- en vellykket remote-opdatering gemmes som seneste kendte valide danske version
- ved remote-fejl bruges først den gemte version og derefter en separat dansk bundle med 782 fixtures
- den tidligere sammenblanding af remote-data og potentielt forældede bundlekampe er fjernet
- API-prøven er afsluttet uden en egnet gratis produktionsleverandør til niveau 1-4
- enheds- og UI-regressionstests er grønne
- åbent: publicer et separat dansk remote-feed og fjern dubletter i produktionsgeneratoren

### Fase 4: Danmark-først progression

- ombyg `Min tur` til dansk standardvisning
- flyt international statistik til en sekundær visning
- del achievements op i danske og internationale spor

Færdigt når:

- hovedprogression aldrig blandes med internationalt scope
- internationale resultater stadig kan findes bevidst

### Fase 5: Kontrolleret afvikling af webproduktet

- fjern offentlig webnavigation og produktfunktioner
- bevar eller flyt nødvendige fixturejobs og kontrolværktøjer
- beslut fremtidig placering af den manuelle klubkontrol
- arkiver webkode, når ingen drift afhænger af den

Færdigt når:

- ingen aktiv brugerrejse kræver web
- alle tilbageværende jobs har en navngiven ejer
- web-repoet kan arkiveres uden at stoppe app, sync eller fixtureopdatering

## 7. Arbejdsproces for hver ændring

Alle ændringer følger:

1. UX-afklaring
2. arkitekturpåvirkning
3. product owner-scope og acceptkriterier
4. udvikling
5. dokumentation
6. test
7. tydelig leverancestatus

Leverancestatus skal altid sige:

- hvilket repo der er ændret
- om ændringen er committed og pushed
- om den kræver backend-deploy
- om den kræver ny TestFlight-build

## 8. Åbne beslutninger

Disse punkter kræver direktør-/slutbrugerbeslutning, når vi når dem:

- præcis hvilke danske rækker fixture-API'en skal dække i første version
- om den manuelle klubkontrol skal være et internt iOS-område eller et lille separat driftsværktøj
- hvornår gammel premium-backend må slettes permanent
- hvornår webdomænet skal lukkes, omdirigeres eller bruges som enkel App Store-landingsside
