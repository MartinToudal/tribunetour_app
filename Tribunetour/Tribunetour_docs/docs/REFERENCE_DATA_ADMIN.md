# Reference-data admin

## Formål

Reference-data-admin er en intern webflade. Den er ikke en del af den brugervendte Tribunetour-oplevelse og skal kun være tilgængelig for administratoren.

## Datamodel

- `stadiums` indeholder klub/stadion-reference med land, række, sæson, koordinater og aktiv/historisk status.
- `reference_countries` indeholder lande.
- `reference_leagues` indeholder rækker og niveau.
- `reference_data_change_log` indeholder før/efter-sporbarhed.

De tre skrivefunktioner er admin-gatede Supabase RPC'er. Webklienten skriver ikke direkte til tabellerne.

## Kildehierarki

Den nuværende situation har to historiske artefakter:

1. iOS’ `stadiums.csv` er Danmark-først og indeholder 51 danske kerne-stadions.
2. webens genererede `data/stadiums.json` indeholder alle aktive landepakker og er større.

Adminfladen viser den samlede reference ved at bruge remote-overrides oven på den eksisterende web-reference. Det er en overgangsløsning. Den næste arkitekturopgave er at gøre Supabase/reference-data til den entydige redaktionelle kilde og generere iOS- og webartefakter fra den.

## Sikkerhed og drift

- `/admin/reference-data` kræver login og admin-status.
- Adgang kræver både `martin@toudal.dk` og `is_current_user_admin()`.
- Alle writes går gennem security-definerede RPC'er, som selv håndhæver admin-adgang.
- Hver write opretter en audit-log med før- og efter-værdi.
- Kør `supabase/reference_data_admin.sql` i Supabase, før adminfladen forventes at kunne gemme.
