# Gust Românesc – aplicație iOS nativă

Produse tradiționale, montane, ecologice și cu origine protejată din România, cu date live din Catalogul Produselor și Activităților Certificate (CPAC) al AFIR – https://cpac.afir.info/ToateProdusele.

## Cum o pornești

1. Dezarhivează și deschide `GustRomanesc.xcodeproj` în **Xcode 16 sau mai nou**.
2. Selectează target-ul *GustRomanesc* → *Signing & Capabilities* → alege echipa ta (Team).
3. Dacă vrei, schimbă `Bundle Identifier` (acum `ro.gustromanesc.app`).
4. Rulează pe simulator sau pe iPhone (iOS 17+).
   - În simulator: *Features → Location → Custom Location* (ex. 45.6427, 25.5887 pentru Brașov) ca să vezi „Lângă tine”.

La prima pornire aplicația descarcă tot catalogul (~5.250 de produse, 22 de cereri în paralel, câteva secunde). Apoi îl ține local și merge **offline**; se reactualizează singură o dată pe săptămână sau la tragere în jos pe ecranul Acasă.

## Ce face

| Tab | Funcții |
|---|---|
| **Acasă** | Detectează unde ești (oraș, județ, regiune istorică), produsul zilei, produse **lângă tine** cu rază reglabilă (10–200 km), produse din județul tău, categorii, ghidul atestatelor |
| **Hartă** | ~1.700 de puncte de lucru grupate în clustere colorate pe categorii; filtre pe categorie și tip de atestat; salt pe orice județ; buton „unde sunt”; listă cu producătorii din zona vizibilă; atingi un pin → produsele lui + navigație |
| **Regiuni** | Transilvania, Maramureș, Crișana, Banat, Oltenia, Muntenia, București-Ilfov, Dobrogea, Moldova, Bucovina, Rep. Moldova → județe → produse (căutare, filtre, sortare, „vezi pe hartă”) |
| **Caută** | Căutare fără diacritice în nume, producător, localitate și descriere; filtre combinate (categorie, atestat, regiune, județ, rating); sortare după distanță / rating / alfabetic / cele mai noi |
| **Favorite** | Produse salvate + **Traseu gustos**: un drum prin până la 10 producători salvați, ordonat cel-mai-apropiat-următor, deschis în Google Maps |

**Pagina produsului:** descriere, atestat (nr., an, explicație), rating, adresa punctului de lucru, minihartă, distanța și timpul estimat, **traseu calculat în aplicație** (durată și km reali prin MapKit), navigație cu **Apple Maps / Google Maps / Waze**, alte produse de la același producător, produse similare pe o rază de 60 km, partajare, copiere adresă.

## Date și curățare

- Sursa: `GET https://cpac.afir.info/GetListaProduseData?q=all&fCp=…&fTa=…&ps=250&pn=1..22` (JSON public folosit de site; maxim 250 pe pagină, paginile încep de la 1).
- Coordonatele sunt în `CV1` / `CV2`. Aplicația acceptă virgulă ca separator zecimal, corectează lat/lon inversate și, unde lipsesc sau sunt în afara țării, pune pinul în reședința de județ (marcat „locație aproximativă”).
- Județele sunt normalizate (ş/ţ vechi → ș/ț, „Satu-Mare” → „Satu Mare”) și mapate pe regiuni istorice.
- Anii de atestat absurzi (0, 9999) sunt ignorați.

## Structură

```
GustRomanesc/
  App/GustRomanescApp.swift        intrare, taburi, ecran de încărcare
  Models/Product.swift              model brut CPAC + produs curățat
  Models/Taxonomy.swift             categorii, atestate (cu explicații), regiuni, sortări
  Models/Geo.swift                  parsare adrese/coordonate, centre de județ, distanțe
  Services/CatalogStore.swift       descărcare paralelă, cache, indexuri, căutare
  Services/LocationService.swift    locație + județul curent (geocodare inversă)
  Services/Directions.swift         Apple Maps / Google Maps / Waze, traseu MapKit
  Services/Favorites.swift, AppRouter.swift
  Views/…                           Acasă, Hartă (MKMapView cu clustere), Regiuni, Caută, Favorite, Detaliu, Despre
```

## Înainte de App Store

- Codul nu a fost compilat încă (a fost scris fără Xcode); la primul build pot apărea mici ajustări.
- Pune echipa de semnare și, eventual, alt Bundle ID.
- Datele aparțin AFIR; aplicația menționează sursa și precizează că nu e afiliată. Merită un email către AFIR pentru acord de reutilizare înainte de publicare.
- Politica de confidențialitate: locația e folosită doar pe dispozitiv (textul e deja în ecranul Despre).
