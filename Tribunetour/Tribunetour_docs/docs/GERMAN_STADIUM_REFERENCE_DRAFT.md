# German Stadium Reference Draft

Dette dokument er første arbejdsdraft for tyske klubber/stadioner i `germany_top_3`.

Formålet er ikke at være den endelige importfil endnu. Formålet er at låse:

- hvilke klubber der er i scope
- hvilke canonical ids vi vil bruge
- hvilke liga-koder der gælder
- hvilke stadionfelter vi skal have på plads

Koordinater er bevidst ikke låst i denne version. Dem bør vi tage i en separat geodata-pass, så vi ikke ender med halve eller upræcise placeringer i produktet.

## Scope

Denne draft dækker:

- `de-bundesliga`
- `de-2-bundesliga`
- `de-3-liga`

League pack:

- `germany_top_3`

## Reference-data felter

Anbefalet minimum pr. række:

- `id`
- `stadiumName`
- `team`
- `league`
- `city`
- `lat`
- `lon`
- `countryCode`
- `leagueCode`
- `leaguePack`
- `shortCode`

I denne draft er:

- `id`, `team`, `leagueCode`, `leaguePack`, `shortCode` låst som arbejdshypotese
- `stadiumName` delvist udfyldt
- `city` delvist udfyldt
- `lat/lon` stadig `pending`

## Bundesliga

Disse stadionnavne er verificeret mod Bundesliga.coms kluboversigt for sæsonen 2025/26.

| canonicalId | team | shortCode | leagueCode | stadiumName | city | lat | lon |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `de-bayern-munchen` | FC Bayern München | `FCB` | `de-bundesliga` | Allianz Arena | München | `48.2187901` | `11.6236227` |
| `de-bayer-leverkusen` | Bayer 04 Leverkusen | `B04` | `de-bundesliga` | BayArena | Leverkusen | `51.0381439` | `7.0030964` |
| `de-eintracht-frankfurt` | Eintracht Frankfurt | `SGE` | `de-bundesliga` | Deutsche Bank Park | Frankfurt am Main | `50.0686103` | `8.6454154` |
| `de-borussia-dortmund` | Borussia Dortmund | `BVB` | `de-bundesliga` | SIGNAL IDUNA PARK | Dortmund | `51.4924922` | `7.4518549` |
| `de-sc-freiburg` | Sport-Club Freiburg | `SCF` | `de-bundesliga` | Europa-Park Stadion | Freiburg im Breisgau | `48.0213778` | `7.8298170` |
| `de-mainz-05` | 1. FSV Mainz 05 | `M05` | `de-bundesliga` | MEWA ARENA | Mainz | `49.9839451` | `8.2244738` |
| `de-rb-leipzig` | RB Leipzig | `RBL` | `de-bundesliga` | Red Bull Arena | Leipzig | `51.3457079` | `12.3482361` |
| `de-werder-bremen` | SV Werder Bremen | `SVW` | `de-bundesliga` | Weserstadion | Bremen | `53.0664479` | `8.8376718` |
| `de-vfb-stuttgart` | VfB Stuttgart | `VFB` | `de-bundesliga` | MHPArena | Stuttgart | `48.7922487` | `9.2320857` |
| `de-borussia-monchengladbach` | Borussia Mönchengladbach | `BMG` | `de-bundesliga` | BORUSSIA-PARK | Mönchengladbach | `51.1746250` | `6.3854094` |
| `de-vfl-wolfsburg` | VfL Wolfsburg | `WOB` | `de-bundesliga` | Volkswagen Arena | Wolfsburg | `52.4328584` | `10.8031040` |
| `de-fc-augsburg` | FC Augsburg | `FCA` | `de-bundesliga` | WWK ARENA | Augsburg | `48.3231179` | `10.8858790` |
| `de-union-berlin` | 1. FC Union Berlin | `FCU` | `de-bundesliga` | Stadion An der Alten Försterei | Berlin | `52.4569741` | `13.5680789` |
| `de-fc-st-pauli` | FC St. Pauli | `FCP` | `de-bundesliga` | Millerntor-Stadion | Hamburg | `53.5545567` | `9.9677842` |
| `de-tsg-hoffenheim` | TSG Hoffenheim | `TSG` | `de-bundesliga` | PreZero Arena | Sinsheim | `49.2380604` | `8.8876414` |
| `de-heidenheim` | 1. FC Heidenheim 1846 | `FCH` | `de-bundesliga` | Voith-Arena | Heidenheim an der Brenz | `48.6685245` | `10.1392963` |
| `de-fc-koln` | 1. FC Köln | `KOE` | `de-bundesliga` | RheinEnergieSTADION | Köln | `50.9335055` | `6.8751167` |
| `de-hamburger-sv` | Hamburger SV | `HSV` | `de-bundesliga` | Volksparkstadion | Hamburg | `53.5871535` | `9.8987056` |

