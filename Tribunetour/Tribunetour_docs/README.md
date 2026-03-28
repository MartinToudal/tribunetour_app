# Tribunetour
**Platform:** iOS-app + web  
**Status:** Aktiv udvikling med overgang til ét produkt på tværs af flader

Tribunetour er et produkt for fodboldfans, der vil:
- udforske stadions
- finde kommende kampe
- planlægge stadionture
- følge deres egen progression

Den nuværende iOS-app er stadig den mest modne flade.
Web er under aktiv konvergens mod samme produkt.

---

## Produktretning

Tribunetour skal opleves som:
- ét produkt
- to flader
- samme identitet
- samme kernebegreber

Kerneflader:
1. `Stadions`
2. `Kampe`
3. `Min tur`

Appen har desuden stadig en stærk `Plan`-flade, som endnu ikke har fuld web-paritet.

---

## Nuværende status

Tribunetour er ikke længere to helt adskilte spor.

App og web deler nu:
- samme auth-retning via Supabase
- en fælles retning for `visited`
- samme reference-data-kontrakt
- i praksis samme kampprogram-indhold

Men løsningen er stadig i overgang, fordi:
- reference-data endnu ikke kommer fra én fuld fælles pipeline
- appen stadig bærer CloudKit/shared overgangslag
- ikke alle brugerdataområder er shared endnu

Den mest præcise korte status er:

`App og web hænger sammen på login og visited-retning, men ikke endnu på én fuld fælles datamodel og én fælles reference-data-pipeline.`

---

## Flader

### iOS-app
Appen er stadig den mest modne produktflade.

Den indeholder blandt andet:
- stadions
- kampe
- plan/weekend-plan
- min tur/statistik
- noter, reviews, billeder og achievements

### Web
Web er nu en reel produktflade og ikke kun et marketinglag.

Den dækker i dag:
- stadions
- kampe
- min tur
- login
- personlig visited-status

Web er dog stadig enklere end appen på flere områder.

---

## Data og sync

### Reference-data
Reference-data er fælles produktdata:
- stadions
- klubber
- fixtures
- ligaer

Krav:
- stabile IDs
- samme ID-familie på tværs af app og web
- valideret ved opdatering

Appen læser i dag:
- stadions fra app bundle
- fixtures via `RemoteFixturesProvider` med lokal fallback

Web læser i dag:
- reference-data gennem et samlet `referenceData`-lag
- med lokale seed-data som fallback

### Brugerdata
Brugerdata er personlige data som:
- visited-status
- visited date
- noter
- reviews
- billeder
- planer

For `visited` gælder nu:
- shared backend er autoritativ efter bootstrap
- appen er kun autoritativ i selve bootstrap-øjeblikket
- CloudKit er sekundært for `visited` efter bootstrap

---

## Auth

Målet er én identitet på tværs af app og web.

Aktuel retning:
- Supabase auth
- web bruger e-mail + adgangskode
- appen bruger samme konto-retning og kan arbejde mod shared backend

Auth skal forstås som adgang til brugerens egen Tribunetour, ikke som en særskilt web-feature.

---

## Arkitektur i grove træk

### App
- SwiftUI
- `AppState`
- `VisitedStore`
- `WeekendPlanStore`
- CloudKit + shared/hybrid overgangslag

### Web
- Next.js 14
- `useVisitedModel`
- `visitedRepository`
- `referenceData`-lag

---

## Vigtigste dokumenter

- `docs/INTEGRATION_STATUS.md`
- `docs/INTEGRATION_BACKLOG.md`
- `docs/ONE_PRODUCT.md`
- `docs/AUTH_AND_DATA_OWNERSHIP.md`
- `docs/REFERENCE_DATA_CONTRACT.md`
- `docs/VISITED_BACKEND_CONTRACT.md`
- `docs/VISITED_MIGRATION_PLAN.md`

---

## Næste vigtigste arbejde

1. fælles reference-data-pipeline
2. yderligere oprydning i appens overgangslag
3. release- og driftstilpasning af docs
4. beslutning om shared vs app-only dataområder

---

Tribunetour er stadig et produkt i bevægelse, men retningen er nu klarere:

`ét produkt med to flader`
