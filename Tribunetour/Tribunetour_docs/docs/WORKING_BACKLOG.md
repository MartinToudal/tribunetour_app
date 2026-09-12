# Tribunetour Backlog

Senest opdateret: 2026-09-12

Dette er den operative backlog og den fælles arbejdssandhed for projektet. Arbejdet registreres som:

- **Epic**: et større produkt- eller arkitekturområde.
- **Story**: en konkret leverance, der kan planlægges og afsluttes.
- **Subtask**: en afgrænset opgave, der kan markeres med flueben.

Status bruges konsekvent:

- `Åben`: ikke startet.
- `I gang`: aktivt arbejde.
- `Afventer`: kræver en ekstern beslutning eller datakilde.
- `Færdig`: implementeret, testet og dokumenteret.
- `Udskudt`: bevidst parkeret.

## Produktbeslutninger

Disse beslutninger er gældende, indtil de ændres eksplicit:

- iOS er den primære produktflade.
- Danmark er kerneproduktet.
- Login og sync bevares.
- Premium udfases, og funktioner er gratis.
- Kampprogrammet omfatter kun danske kampe.
- Internationale lande omfatter primært stadions og indlæses efter valg.
- `Plan` er fjernet fra produktet.
- Web er ikke en brugervendt produktflade.
- Web må kun bruges internt til admin- og driftsværktøjer som Klubtjek og backlog.
- Nødvendige backend-jobs, feeds, audits og API'er bevares, uanset om de ligger i web-repositoriet.

## Værdibaseret epic-struktur

De eksisterende stories nedenfor bevares, men vurderes fremover inden for disse overordnede værdiepics. Formålet er at prioritere efter den effekt, Tribunetour skal skabe, ikke efter mængden af kode eller dataarbejde.

### Værdiepic A – Gør stadionturen bedre

**Værdi:** Brugeren skal hurtigt kunne finde relevante stadions, forstå sit scope og få lyst til at tage næste tur.

**Indhold:** Story 1.1, Story 1.2, Story 1.4 og den brugerrettede del af Story 8.1-8.2.

### Værdiepic B – Gør Danmark komplet og brugbart

**Værdi:** Danmark skal være et troværdigt hovedprodukt, hvor brugeren kan udforske hele pyramiden og stole på klub-, række- og stadiondata.

**Indhold:** Story 1.3, Story 2.1-2.2, Story 3.1-3.2 og Story 9.1.

### Værdiepic C – Skab en troværdig datamotor

**Værdi:** Rettelser skal kunne gennemføres én gang, kontrolleres, spores og slå igennem konsekvent i appen uden gentagne manuelle lapninger.

**Indhold:** Story 3.3-3.4, Story 4.2-4.4 og den tekniske del af Story 8.1-8.2.

### Værdiepic D – Gør drift og feedback håndterbar

**Værdi:** Vi skal kunne opdage fejl, behandle forslag og holde systemet sundt uden at være afhængige af chat-hukommelse eller ad hoc-arbejde.

**Indhold:** Story 5.1-5.2, Story 6.1-6.3 og Story 7.1.

### Værdiepic E – Udvid rækkevidden kontrolleret

**Værdi:** Flere lande, UEFA-turneringer og danske niveauer skal øge oplevelsen uden at gøre data, performance eller drift ustabil.

**Indhold:** Story 8.1-8.2 og Story 9.1, efter at datamotoren og scope-modellen er robuste.

### Værdiepic F – Udgiv en stabil løsning

**Værdi:** Brugeren skal opleve en stabil app, og vi skal kunne udgive ændringer med forudsigelig risiko.

**Indhold:** Story 10.1 samt release-, performance- og platformspunkter fra Story 1.1, Story 2.1-2.2 og Story 6.3.

### PO-vurdering før næste større leverance

For hvert åbent item skal vi dokumentere:

- Hvilket brugerproblem løser det?
- Hvem får værdien?
- Hvad bliver konkret bedre i brugerens oplevelse eller i driften?
- Hvordan kan vi se, at værdien er opnået?
- Hvad er den mindste løsning, der kan teste værdien?
- Hvilke eksisterende problemer eller gamle backlogpunkter afhænger det af?

