# Spanien 2026/27 overgangsnotat

Formål: samle de kendte sæsonændringer for Spanien, før den endelige 2026/27-model skrives ind i appens reference-data.

Dette notat bruges som arbejdsgrundlag for næste opdatering af:
- `spain_top_4.csv`
- historiske medlemskaber for 2025/26
- aktivt 2026/27-snapshot for Spanien

## Bekræftede ændringer

### La Liga
- Nedrykkere:
  - Mallorca
  - Girona
  - Oviedo

### Segunda División
- Oprykkere til La Liga:
  - Racing Santander
  - La Coruna
  - Malaga
- Nedrykkere fra Segunda División:
  - Mirandes
  - Huesca
  - Cultural Leonesa
  - Zaragoza

### Primera Federación
- Oprykkere fra Gruppe 1:
  - Tenerife
  - Celta Vigo B
- Oprykkere fra Gruppe 2:
  - Eldense
  - Sabadell

- Nedrykkere ud af ligasystemet fra Gruppe 1:
  - CF Talavera
  - Ourense CF
  - Guadalajara
  - Osasuna B
  - Arenteiro

- Nedrykkere ud af ligasystemet fra Gruppe 2:
  - Betis B
  - Tarazona
  - UD Marbella
  - Sanluqueno
  - Sevilla B

### Oprykkere fra Segunda Federación
- Aguilas
- Coria
- Deportivo Fabril
- Extremadura
- Jaen
- UD Logrones
- UD Ourense
- Rayo Majadahonda
- Real Union
- Sant Andreu

## Åbne afklaringer

### Primera Federación 2026/27
- Den endelige fordeling mellem Gruppe 1 og Gruppe 2 er ikke fastlagt endnu.
- Indtil forbundet offentliggør grupperne, bruges en midlertidig fordeling i reference-data.

## Implementeringsprincip

Spanien kan nu godt skrives til et aktivt `2026-27`-snapshot, selv om Primera Federación stadig mangler officiel gruppefordeling.

Princippet er:
1. La Liga og Segunda División følger de afgjorte op- og nedrykninger
2. Primera Federación holdes i to midlertidige grupper
3. når forbundet offentliggør den endelige fordeling, kan grupperne justeres uden at ændre resten af modellen

## Næste skridt

1. opdater `spain_top_4.csv` til samme sæsonformat som Danmark, England og Italien
2. tilføj historiske `2025-26` medlemskaber i `CSVClubImporter.swift`
3. placer nedrykkere uden for det aktive ligasystem som `Nedrykkere`
4. skift de midlertidige Primera Federación-grupper til officiel fordeling, når den er offentliggjort
5. build og sanity-check klubbers rækkehistorik og aktiv rækkevisning
