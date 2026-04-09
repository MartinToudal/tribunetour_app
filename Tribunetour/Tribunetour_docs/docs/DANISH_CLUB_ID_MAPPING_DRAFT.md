# Danish Club ID Mapping Draft

## Formål
Dette dokument er første komplette mapping-udkast fra nuværende danske klub-/stadion-id'er til foreslåede canonical ids.

Det bruges som grundlag for:
- migration af `stadiums.csv`
- migration af `fixtures.csv`
- plan for brugerdata-migration
- første sikre trin før tysk league pack

Se også:
- `CLUB_ID_POLICY.md`
- `DANISH_CLUB_ID_AUDIT.md`

## Felter
- `legacyId`: nuværende id i systemet
- `canonicalId`: foreslået nyt globalt id
- `shortCode`: UI-/forkortelsesfelt
- `team`: klubnavn

## Mapping

| legacyId | canonicalId | shortCode | team |
| --- | --- | --- | --- |
| `aab` | `dk-aab` | `AaB` | AaB |
| `aaf` | `dk-aarhus-fremad` | `AAF` | Aarhus Fremad |
| `ab` | `dk-ab` | `AB` | AB |
| `ach` | `dk-ac-horsens` | `ACH` | AC Horsens |
| `agf` | `dk-agf` | `AGF` | AGF |
| `b93` | `dk-b-93` | `B93` | B.93 |
| `bif` | `dk-brondby-if` | `BIF` | Brøndby IF |
| `bra` | `dk-brabrand-if` | `BRA` | Brabrand IF |
| `brø` | `dk-bronshoj` | `BSJ` | Brønshøj |
| `efb` | `dk-esbjerg-fb` | `EFB` | Esbjerg fB |
| `fa2` | `dk-fa-2000` | `FA2` | FA 2000 |
| `faa` | `dk-fremad-amager` | `FAM` | Fremad Amager |
| `fcf` | `dk-fc-fredericia` | `FCF` | FC Fredericia |
| `fck` | `dk-fc-kobenhavn` | `FCK` | F.C. København |
| `fcm` | `dk-fc-midtjylland` | `FCM` | FC Midtjylland |
| `fcn` | `dk-fc-nordsjaelland` | `FCN` | FC Nordsjælland |
| `fre` | `dk-frem` | `FRE` | Frem |
| `hbk` | `dk-hb-koge` | `HBK` | HB Køge |
| `hel` | `dk-fc-helsingor` | `HEL` | FC Helsingør |
| `hik` | `dk-hik` | `HIK` | HIK |
| `hil` | `dk-hillerod-fodbold` | `HIL` | Hillerød Fodbold |
| `hob` | `dk-hobro-ik` | `HOB` | Hobro IK |
| `hol` | `dk-holbaek-bi` | `HOL` | Holbæk B&I |
| `hør` | `dk-horsholm-usserod-ik` | `HUI` | Hørsholm-Usserød IK |
| `hvi` | `dk-hvidovre-if` | `HVI` | Hvidovre IF |
| `ish` | `dk-ishoj-if` | `ISH` | Ishøj IF |
| `kol` | `dk-kolding-if` | `KOL` | Kolding IF |
| `lyn` | `dk-lyngby-boldklub` | `LYN` | Lyngby Boldklub |
| `lys` | `dk-if-lyseng` | `LYS` | IF Lyseng |
| `mid` | `dk-middelfart` | `MID` | Middelfart |
| `næs` | `dk-naesby-bk` | `NAB` | Næsby BK |
| `nas` | `dk-naestved` | `NAS` | Næstved |
| `nyk` | `dk-nykobing-fc` | `NYK` | Nykøbing FC |
| `ob` | `dk-ob` | `OB` | OB |
| `odd` | `dk-odder-fodbold` | `ODD` | Odder Fodbold |
| `ran` | `dk-randers-fc` | `RAN` | Randers FC |
| `ros` | `dk-fc-roskilde` | `ROS` | FC Roskilde |
| `sif` | `dk-silkeborg-if` | `SIF` | Silkeborg IF |
| `sje` | `dk-sonderjyske` | `SJE` | Sønderjyske Fodbold |
| `ski` | `dk-skive` | `SKI` | Skive |
| `sun` | `dk-sundby-bk` | `SUN` | Sundby BK |
| `thi` | `dk-thisted-fc` | `THI` | Thisted FC |
| `van` | `dk-vanlose` | `VAN` | Vanløse |
| `vb` | `dk-vejle-boldklub` | `VB` | Vejle Boldklub |
| `vej` | `dk-vejgaard-b` | `VEJ` | Vejgaard B |
| `ven` | `dk-vendsyssel-ff` | `VEN` | Vendsyssel FF |
| `vff` | `dk-viborg-ff` | `VFF` | Viborg FF |
| `vsk` | `dk-vsk-aarhus` | `VSK` | VSK Aarhus |

## Bemærkninger

### 1. ASCII-only
Alle foreslåede canonical ids er ASCII-only.

Det betyder:
- `brø` bliver `dk-bronshoj`
- `hør` bliver `dk-horsholm-usserod-ik`
- `næs` bliver `dk-naesby-bk`

### 2. Shortcodes er ikke canonical ids
Felter som `AGF`, `FCK`, `BIF` og `VFF` er tænkt som `shortCode`, ikke som primær nøgle.

### 3. Bevidste navnevalg
Draftet følger nu denne stil:
- brug korte ids når den korte klubidentitet i praksis er stabil og reel
- brug længere translittererede slugs når den korte form er for lokal eller skrøbelig
- hold sproget dansk-translittereret i stedet for at blande dansk og engelsk

Det betyder fx:
- `ab` -> `dk-ab`
- `ob` -> `dk-ob`
- `fck` -> `dk-fc-kobenhavn`
- `sje` -> `dk-sonderjyske`

### 4. F.C. København
Her er det bevidste valg nu:
- `dk-fc-kobenhavn`

Grunden er:
- ASCII-only
- dansk identitet bevaret
- mere konsekvent stil på tværs af danske ids

## Næste skridt
Dette draft er ikke selve migrationen endnu.

Den anbefalede rækkefølge herfra er:
1. godkend mappingen
2. beslut eventuelle justeringer i canonical ids
3. opdatér `stadiums.csv`
4. opdatér `fixtures.csv`
5. planlæg migration af brugerdata
6. først derefter åbne første tyske pack