Ingen nye større epics startes, før de åbne punkter er vurderet efter denne model.

## EPIC 1 – Danmark-først produkt

### Story 1.1 – Enkel navigation

**Status: Færdig**

- [x] Fjern `Plan` fra fanebaren.
- [x] Behold plandata og sync midlertidigt af hensyn til rollback.
- [x] Gør fixture-indlæsningen robust over for dublerede kamp-ID'er.
- [x] Verificer tre hovedfaner og grønt iOS-build.

**Accept:** Appen har tre hovedfaner og starter uden fixture-relateret crash.

### Story 1.2 – Gratis adgang og land-on-demand

**Status: Færdig**

- [x] Fjern premium-copy, gates og anmodningsflow fra brugerfladen.
- [x] Gør alle stadionlande tilgængelige uden login.
- [x] Indlæs kun Danmark ved opstart.
- [x] Indlæs valgt internationalt land efter brugerhandling.
- [x] Beskyt Danmark-load mod at blive overskrevet af et tidligt landeskift.
- [x] Verificer portrait-geometri ved 390, 402 og 440 punkters bredde.

**Accept:** Gæst og logget ind bruger har samme landescope, og opstarten indlæser ikke hele Europa.

### Story 1.3 – Kun danske kampe

**Status: Færdig**

- [x] Fjern internationale fixtures fra produktet og lokal fallback.
- [x] Fjern landevalg fra `Kampe` og gør dansk scope synligt.
- [x] Gennemfør API-prøve uden produktionskobling.
- [x] Indfør validering, deduplikering, senest-kendt-god cache og dansk fallback.
- [x] Publicer separat versionsstyret dansk remote-feed.
- [x] Håndter dublerede kamp-ID'er strukturelt.

**Accept:** `Kampe` viser kun Danmark og overlever fejl hos datakilden.

### Story 1.4 – Danmark-først Min tur og achievements

**Status: Færdig**

- [x] Gør dansk statistik, progression og anbefalinger til standard.
- [x] Flyt international statistik til et eksplicit scopevalg.
- [x] Lad noter, anmeldelser og billeder følge valgt scope.
- [x] Beregn achievements ud fra aktivt scope.
- [x] Gennemgå achievement-navne, milepæle og rækkefølge med product owner.

**Accept:** Internationale tal blandes ikke ind i dansk hovedprogression.

## EPIC 2 – Fixture-drift og danske datakilder

Dette epic handler om den automatiske fixture-kontrol, der afvikles via GitHub Actions. Det er adskilt fra det manuelle Klubtjek i Epic 4.

### Story 2.1 – Officiel dansk fixture-kilde

**Status: I gang**

- [x] Afprøv API-Football og fravælg den gratis plan, fordi 2026-sæsonen ikke er tilgængelig.
- [x] Byg read-only adapter til den offentlige kilde bag de officielle danske sider.
- [x] Hent hele sæsonen, ikke kun synlige eller paginerede kampe.
- [x] Indfør sæsonår, datofilter, deduplikering og stop ved ufuldstændigt svar.
- [x] Sammenlign hold, kamp-ID, kickoff, flytninger, aflysninger og manglende kampe.
- [x] Log fetch-, schema- og komplethedsfejl.
- [x] Kør officiel kilde og nuværende feed parallelt i observationsperioden.
- [x] Behold Flashscore som midlertidig fallback.
- [ ] Afslut observationsperioden efter dokumenteret stabil drift.
- [ ] Fjern Flashscore-fallback og gamle danske checks efter godkendt observationsperiode.

**Accept:** Et komplet dansk kampprogram kan opdateres ugentligt fra den officielle kilde uden direkte appkald.

### Story 2.2 – Stabil fixture-monitorering

**Status: I gang**

- [ ] Begræns dagligt fixture-check til danske rækker.
- [ ] Skeln tydeligt mellem `added`, `changed`, `removed` og uændret data.
- [ ] Afvis gamle sæsoner og kampe uden for det aktuelle datovindue.
- [ ] Håndter slutspil og sæsonskifte uden at genindføre gamle kampe.
- [ ] Gør rapporter korte og handlingsorienterede.
- [ ] Dokumenter root cause, når en række fejler.