## 2. Bundesliga

Denne del er nu opdateret med officielle stadionnavne fra Bundesliga.coms kluboversigt for sæsonen 2025/26.

By-feltet er i denne version udfyldt ud fra klubidentiteten, hvor det er entydigt og lav-risiko.

| canonicalId | team | shortCode | leagueCode | stadiumName | city | lat | lon |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `de-sv-darmstadt-98` | SV Darmstadt 98 | `D98` | `de-2-bundesliga` | Merck-Stadion am Böllenfalltor | Darmstadt | `49.8577100` | `8.6724145` |
| `de-sv-elversberg` | SV Elversberg | `SVE` | `de-2-bundesliga` | URSAPHARM-Arena | Spiesen-Elversberg | `49.3188046` | `7.1215724` |
| `de-hannover-96` | Hannover 96 | `H96` | `de-2-bundesliga` | Heinz von Heiden Arena | Hannover | `52.3600260` | `9.7310161` |
| `de-magdeburg` | 1. FC Magdeburg | `FCM` | `de-2-bundesliga` | Avnet Arena | Magdeburg | `52.1248901` | `11.6706866` |
| `de-sc-paderborn-07` | SC Paderborn 07 | `SCP` | `de-2-bundesliga` | Home Deluxe Arena | Paderborn | `51.7308967` | `8.7109633` |
| `de-arminia-bielefeld` | DSC Arminia Bielefeld | `DSC` | `de-2-bundesliga` | SchücoArena | Bielefeld | `52.0320259` | `8.5167762` |
| `de-kaiserslautern` | 1. FC Kaiserslautern | `FCKL` | `de-2-bundesliga` | Fritz-Walter-Stadion | Kaiserslautern | `49.4345765` | `7.7766303` |
| `de-dynamo-dresden` | SG Dynamo Dresden | `SGD` | `de-2-bundesliga` | Rudolf-Harbig-Stadion | Dresden | `51.0408490` | `13.7480416` |
| `de-holstein-kiel` | Holstein Kiel | `KSV` | `de-2-bundesliga` | Holstein-Stadion | Kiel | `54.3492088` | `10.1237559` |
| `de-preussen-munster` | SC Preußen Münster | `SCPM` | `de-2-bundesliga` | LVM-Preußenstadion | Münster | `51.9318157` | `7.6260970` |
| `de-schalke-04` | FC Schalke 04 | `S04` | `de-2-bundesliga` | VELTINS-Arena | Gelsenkirchen | `51.5545938` | `7.0676001` |
| `de-hertha-bsc` | Hertha BSC | `BSC` | `de-2-bundesliga` | Olympiastadion | Berlin | `52.5145846` | `13.2398144` |
| `de-karlsruher-sc` | Karlsruher SC | `KSC` | `de-2-bundesliga` | BBBank Wildpark | Karlsruhe | `49.0200043` | `8.4129879` |
| `de-eintracht-braunschweig` | Eintracht Braunschweig | `EBS` | `de-2-bundesliga` | EINTRACHT-STADION | Braunschweig | `52.2901014` | `10.5214686` |
| `de-fortuna-dusseldorf` | Fortuna Düsseldorf | `F95` | `de-2-bundesliga` | Merkur Spielarena | Düsseldorf | `51.2616291` | `6.7331516` |
| `de-vfl-bochum` | VfL Bochum 1848 | `BOC` | `de-2-bundesliga` | Vonovia Ruhrstadion | Bochum | `51.4900826` | `7.2365091` |
| `de-nurnberg` | 1. FC Nürnberg | `FCN` | `de-2-bundesliga` | Max-Morlock-Stadion | Nürnberg | `49.4262570` | `11.1256706` |
| `de-greuther-furth` | SpVgg Greuther Fürth | `SGF` | `de-2-bundesliga` | Sportpark Ronhof \| Thomas Sommer | Fürth | `49.4871453` | `10.9988931` |

## 3. Liga

Denne del er nu udfyldt som et første arbejdsudkast med stadionnavne og byer.

Vigtigt:

- dette er stadig draft-niveau
- `3. Liga` bør have et sidste verificeringspas før egentlig import
- `lat/lon` er fortsat bevidst `pending`

