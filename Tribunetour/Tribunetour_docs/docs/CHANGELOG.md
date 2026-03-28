# Changelog
Alle væsentlige ændringer i Tribunetour dokumenteres her.

Formatet følger i grove træk *Keep a Changelog*, men er tilpasset et lille produkt-eksperiment med sprint-baseret udvikling.

---

## [Unreleased] – Sprint 5.x
**Status:** Stabiliseringsrunde i gang  
**Fokus:** Foto-sync, review, achievements og release-hardening

### 🧭 Forbedringer
- Forbedret CloudKit foto-sync robusthed (serialiseret push-flow)
- Hurtigere sync-trigger ved fotoændringer (add/slet/caption)
- Oprydning i release-dokumentation med konkrete go/no-go kriterier
- Notifikationsvinduer gjort eksplicit testbare (midtuge + weekend)
- Tidszone-regressionstest for fixtures efter sommertid (Europe/Copenhagen)
- App Store launch-spor nu dokumenteret separat fra senere platform-migrering

### ✅ Verificeret i test
- Reinstall-flow med fotos kan gendanne hele datasættet i normal drift
- Regressionstest dækker nu vindueslogik for lokale notifikationer
- Regressionstest verificerer lokal visning/filtrering af kampstart efter DST-skifte

---

## [0.1.1] – Sprint 2  
**Status:** TestFlight Beta  
**Fokus:** Plan, synkronisering og stabilitet

### ✨ Nye features
- Fleksibel **Plan-funktion** med valgfrit datointerval (ikke kun weekend)
- Interaktiv datovælger med interval-markering
- **CloudKit-synkronisering** (Private Database) for:
  - Besøgte stadions
  - Kamp-plan
- Automatisk restore ved geninstallation / ny enhed
- Filtrering af kampe så **afviklede kampe ikke længere vises**

### 🧭 Forbedringer
- Forbedret struktur med central `AppState`
- Tydeligere opdeling mellem data (models), visning (views) og lagring (stores)
- Plan og Kampe bedre koblet sammen (tap fra plan → kampdetalje)
- UI-justeringer i Plan-fanen (mere rolig og fokuseret præsentation)

### 🐞 Fejlrettelser
- Rettet tab af brugerdata ved geninstallation
- Stabiliseret CloudKit-schema (VisitedStadium, WeekendPlan)
- Rettet forskellige lifecycle-issues ved app-start
- Reduceret unødige reloads ved navigation

### ⚠️ Kendte begrænsninger
- Kampprogram hentes stadig fra CSV i app bundle
- Ingen live-opdatering af fixtures
- Ingen push-notifikationer
- Begrænset error-logging (bevidst i beta)

---

## [0.1.0] – Sprint 1  
**Status:** Første TestFlight-build  
**Fokus:** Grundfunktionalitet og værdiflow

### ✨ Features
- Stadions:
  - Liste- og kortvisning
  - Markering af besøgte stadions
  - Filtre og sortering
  - “Tættest på mig” (lokation)
- Kampe:
  - Kampprogram (kommende kampe)
  - Søgning og filtrering
  - Kampdetalje med stadioninfo
- Min tur:
  - Simpel statistik og progression
- Lokal persistens (UserDefaults)

### 🧱 Teknisk
- SwiftUI-baseret UI
- CSV-import med validering
- Offline-first tilgang
- Ingen backend eller login

---

## Versionering
- `0.1.x` = Beta / eksperimentel fase
- Mindre features og forbedringer → patch/minor bump
- Større produktmæssige skridt → minor bump (`0.2.0`, `0.3.0`, …)

---

*Changelog opdateres løbende i takt med TestFlight-feedback og sprint-afslutninger.*