**Accept:** En daglig rapport viser kun relevante danske afvigelser og skaber ikke falske fejl på gamle eller foreløbige kampe.

## EPIC 3 – Stadions, lande og sæsonhistorik

### Story 3.1 – Korrekte stadiondata

**Status: I gang**

- [ ] Gennemgå land og række én ad gangen.
- [ ] Verificer koordinater for hvert stadion.
- [ ] Verificer klubnavn, stadionnavn og by.
- [ ] Verificer rækketilhør pr. sæson.
- [ ] Registrer ændringer med kilde og kontroltidspunkt.

**Accept:** Hvert aktivt stadion har verificerede koordinater og dokumenteret klub-/rækketilhør.

### Story 3.2 – Sæsonskifte og historik

**Status: I gang**

- [ ] Bevar historisk rækketilhør pr. klub og sæson.
- [ ] Adskil aktuelle rækker fra historiske og nedlagte/udtrådte rækker.
- [ ] Placer hold, der forlader ligasystemet, i en arkivrække.
- [ ] Understøt mange sæsoner uden at ændre tidligere historik.
- [ ] Verificer, at kort og aktive scopes ikke viser arkiverede hold.

**Accept:** En klub kan vises med alle kendte rækker siden Tribunetour startede, mens kun aktuelle hold tæller i aktive landescope.

### Story 3.3 – Landepakker og foreløbige grupper

**Status: Afventer**

- [ ] Afslut endelig Serie C-fordeling i Italien.
- [ ] Afslut eller dokumenter foreløbige grupper i Portugal niveau 3.
- [ ] Afslut eller dokumenter foreløbige grupper i Spanien Primera Federación.
- [ ] Kvalitetstjek Frankrigs niveau 3.
- [ ] Hold alle nye landepakker adskilt pr. land, niveau og sæson.

**Accept:** Foreløbige grupper er tydeligt markeret og kan udskiftes uden at beskadige historik eller stadiondata.

### Story 3.4 – Brugerindsendte manglende stadions

**Status: Afventer, prioritet middel**

- [ ] Giv en logget bruger mulighed for at indsende et manglende stadion.
- [ ] Kræv klub, række, by, koordinater og en kort beskrivelse af grundlaget.
- [ ] Markér indsendelsen som forslag, indtil den er kontrolleret.
- [ ] Understøt billede eller link som dokumentation uden at gøre det til automatisk sandhed.
- [ ] Lad admin godkende, afvise eller bede om flere oplysninger.
- [ ] Opret en historik over indsender, tidspunkt, beslutning og eventuelle rettelser.
- [ ] Publicér først godkendte stadions i den relevante landepakke og det centrale scope.
- [ ] Beskyt mod dubletter, ugyldige koordinater, spam og uautoriserede rækkevalg.

**Accept:** En bruger kan foreslå et manglende stadion, men det bliver først en del af den aktive stadionoversigt efter sporbar admin-godkendelse.

## EPIC 4 – Manuel klubkontrol

### Story 4.1 – Daglig klubkontrol

**Status: Færdig, første version**

- [x] Generér tre tilfældige klubber dagligt.
- [x] Vis kontrol af danske kampprogrammer.
- [x] Vis kontrol af stadionplacering og koordinater for alle lande.
- [x] Vis kontrol af rækketilhør og sæson.
- [x] Gør koordinater og række redigerbare.
- [x] Gem lokal historik og understøt eksport.
- [x] Begræns værktøjet til logget admin.
- [x] Begræns den aktuelle admin-allowlist til `martin@toudal.dk` og Supabase-adminstatus.
- [x] Begræns fixture-visningen i Klubtjek til danske kampe; internationale fixtures må ikke vises som kontrolgrundlag.

**Accept:** Admin kan gennemføre en daglig stikprøve uden klargøring, og kontrolindholdet er ikke synligt for andre brugere.