| canonicalId | team | shortCode | leagueCode | stadiumName | city | lat | lon |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `de-energie-cottbus` | Energie Cottbus | `FCE` | `de-3-liga` | LEAG Energie Stadion | Cottbus | `51.7516231` | `14.3455790` |
| `de-msv-duisburg` | MSV Duisburg | `MSV` | `de-3-liga` | Schauinsland-Reisen-Arena | Duisburg | `51.4095005` | `6.7771895` |
| `de-sc-verl` | SC Verl | `SCV` | `de-3-liga` | Sportclub Arena | Verl | `51.8834990` | `8.5133824` |
| `de-vfl-osnabruck` | VfL Osnabrück | `OSN` | `de-3-liga` | Bremer Brücke | Osnabrück | `52.2808323` | `8.0712775` |
| `de-hansa-rostock` | FC Hansa Rostock | `FCHR` | `de-3-liga` | Ostseestadion | Rostock | `54.0850095` | `12.0950945` |
| `de-rot-weiss-essen` | Rot-Weiss Essen | `RWE` | `de-3-liga` | Stadion an der Hafenstraße | Essen | `51.4868685` | `6.9766158` |
| `de-1860-munchen` | TSV 1860 München | `TSV` | `de-3-liga` | Städtisches Stadion an der Grünwalder Straße | München | `48.1110013` | `11.5744172` |
| `de-tsg-hoffenheim-ii` | TSG Hoffenheim II | `TSG2` | `de-3-liga` | Dietmar-Hopp-Stadion | Sinsheim | `49.2782944` | `8.8422013` |
| `de-waldhof-mannheim` | SV Waldhof Mannheim | `SVWM` | `de-3-liga` | Carl-Benz-Stadion | Mannheim | `49.4794201` | `8.5025049` |
| `de-wehen-wiesbaden` | SV Wehen Wiesbaden | `SVWW` | `de-3-liga` | BRITA-Arena | Wiesbaden | `50.0712853` | `8.2566478` |
| `de-viktoria-koln` | FC Viktoria Köln | `VIK` | `de-3-liga` | Sportpark Höhenberg | Köln | `50.9451090` | `7.0304736` |
| `de-vfb-stuttgart-ii` | VfB Stuttgart II | `VFB2` | `de-3-liga` | Robert-Schlienz-Stadion | Stuttgart | `48.7904688` | `9.2338466` |
| `de-fc-ingolstadt-04` | FC Ingolstadt 04 | `FCI` | `de-3-liga` | Audi Sportpark | Ingolstadt | `48.7452797` | `11.4855268` |
| `de-saarbrucken` | 1. FC Saarbrücken | `FCS` | `de-3-liga` | Ludwigsparkstadion | Saarbrücken | `49.2480830` | `6.9838944` |
| `de-jahn-regensburg` | SSV Jahn Regensburg | `SSVJ` | `de-3-liga` | Jahnstadion Regensburg | Regensburg | `48.9908566` | `12.1073501` |
| `de-alemannia-aachen` | Alemannia Aachen | `AAC` | `de-3-liga` | Tivoli | Aachen | `50.7931119` | `6.0964285` |
| `de-erzgebirge-aue` | FC Erzgebirge Aue | `AUE` | `de-3-liga` | Erzgebirgsstadion | Aue-Bad Schlema | `50.5977903` | `12.7113047` |
| `de-ssv-ulm-1846` | SSV Ulm 1846 Fußball | `ULM` | `de-3-liga` | Donaustadion | Ulm | `48.4045183` | `10.0093900` |
| `de-tsv-havelse` | TSV Havelse | `HAV` | `de-3-liga` | Wilhelm-Langrehr-Stadion | Garbsen | `52.4088683` | `9.6019752` |
| `de-schweinfurt-05` | 1. FC Schweinfurt 05 | `S05` | `de-3-liga` | Sachs-Stadion | Schweinfurt | `50.0519940` | `10.2016834` |

## Åbne beslutninger

1. Skal vi bruge lokal tysk klubform som visningsnavn hele vejen?
2. Skal reservehold have særskilt UI-markering, fx “II” badges?
3. Vil vi have mere konsekvente short codes i 2. Bundesliga og 3. Liga for at undgå kollisioner i chips og badges?

## Næste skridt

1. Kør et sidste verificeringspas på `3. Liga`, før import.
2. Omsæt derefter draftet til faktisk importformat.

## Kilder

- Bundesliga official clubs/stadium overview:
  - [Bundesliga Clubs 2025/26](https://www.bundesliga.com/en/bundesliga/clubs)
- 2. Bundesliga official club scope:
  - [2. Bundesliga Clubs 2025/26](https://www.bundesliga.com/en/2bundesliga/clubs)
- 3. Liga official club scope:
  - [DFB Datencenter 3. Liga 2025/26](https://datencenter.dfb.de/datencenter/3-liga/2025-2026/16)
- Geokodning af stadionnavn + by:
  - [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org/)
