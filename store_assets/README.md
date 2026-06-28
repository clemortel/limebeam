# Store assets

Generated from the brand SVGs in `files/` via `rsvg-convert`.

| Fichier | Taille | Usage |
|---|---|---|
| `play_feature_1024x500.png` | 1024×500 | **Play Store — Feature graphic** (bandeau de présentation). |
| `play_icon_512.png` | 512×512 | **Play Store — Icône haute résolution** (carré plein, Google masque). |
| `app_icon_1024.png` | 1024×1024 | Icône d'app arrondie (référence ; déjà câblée via flutter_launcher_icons). |

## Régénérer
```sh
rsvg-convert -w 1024 -h 500 files/limebeam_feature_graphic.svg -o store_assets/play_feature_1024x500.png
rsvg-convert -w 512  -h 512 files/limebeam_appicon_square.svg   -o store_assets/play_icon_512.png
```

## Icône d'app dans l'app (iOS/Android)
La source est `assets/branding/limebeam_appicon_1024.png` (déjà en place). Pour la
régénérer depuis le SVG puis recréer toutes les tailles :
```sh
rsvg-convert -w 1024 -h 1024 files/limebeam_appicon.svg -o assets/branding/limebeam_appicon_1024.png
dart run flutter_launcher_icons
```

## App Store
L'icône iOS est gérée par flutter_launcher_icons (pas de feature graphic requis ;
App Store n'utilise que les screenshots + l'icône).