### Story 4.2 – Central lagring og godkendelse af klubtjek

**Status: Åben, prioritet høj**

- [x] Implementér Supabase-schema for kontroller, ændringsforslag og auditstatus.
- [x] Implementér sikker RPC til at gemme en kontrol og oprette ændringsforslag.
- [x] Implementér sikker RPC til eksplicit godkendelse og opdatering af central `stadiums`-data.
- [x] Kobl Klubtjek på den centrale save-kæde i web-koden.
- [x] Kør Supabase-migrationen på produktionsprojektet.
- [x] Gem kontroller centralt med bruger, tidspunkt, klub, kontroltype, resultat og noter i review-modellen.
- [x] Opret koordinat- og rækkeændringer som ændringsforslag.
- [x] Gem gammel værdi, ny værdi, kilde og status for hvert forslag.
- [x] Kræv eksplicit admin-godkendelse før stamdata ændres.
- [x] Lad admin godkende en rettelse direkte i Klubtjek.
- [x] Skriv godkendte koordinat- og rækkeændringer til den centrale `stadiums`-database.
- [ ] Publicér eller synkronisér godkendte rettelser til appens fælles datakilde.
- [ ] Vis komplet historik pr. stadion og kontroltype.
- [ ] Understøt afvisning og opfølgning uden at miste oprindelig kontrol.
- [x] Deploy web-koden med den centrale save-kæde.
- [x] Verificér at en central kontrol kan gemmes for en udenlandsk klub fra en league-pack; Westerlo blev gemt succesfuldt centralt og lokalt.
- [x] Verificér RPC-adgang med `martin@toudal.dk` gennem en ægte koordinatændring på Westerlo; review og begge forslag blev godkendt centralt.

**Accept:** Når admin retter og godkender koordinat eller rækketilhør i Klubtjek, gemmes ændringen i den centrale database med audit-log og kan efterfølgende verificeres i appen.

### Story 4.3 – Central distribution af godkendte stamdata

**Status: Afventer, prioritet høj**

- [ ] Fastlæg én autoritativ model for klubidentitet, stadion, aktiv række, sæson og historiske medlemskaber.
- [ ] Definér precedence mellem bundne landepakker, centrale stamdata og godkendte Klubtjek-overrides.
- [ ] Publicér godkendte koordinat- og rækkeændringer i en versioneret, central datakilde.
- [ ] Lad godkendte ændringer udløse en kontrolleret publicerings- eller synkroniseringsproces automatisk.
- [ ] Sørg for at en godkendt rækkefejl opdaterer klubbens aktive række uden at slette historikken.
- [ ] Lad iOS-appen hente centrale rettelser og lægge dem oven på den indbyggede fallback-data.
- [ ] Bevar offline- og fallback-adfærd, hvis den centrale datakilde ikke kan nås.
- [ ] Valider ændringer før publicering, herunder gyldig klub, række, land og sæson.
- [ ] Log version, tidspunkt, kilde, godkendelse og resultat for hver publicering.
- [ ] Understøt rollback, hvis en godkendt rettelse viser sig at være forkert.
- [ ] Test end-to-end med Carpi: forkert Serie C-række rettes i Klubtjek, godkendes centralt og vises korrekt i appen.

**Accept:** En admin-godkendt ændring af koordinater eller aktiv række bliver automatisk valideret, publiceret og synlig i appen uden en ny TestFlight-release, mens klubbens historik bevares.

### Story 4.4 – Automatisk komplet rækkegennemgang

**Status: Afventer, prioritet høj**

- [ ] Registrér når en godkendt ændring påvirker en klubs aktive række.
- [ ] Udløs automatisk en komplet audit af den berørte række, ikke kun af den rettede klub.
- [ ] Kontrollér holdliste, række, sæson, stadiondata og relevante fixtures i samme audit.
- [ ] Saml auditresultatet med den oprindelige Klubtjek-kontrol og den udløsende ændring.
- [ ] Gør auditten idempotent, så samme ændring ikke starter gentagne kørsler.
- [ ] Send kun en notifikation ved fejl, nye afvigelser eller behov for adminbeslutning.
- [ ] Understøt genkørsel efter manuel rettelse eller ændret kildedata.

