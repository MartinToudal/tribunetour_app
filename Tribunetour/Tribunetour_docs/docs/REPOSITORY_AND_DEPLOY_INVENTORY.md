# Repository- og deployinventar

Senest opdateret: 2026-10-05

Dette dokument beskriver, hvor Tribunetour faktisk lever, hvilke dele der er verificeret, og hvad der stadig kræver en remote/deploy-kontrol. Det er et driftsdokument, ikke en ny source of truth for produktdata.

## Repositories

| Område | Lokal placering | Remote | Verificeret status | Mål |
|---|---|---|---|---|
| iOS-app og fælles dokumentation | `/Users/martintoudal/Documents/Tribunetour/Tribunetour` | `Tribunetour_app` | Lokal `main` er pushed efter seneste dokumentationsændring | Bevar som eneste produktrepo for iOS og produktdokumentation |
| Web, fixtures og drift | `/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website repo` | `origin` / `tribunetour-mvp` | Lokal `main` er `ahead 3, behind 46` og har untracked lokale data-/Supabase-filer; må ikke bruges som autoritativ remote-status | Reducér til nødvendige interne/driftsflows og udfas offentlig webvisning |
| Supabase | Knyttet til web-repoets migrations-/SQL-spor | Remote Supabase-projekt | Login, sync og tidligere Klubtjek-spor eksisterer; fuld oprydning er ikke afsluttet | Bevar login/sync; fjern kun legacy efter afhængighedskontrol |

Den eksisterende lokale ændring i `Tribunetour.xcodeproj/project.pbxproj` er brugerens og må ikke medtages i dokumentationscommits.

## Verificerede appflows

- Appen loader Danmark først fra bundlede CSV-data.
- Andre lande loader on demand via landepakker.
- Danske fixtures kommer fra remote feed, cache og lokal fallback.
- Login og brugerdata-sync er fortsat aktive.
- Weekendplan og premium/league-pack-kode findes stadig i runtime og er overgangsflows, selv om de er besluttet udfaset.

## Verificerede web- og driftsflows

Den lokale webcheckout indeholder:

- `daily-fixture-check.yml` som manuel workflow.
- `fixture-audit.yml` som manuel workflow.
- `daily-manual-club-check.yml` med både manuel og planlagt kørsel.
- Vercel-konfiguration med cron-ruter for daily fixture check og fixture audit.
- Reference-data-generering og publicering af fixture-feed.
- Offentlige web-ruter samt admin-/legacy-ruter.

Dette er en lokal checkout-observation. Den er ikke en garanti for den deployede remote-version, fordi checkouten er divergeret fra den registrerede remote-reference.

## Secrets og deployafhængigheder

Følgende secret-navne er observeret i workflow-definitioner. Værdier må aldrig skrives i dokumentationen:

- `RESEND_API_KEY`
- `FIXTURE_CHECK_NOTIFY_TO`
- `FIXTURE_CHECK_NOTIFY_FROM`
- `MANUAL_SPOTCHECK_NOTIFY_TO`
- `MANUAL_SPOTCHECK_NOTIFY_FROM`

Derudover skal remote/deploy-kontrollen afdække:

- Vercel project og production branch.
- Production environment variables.
- Supabase project reference, policies, RPC’er og migrationsstatus.
- GitHub Actions secrets og repository permissions.
- Hvilke cron-ruter der reelt er aktive i produktion.
- Hvilke public reference-data-filer i Vercel der fortsat bruges af appen.

## Kendte begrænsninger

Remote-verifikation kunne ikke gennemføres 2026-10-05, fordi miljøet ikke kunne opløse `github.com`. Derfor er følgende endnu ikke godkendt:

- Remote `main`-revision for web-repositoriet.
- Faktisk deployed Vercel-revision.
- Aktive production secrets og cron schedules.
- Om remote indeholder workflows eller filer, som den lokale checkout ikke har.

## Beslutning før ændringer

Der må ikke slettes workflows, Supabase-tabeller, secrets eller Vercel-ruter på baggrund af den lokale checkout alene. Først skal remote/deploy-kontrol gennemføres, hvorefter hver del klassificeres som:

1. Bevar for iOS-produktet.
2. Bevar midlertidigt som driftsfallback.
3. Migrér til den nye danske CSV-/fixture-struktur.
4. Udfas efter dokumenteret efterkontrol.

## Næste konkrete arbejde

1. Verificér remote web-repository og Vercel production revision.
2. Lav afhængighedskort for Supabase-tabeller, RPC’er, secrets og cron-ruter.
3. Fastlæg minimumsdrift for danske fixtures og login/sync.
4. Lav en trinvis udfasningsplan for offentlig web, Plan, premium og Klubtjek.
5. Kør efterkontrol efter hvert trin før næste oprydning.
