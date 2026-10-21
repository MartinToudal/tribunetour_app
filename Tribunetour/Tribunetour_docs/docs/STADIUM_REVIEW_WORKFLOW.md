# Stadionopdatering via regneark

## Hvad skal kontrolleres?

For hver række i `stadium_review.csv` kontrolleres:

- `team`: det korrekte klubnavn.
- `name`: det korrekte stadionnavn.
- `city`: den korrekte by.
- `league`: den korrekte aktive række.
- `season_id`: den sæson rækken gælder for.
- `lat` og `lon`: stadionets geografiske koordinater.
- `source_url`: den kilde der blev brugt til kontrollen.
- `checked_at`: dato og tidspunkt for kontrollen.
- `reviewer`: hvem der kontrollerede rækken.
- `notes`: eventuel forklaring eller usikkerhed.

`id`, `country_code` og øvrige tekniske identifikatorer skal ikke ændres i regnearket. De beskytter historik, fixtures og brugerens besøgsdata.

## Sådan bruges filen

1. Åbn `Tribunetour/stadium_review.csv` i Numbers, Excel eller Google Sheets.
2. Ret kun de faktiske stadionoplysninger.
3. Sæt `sync_status` til `approved`, når rækken er kontrolleret.
4. Udfyld `source_url`, `checked_at` og `reviewer` på godkendte rækker.
5. Gem filen og commit den til app-repositoriet.

Den daglige synkronisering validerer filen, skriver godkendte ændringer til canonical `Tribunetour/stadiums.csv`, markerer rækkerne som `applied` og skriver en audit-log i `Tribunetour/stadium_review_log.json`.

## Vigtig afgrænsning

Regnearket skriver ikke direkte til Supabase. Canonical reference-data er fortsat CSV-datasættet. Supabase bruges til login, sync og brugerdata. Når reference-dataflowet senere er samlet helt, kan den samme review-fil bruges som input til den centrale distribution.

## Statusser

- `pending`: ikke færdigkontrolleret.
- `approved`: kontrolleret og klar til automatisk anvendelse.
- `applied`: anvendt i canonical data.
- `rejected`: må ikke anvendes.