**Accept:** En godkendt rækkefejl starter automatisk én komplet, sporbar audit af den berørte række, og resultatet kan følges fra Klubtjek.

## EPIC 5 – Backlog og intern drift

### Story 5.1 – Jira-lignende admin-backlog

**Status: Åben, prioritet middel**

- [ ] Genbrug admin-login og samme admin-allowlist som Klubtjek.
- [ ] Vis epics, stories og subtasks i en samlet oversigt.
- [ ] Understøt status, prioritet, ansvarlig og seneste ændring.
- [ ] Gør subtasks afkrydsbare direkte i UI.
- [ ] Vis åbne, igangværende, afventende, færdige og udskudte items.
- [ ] Link backlog-items til dokumentation, kontrolhistorik og relevante deploys.
- [ ] Gem ændringer centralt, så UI og Markdown ikke udvikler sig til to sandheder.
- [ ] Bevar Markdown som eksport, backup og versionshistorik.

**Arkitektur:** Backloggen skal være et adminværktøj i web-driftslaget, ikke en offentlig del af iOS-appen. Supabase bør være den autoritative lagring, mens Markdown genereres eller eksporteres derfra.

**Accept:** Admin kan planlægge, opdatere og afslutte arbejde fra én side uden at miste historik eller skabe en parallel backlog.

### Story 5.2 – Systemoverblik og ændringsprotokol

**Status: I gang**

- [ ] Vedligehold systemkort for iOS-app, web-driftslag, Supabase og fixture-pipeline.
- [ ] Dokumentér source of truth for stadiondata, fixtures, kontroller og backlog.
- [ ] Kræv UX-afklaring, arkitekturgennemgang, PO-beslutning, udvikling, dokumentation og test for større ændringer.
- [ ] Registrér repo, commit, deploy og verifikation for hver leverance.
- [ ] Undgå at beskrive app- og web-status som én samlet status, før begge er verificeret.

**Accept:** En ny session kan forstå arkitekturen, aktive risici og seneste leverancer uden at rekonstruere historikken fra chatten.

## EPIC 7 – Feedback og forslag

### Story 7.1 – Feedbackindbakke og triage

**Status: Afventer, prioritet middel**

- [ ] Byg en enkel feedbackfunktion til fejl, dataforslag og nye feature-idéer.
- [ ] Kræv kontekst i indsendelsen: skærm, klub/række, beskrivelse og eventuelt billede.
- [ ] Gem feedback centralt med bruger, tidspunkt, status og relaterede dataobjekter.
- [ ] Klassificér feedback som entydig lavrisiko-fejl, datakontrol, uklar sag eller featureforslag.
- [ ] Lad entydige lavrisiko-fejl gå til en sikker automatisk rettelses- eller auditkø.
- [ ] Kræv admin-godkendelse før ændringer med højere risiko publiceres.
- [ ] Send notifikation med resultatet, når en fejl er rettet, afvist eller kræver mere information.
- [ ] Opret featureforslag som backlog-items til kort PO-afklaring før udvikling.
- [ ] Link feedback, rettelse, audit, commit og deploy, så hele forløbet kan spores.
- [ ] Beskyt mod spam, dubletter og uautoriserede ændringer.

**Accept:** En bruger kan sende et forslag ind, og systemet kan føre det gennem triage, sikker rettelse eller PO-afklaring med sporbar status og passende notifikation.

## EPIC 6 – Internt web- og driftslag

### Story 6.1 – Lukket admin- og driftsweb

**Status: I gang**

- [x] Beslut at web ikke skal være en brugervendt visningsflade.
- [x] Begræns Klubtjek til logget admin.
- [ ] Kortlæg jobs, feeds, audits og adminværktøjer, der fortsat kræver web-repositoriet.
- [ ] Bevar login/sync i Supabase.
- [ ] Adskil interne adminruter fra eventuelle resterende offentlige ruter.
- [ ] Flyt eller behold nødvendige backend-funktioner i en dokumenteret permanent driftsplacering.
- [ ] Beslut endelig host- og deploymodel.
- [ ] Fjern offentlig webvisning, når iOS og driftslaget er uafhængige.

