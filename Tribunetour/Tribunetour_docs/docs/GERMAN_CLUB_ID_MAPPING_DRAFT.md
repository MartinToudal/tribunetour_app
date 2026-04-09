# German Club ID Mapping Draft

Dette dokument er første konkrete id-draft for den tyske league pack `germany_top_3`.

Status:

- scope er `Bundesliga`, `2. Bundesliga`, `3. Liga`
- ids er foreslået i canonical format
- forkortelser er bevaret som `shortCode`
- listen er et arbejdsudkast, ikke en låst produktbeslutning endnu

Kildemæssigt er listen baseret på officielle kluboversigter for:

- Bundesliga 2025/26
- 2. Bundesliga 2025/26
- 3. Liga 2025/26

## Id-regler

Vi bruger:

- `de-` som landeprefix
- ASCII-only slugs
- stabil klubidentitet frem for lokal, løs forkortelse

Eksempler:

- `de-bayern-munchen`
- `de-borussia-dortmund`
- `de-fc-st-pauli`

`shortCode` er kun til UI og genkendelse, ikke som primær nøgle.

## Bundesliga

| clubName | canonicalId | shortCode |
| --- | --- | --- |
| FC Bayern München | `de-bayern-munchen` | `FCB` |
| Bayer 04 Leverkusen | `de-bayer-leverkusen` | `B04` |
| Eintracht Frankfurt | `de-eintracht-frankfurt` | `SGE` |
| Borussia Dortmund | `de-borussia-dortmund` | `BVB` |
| Sport-Club Freiburg | `de-sc-freiburg` | `SCF` |
| 1. FSV Mainz 05 | `de-mainz-05` | `M05` |
| RB Leipzig | `de-rb-leipzig` | `RBL` |
| SV Werder Bremen | `de-werder-bremen` | `SVW` |
| VfB Stuttgart | `de-vfb-stuttgart` | `VFB` |
| Borussia Mönchengladbach | `de-borussia-monchengladbach` | `BMG` |
| VfL Wolfsburg | `de-vfl-wolfsburg` | `WOB` |
| FC Augsburg | `de-fc-augsburg` | `FCA` |
| 1. FC Union Berlin | `de-union-berlin` | `FCU` |
| FC St. Pauli | `de-fc-st-pauli` | `FCP` |
| TSG Hoffenheim | `de-tsg-hoffenheim` | `TSG` |
| 1. FC Heidenheim 1846 | `de-heidenheim` | `FCH` |
| 1. FC Köln | `de-fc-koln` | `KOE` |
| Hamburger SV | `de-hamburger-sv` | `HSV` |

## 2. Bundesliga

| clubName | canonicalId | shortCode |
| --- | --- | --- |
| SV Darmstadt 98 | `de-sv-darmstadt-98` | `D98` |
| SV Elversberg | `de-sv-elversberg` | `SVE` |
| Hannover 96 | `de-hannover-96` | `H96` |
| 1. FC Magdeburg | `de-magdeburg` | `FCM` |
| SC Paderborn 07 | `de-sc-paderborn-07` | `SCP` |
| DSC Arminia Bielefeld | `de-arminia-bielefeld` | `DSC` |
| 1. FC Kaiserslautern | `de-kaiserslautern` | `FCKL` |
| SG Dynamo Dresden | `de-dynamo-dresden` | `SGD` |
| Holstein Kiel | `de-holstein-kiel` | `KSV` |
| SC Preußen Münster | `de-preussen-munster` | `SCPM` |
| FC Schalke 04 | `de-schalke-04` | `S04` |
| Hertha BSC | `de-hertha-bsc` | `BSC` |
| Karlsruher SC | `de-karlsruher-sc` | `KSC` |
| Eintracht Braunschweig | `de-eintracht-braunschweig` | `EBS` |
| Fortuna Düsseldorf | `de-fortuna-dusseldorf` | `F95` |
| VfL Bochum 1848 | `de-vfl-bochum` | `BOC` |
| 1. FC Nürnberg | `de-nurnberg` | `FCN` |
| SpVgg Greuther Fürth | `de-greuther-furth` | `SGF` |

## 3. Liga

| clubName | canonicalId | shortCode |
| --- | --- | --- |
| Energie Cottbus | `de-energie-cottbus` | `FCE` |
| MSV Duisburg | `de-msv-duisburg` | `MSV` |
| SC Verl | `de-sc-verl` | `SCV` |
| VfL Osnabrück | `de-vfl-osnabruck` | `OSN` |
| FC Hansa Rostock | `de-hansa-rostock` | `FCHR` |
| Rot-Weiss Essen | `de-rot-weiss-essen` | `RWE` |
| TSV 1860 München | `de-1860-munchen` | `TSV` |
| TSG Hoffenheim II | `de-tsg-hoffenheim-ii` | `TSG2` |
| SV Waldhof Mannheim | `de-waldhof-mannheim` | `SVWM` |
| SV Wehen Wiesbaden | `de-wehen-wiesbaden` | `SVWW` |
| FC Viktoria Köln | `de-viktoria-koln` | `VIK` |
| VfB Stuttgart II | `de-vfb-stuttgart-ii` | `VFB2` |
| FC Ingolstadt 04 | `de-fc-ingolstadt-04` | `FCI` |
| 1. FC Saarbrücken | `de-saarbrucken` | `FCS` |
| SSV Jahn Regensburg | `de-jahn-regensburg` | `SSVJ` |
| Alemannia Aachen | `de-alemannia-aachen` | `AAC` |
| FC Erzgebirge Aue | `de-erzgebirge-aue` | `AUE` |
| SSV Ulm 1846 Fußball | `de-ssv-ulm-1846` | `ULM` |
| TSV Havelse | `de-tsv-havelse` | `HAV` |
| 1. FC Schweinfurt 05 | `de-schweinfurt-05` | `S05` |

## Åbne beslutninger

Der er nogle navne, vi bør låse bevidst før import:

1. Hvordan vi vil håndtere reservehold i canonical ids
   - forslag: behold `-ii` eksplicit i id

2. Hvordan vi vil forkorte klubber med potentielle UI-kollisioner
   - fx `SC Paderborn 07` vs. `SC Preußen Münster`

3. Om vi vil bruge meget lokale short codes eller mere internationale varianter
   - fx `KOE` vs. `FC`

4. Hvordan vi vil navngive klubber med tal i identiteten
   - fx `Mainz 05`, `Schalke 04`, `Hannover 96`

## Næste skridt

1. Gennemgå og justér canonical ids, hvor de føles for tunge eller uklare.
2. Lås short-code-stilen.
3. Lav første reference-data-draft for stadioner og koordinater.
4. Først bagefter importér tyske fixtures.
