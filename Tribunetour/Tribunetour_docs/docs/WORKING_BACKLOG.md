# Tribunetour Backlog

Senest opdateret: 2026-09-05

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
- [ ] Begræns fixture-visningen i Klubtjek til danske kampe; internationale fixtures må ikke vises som kontrolgrundlag.

**Accept:** Admin kan gennemføre en daglig stikprøve uden klargøring, og kontrolindholdet er ikke synligt for andre brugere.

### Story 4.2 – Central lagring og godkendelse af klubtjek

**Status: Åben, prioritet høj**

- [ ] Gem kontroller centralt med bruger, tidspunkt, klub, kontroltype, resultat og noter.
- [ ] Opret koordinat- og rækkeændringer som ændringsforslag.
- [ ] Gem gammel værdi, ny værdi, kilde og status for hvert forslag.
- [ ] Kræv eksplicit admin-godkendelse før stamdata ændres.
- [ ] Lad admin godkende en rettelse direkte i Klubtjek.
- [ ] Skriv godkendte koordinat- og rækkeændringer til den centrale database.
- [ ] Publicér eller synkronisér godkendte rettelser til appens fælles datakilde.
- [ ] Vis komplet historik pr. stadion og kontroltype.
- [ ] Understøt afvisning og opfølgning uden at miste oprindelig kontrol.

**Accept:** Når admin retter og godkender koordinat eller rækketilhør i Klubtjek, gemmes ændringen i den centrale database med audit-log og kan efterfølgende verificeres i appen.

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

## Aktive risici

- App og web er fortsat to repositories. Der skal altid angives, hvilket repo en ændring vedrører.
- Klubtjek gemmer endnu kun lokalt i browseren; rettelser slår ikke automatisk igennem i appens stamdata.
- Det automatiske Fixture Check er en separat GitHub-kørsel og må ikke blandes sammen med adminens manuelle Klubtjek.
- Web-backendets samlede fixture-feed indeholder fortsat internationale kampe, og Klubtjek bruger endnu denne samlede fil i stedet for det danske fixture-feed.
- Fixture-kildeovergangen er endnu i observationsperiode med Flashscore som fallback.
- Flere landes grupper er foreløbige eller mangler endelig kvalitetssikring.
- Web-deploy bygger mange statiske sider og kan derfor tage betydelig tid; det skal reduceres, når offentlig webvisning fjernes.

## Næste anbefalede rækkefølge

1. Færdiggør central lagring og godkendelse for Klubtjek.
2. Stabiliser og afslut observationsperioden for danske fixtures.
3. Gennemgå stadiondata land for land.
4. Byg admin-backloggen oven på samme centrale datamodel.
5. Luk offentlig webvisning, når driftslaget er dokumenteret og stabilt.