**Accept:** Brugere møder ingen webbaseret produktvisning, mens admin kan bruge nødvendige kontrol- og driftsværktøjer sikkert.

### Story 6.2 – Oprydning i Supabase efter scope-reduktion

**Status: Afventer, prioritet høj**

- [ ] Kortlæg tabeller, views, RPC’er, jobs, secrets og policies, der vedrører internationale fixtures og udfasede premium-/webflows.
- [ ] Skeln mellem data, der skal slettes, arkiveres eller bevares af hensyn til historik og login/sync.
- [ ] Fjern eller deaktiver gamle fixture-tabeller, funktioner og jobs, der ikke længere er i scope.
- [ ] Bevar danske fixturedata og nødvendige audit-/Klubtjekdata.
- [ ] Ryd op i forældede RLS-politikker og serviceadgange efter ændringerne.
- [ ] Tag dokumenteret backup eller eksport før destruktive ændringer.
- [ ] Kør efterkontrol af app-sync, Klubtjek, danske fixtures og login efter oprydningen.
- [ ] Dokumentér den endelige Supabase-struktur som source of truth.

**Accept:** Supabase indeholder kun aktive og historisk nødvendige dele af løsningen, uden at login, sync, danske fixtures eller Klubtjek brydes.

### Story 6.3 – GitHub- og repository-hygiejne

**Status: Afventer, prioritet middel**

- [ ] Lav et samlet inventar over app- og web-repositories, branches, workflows, secrets og production-forbindelser.
- [ ] Identificér branches, der er merged, forældede eller kun indeholder midlertidige snapshots.
- [ ] Kontrollér lokale branches og utrackede filer, før de fjernes eller arkiveres.
- [ ] Gennemgå workflows for overlap mellem daily fixture-check, fixture-audit og manuelle admin-kontroller.
- [ ] Bevar kun workflows, der har en dokumenteret funktion i den aktuelle arkitektur.
- [ ] Opdatér actions til understøttede runtime-versioner, når kompatible versioner findes.
- [ ] Ryd op i midlertidige branches og arbejdsfiler efter eksplicit verifikation.
- [ ] Dokumentér production-branch, deploykilde og rollback-procedure.
- [ ] Bekræft at oprydning ikke ændrer `main`, Supabase, Vercel eller App Store-buildflowet.

**Accept:** Begge repositories har en dokumenteret, minimal og forståelig branch-/workflowstruktur, mens production og rollback fortsat kan verificeres.

## EPIC 8 – Europæiske turneringer og stadion-scope

### Story 8.1 – UEFA-turneringer som valgbart scope

**Status: Afventer, prioritet middel**

- [ ] Tilføj `Champions League` som valgbart stadion-scope.
- [ ] Tilføj `Europa League` som valgbart stadion-scope.
- [ ] Tilføj `Conference League` som valgbart stadion-scope.
- [ ] Definér om scope viser klubber med deltagelse i den aktuelle sæson eller historisk deltagelse.
- [ ] Vis kun stadiondata i scope; internationale kampe skal ikke genindføres i produktets kampprogram.
- [ ] Håndtér kvalifikation, gruppespil og ændringer i turneringsdeltagere uden at miste historik.
- [ ] Gør scope-valget eksplicit og adskilt fra brugerens danske hovedscope.

**Accept:** Brugeren kan vælge en UEFA-turnering og få et korrekt, rent stadionoverblik uden at internationale fixtures blandes ind i Kampe.

### Story 8.2 – Europæiske hold som stadion-scope

**Status: Afventer, prioritet middel**

- [ ] Tilføj et samlet scope for europæiske hold og stadions.
- [ ] Definér hvilke UEFA-lande og aktive sæsoner der indgår.
- [ ] Bevar landefiltre, så det samlede scope kan afgrænses uden at ændre stamdata.
- [ ] Indlæs scope efter brugerens valg og behold Danmark som hurtig standard.
- [ ] Undgå at arkiverede eller udtrådte hold tæller som aktive i scope-statistik.

