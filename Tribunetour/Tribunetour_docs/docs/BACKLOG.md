# Tribunetour Backlog

Dette dokument er den løbende, samlede backlog for appen.  
Opdateres løbende sammen med sprint-arbejdet.

---

## Status Snapshot
- **Fase:** App-first (før backend/web)
- **Aktuel sprintretning:** Sprint 5.x (EPIC E-light + D-light)
- **Næste store fase:** Login/backend/web-fundament (EPIC A)

---

## Done (højdepunkter)
- Kerneflow: Stadions, Kampe, Plan, Min tur
- Filtrering/sortering/søgning inkl. afstand
- Kampdetaljer + link til stadiondetaljer
- Lokal persistens + iCloud sync (visited + plan)
- Review v1 i stadiondetalje:
  - kategorier, score, kategori-noter, opsummering, tags
- Fotos v1:
  - upload, lokalt galleri, fullscreen, swipe, billedtekst, sletning
- Stats v1:
  - anmeldelser, fotos, progression
- Achievements v1:
  - lokale milestones + unlock/progress

---

## In Progress (Sprint 5.x)
- Stabilisering af CloudKit fotosync på tværs af reinstall/enheder
- Achievement UX-polish (toast/visibilitet/oplevelse)
- Dokumentation og release-hardening af foto/review/achievement-flow

---

## Next Up (prioriteret)
1. **E26:** Stabil cloud-sync af billeder (inkl. edge cases, schema, recovery)
2. **D18-D19:** Achievement polish (bedre progression, evt. detailside)
3. **D20-D21:** Flere belønninger/tiers (visual rewards)
4. **E24-E25:** Review polish (hurtigere input, rediger/slet-flow)
5. **C20:** Små UX-polish-opgaver (haptics, swipe-actions, tom-tilstande)

---

## Push-notifikationer (senere backlog)
> Planlagt til senere sprint, når kerne/app-flow er helt stabilt.

1. **N1:** Lokal notifikation ved ny achievement unlock
2. **N2:** Weekend-signal:
   - "Du har X kampe i weekenden på ikke-besøgte stadions"
3. **N3:** Reminder:
   - "Næste kamp på stadion du mangler"
4. **N4:** Notifikationsindstillinger:
   - opt-in pr. type + timing
5. **N5:** Ugentlig digest (søndag aften)

---

## Later (strategisk)

### EPIC A – Login / backend / web
- Login-strategi (Apple/email)
- Brugerprofil
- Backend-beslutning + migrering
- API/read-model til web

### EPIC F/G – Social + ranking
- Deling af besøg/billeder/reviews
- Gruppeture/invite
- Leaderboards (med privacy/opt-in)

### Branding/visuals
- Klublogoer
- Rækkelogoer

---

## Working Rules
- Fokus på app-værdi først, backend efter stabil kerne.
- Små, releasebare increments med tydelig DoD.
- Backlog opdateres i dette dokument ved større feature-ændringer.
