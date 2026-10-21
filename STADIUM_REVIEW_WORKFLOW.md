# Stadiondata: enkel arbejdsgang

Denne fil er den korte vejledning til den halvårlige gennemgang af stadiondata.

## Hvad skal kontrolleres?

For hver klub/stadion kontrolleres klubnavn og stabilt ID, stadionnavn og by, latitude/longitude, land og række, aktiv/historisk status samt kampprogram for de fire danske Klub 48-rækker.

Ret kun data, når du har en kilde eller selv har verificeret forholdet. Stabilt ID må ikke ændres uden en særskilt migrationsplan.

Den praktiske CSV-fil ligger i `Tribunetour/stadium_review.csv`, og valideringen ligger i `Tribunetour/scripts/sync-stadium-review.py`.

## Vigtigt om lande

Den nuværende iOS-CSV er Danmark-først og indeholder derfor kun de 51 danske kerne-stadions. Web-reference-data indeholder allerede internationale landepakker. Det er en kendt forskel mellem de to artefakter, ikke et signal om at internationale stadions skal fjernes.

Den nye adminflade til reference-data viser den samlede web-reference og er den næste del af arbejdet med at samle kilderne. Indtil det er migreret færdigt, skal en ændring ikke anses for distribueret til iOS, bare fordi den er gemt i adminfladen.

## Adminflade

Når web-admin er deployet, findes reference-editoren på `/admin/reference-data`. Den er kun synlig og tilgængelig for administratoren `martin@toudal.dk`.

Her kan man søge og filtrere alle lande, rækker, klubber og stadions, rette referencefelter, oprette nye klubber/stadions, oprette lande og rækker samt gemme ændringer centralt med audit-log.

Før siden kan gemme centralt, skal SQL-migrationen `Website repo/supabase/reference_data_admin.sql` køres i Supabase.