**Accept:** Brugeren kan udforske europæiske stadions samlet, mens Danmark fortsat er standard og aktive/arkiverede hold behandles korrekt.

## EPIC 9 – Udvidet dansk fodboldpyramide

### Story 9.1 – Valgbare danske niveauer

**Status: Afventer, prioritet middel**

- [ ] Udvid Danmark med niveau 5.
- [ ] Udvid Danmark med niveau 6.
- [ ] Udvid Danmark med niveau 7.
- [ ] Udvid Danmark med niveau 8.
- [ ] Udvid Danmark med niveau 9.
- [ ] Udvid Danmark med niveau 10.
- [ ] Udvid Danmark med niveau 11.
- [ ] Udvid Danmark med niveau 12.
- [ ] Tilføj et samlet valg for hele Danmark.
- [ ] Lad brugeren vælge ét eller flere niveauer uden at ændre det danske standard-scope.
- [ ] Dokumentér datakilder, klubantal, stadionkvalitet og sæson for hvert nyt niveau.
- [ ] Håndtér klubber uden verificerede koordinater tydeligt uden at blokere resten af Danmark.
- [ ] Kontrollér at niveauvalg påvirker kort, stadionliste, statistik og achievements ensartet.

**Accept:** Brugeren kan vælge niveau 1-12 eller hele Danmark, og alle visninger bruger samme valgte scope.

## EPIC 10 – App Store-release

### Story 10.1 – Release efter macOS-beta-afhængighed

**Status: Afventer, prioritet høj**

- [ ] Vent med upload, indtil Mac’en er tilbage på stabil macOS/Xcode.
- [ ] Verificér stabilt archive- og signing-flow uden beta-SDK.
- [ ] Kør regressionstest af opstart, landescope, kort, Klubtjek-relateret sync og Kampe.
- [ ] Bekræft versionsnummer, buildnummer og App Store-release notes.
- [ ] Upload til App Store Connect og gennemfør den endelige releasekontrol.
- [ ] Dokumentér release-version, dato og testresultat i systemoverblikket.

**Accept:** Den samlede iOS-løsning kan uploades og godkendes til App Store fra stabil macOS/Xcode uden beta-relaterede uploadfejl.

## Aktive risici

- App og web er fortsat to repositories. Der skal altid angives, hvilket repo en ændring vedrører.
- Klubtjek gemmer centralt og lokalt; godkendte rettelser slår endnu ikke automatisk igennem i appens stamdata.
- Det automatiske Fixture Check er en separat GitHub-kørsel og må ikke blandes sammen med adminens manuelle Klubtjek.
- Web-backendets samlede fixture-feed indeholder fortsat internationale kampe, og Klubtjek bruger endnu denne samlede fil i stedet for det danske fixture-feed.
- Fixture-kildeovergangen er endnu i observationsperiode med Flashscore som fallback.
- Flere landes grupper er foreløbige eller mangler endelig kvalitetssikring.
- Web-deploy bygger mange statiske sider og kan derfor tage betydelig tid; det skal reduceres, når offentlig webvisning fjernes.

## Næste anbefalede rækkefølge

1. Gennemfør PO-vurdering af alle åbne items efter værdimodellen.
2. Gennemfør App Store-release, når Mac’en er tilbage på stabil macOS/Xcode.
3. Færdiggør central distribution af godkendte stamdata til appen.
4. Udløs komplet rækkegennemgang automatisk efter godkendte rækkeændringer.
5. Stabiliser og afslut observationsperioden for danske fixtures.
6. Ryd op i Supabase og GitHub efter den besluttede scope-reduktion.
7. Gennemgå stadiondata land for land.
8. Byg feedbackindbakke og admin-backlog oven på samme centrale driftsmodel.
9. Udvid Danmark med valgbare niveau 5-12 og hele Danmark.
10. Udvid stadion-scope med UEFA-turneringer og europæiske hold.
11. Byg sikker indsendelse og godkendelse af manglende stadions.
12. Luk offentlig webvisning, når driftslaget er dokumenteret og stabilt.
