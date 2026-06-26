# LimeBeam — Charte graphique

> Lecteur IPTV premium · iOS + Android · 100 % client-side (player pur, aucun backend).
> Thème par défaut : **dark**. Accent : **lime**, utilisé comme un scalpel, jamais comme un seau de peinture.

Ce document est la référence visuelle unique de LimeBeam : marque, couleurs, typographie,
espacements, composants, et mapping Flutter (`AppTheme`). Toute valeur est un token nommé —
aucun widget ne doit coder une couleur ou une taille en dur.

---

## 1. Marque

### 1.1 Nom

**LimeBeam** — écrit en un seul mot, casse interne « LB ». Jamais « Lime Beam », « Limebeam »
ou « LIMEBEAM ». Le wordmark est bicolore : `Lime` en `text/primary`, `Beam` en `accent`.

### 1.2 Le symbole (the beam)

Un point source lumineux qui projette un faisceau triangulaire vers la droite — il dit
littéralement *Lime* (couleur) + *Beam* (faisceau / diffusion). Le sens (gauche → droite)
évoque la lecture et la diffusion du flux. Une encoche intérieure sombre (16 % d'opacité)
donne de la profondeur sans bruit.

**Règles d'usage :**
- Le faisceau pointe **toujours** vers la droite. Ne pas le retourner.
- Zone de protection : un espace libre égal au rayon du point source de chaque côté.
- Taille minimale du symbole seul : 24 px. En dessous, l'encoche intérieure disparaît
  (utiliser la version « solid » sans notch).
- Ne jamais : ajouter d'ombre portée, de dégradé, de contour, ni recolorer le faisceau
  dans une autre teinte que `accent`.

### 1.3 Déclinaisons fournies

| Asset | Fichier | Usage |
|---|---|---|
| App icon | `limebeam_appicon.svg` / `_1024.png` / `_180.png` | Icône iOS/Android, fond `bg/base` arrondi. |
| Symbole seul | `limebeam_mark.svg` / `_512.png` | Splash, header, favicon, watermark player. |
| Lockup horizontal | `limebeam_lockup.svg` / `.png` | Sur fond clair/transparent (onboarding, docs). |
| Lockup sur sombre | `limebeam_lockup_dark.svg` / `.png` | Sur fond sombre, panneau inclus. |

### 1.4 App icon

Fond `bg/base` `#0B0C0E` (soft black, jamais `#000`), faisceau `accent` `#C5F03A`,
rayon de coin iOS standard (≈ 22 % du côté). Le faisceau est centré verticalement,
décalé pour laisser respirer le point source à gauche.

---

## 2. Couleur

Discipline n°1 de l'app : **lime = « tu peux agir là-dessus »**. Rouge = « état en direct
maintenant ». Rien d'autre ne capte l'attention saturée. Tout le reste est un gris calibré
sur base soft-black.

### 2.1 Surfaces (base sombre)

| Token | Hex | Rôle |
|---|---|---|
| `bg/base` | `#0B0C0E` | Fond d'app, derrière tout. Soft black. |
| `bg/surface` | `#141619` | Cartes, feuilles, lignes de liste, tab bar. |
| `bg/elevated` | `#1D2024` | Surfaces surélevées : modales, menus, ligne focus, panneaux player. |
| `bg/input` | `#191C20` | Remplissage des champs de saisie. |

### 2.2 Bordures & séparateurs

| Token | Hex | Rôle |
|---|---|---|
| `border/subtle` | `rgba(255,255,255,0.08)` | Séparateur fin par défaut, bord de carte. |
| `border/default` | `rgba(255,255,255,0.14)` | Bordure d'input, séparation marquée. |
| `border/strong` | `#2A2E33` | Input focus, contour de carte sélectionnée (non-accent). |

### 2.3 Texte (sur sombre)

| Token | Hex | Rôle |
|---|---|---|
| `text/primary` | `#F4F6F8` | Titres, corps principal. Blanc cassé. |
| `text/secondary` | `#A7AEB6` | Sous-titres, métadonnées, légendes. |
| `text/tertiary` | `#6B7280` | Indices, placeholders, libellés désactivés. |
| `text/onAccent` | `#0B0C0E` | Texte/icône **sur** un fond lime. Quasi-noir — le lime ne porte jamais de texte clair. |

### 2.4 Accent — lime (scalpel)

| Token | Hex | Rôle |
|---|---|---|
| `accent/default` | `#C5F03A` | CTA primaire, onglet actif, anneau de focus, barre de progression, badge NEW, play. |
| `accent/pressed` | `#A8D625` | État pressé des surfaces accent. |
| `accent/subtle` | `#2E3A12` | Lavis accent discret : fond de chip sélectionné, teinte derrière icône. |

**Usages autorisés de `accent/default` :** boutons primaires, onglet actif, anneau de
focus/sélection, remplissage de progression vidéo, badge NEW, glyphe play, le ❤️ favori actif,
le bouton « Regarder » d'une chaîne live. **Interdits :** grands aplats, bannières pleine
largeur, texte de corps, plus de ~5 % des pixels d'un écran.

### 2.5 États sémantiques

| Token | Hex | Rôle |
|---|---|---|
| `state/live` | `#FF5247` | Badge LIVE + point de statut direct. Rouge, par convention. **Jamais lime.** |
| `state/success` | `#3DD68C` | Connexion OK, source valide, confirmations (« Merci ❤️ »). |
| `state/warning` | `#F5A623` | EPG périmé, données partielles, échecs doux. |
| `state/error` | `#FF5247` | Identifiants invalides, échec de flux, erreurs de validation. |
| `state/offline` | `#6B7280` | Hors ligne / inconnu / chaîne désactivée. |

### 2.6 Map des badges

| Badge | Fond | Texte |
|---|---|---|
| `LIVE` | `state/live` | `#FFFFFF` |
| `NEW` | `accent/default` | `text/onAccent` |
| `VOD` / `SERIES` / `4K` / `HD` | `bg/elevated` | `text/secondary` |
| `EN COURS` (reprise) | `accent/subtle` | `accent/default` |
| `18+` (parental) | `state/error` (contour) | `state/error` |

### 2.7 Thème clair (Light)

LimeBeam supporte Light/Dark/Système. Le lime reste identique (il fonctionne sur les deux) ;
seules les surfaces et le texte s'inversent. Le texte sur lime reste `text/onAccent` quasi-noir.

| Token | Light | Rôle |
|---|---|---|
| `bg/base` | `#F7F8F5` | Fond d'app clair (légèrement chaud, pas blanc pur). |
| `bg/surface` | `#FFFFFF` | Cartes, lignes. |
| `bg/elevated` | `#FFFFFF` + ombre `elev/2` | Modales, menus. |
| `bg/input` | `#F0F1EE` | Champs. |
| `text/primary` | `#16181B` | Titres, corps. |
| `text/secondary` | `#5A616B` | Sous-titres. |
| `text/tertiary` | `#9AA1AB` | Indices. |
| `border/subtle` | `rgba(0,0,0,0.08)` | Séparateurs. |
| `accent/subtle` | `#EAF7C4` | Lavis accent clair. |

> Le player reste **toujours** sur fond noir (`#000`) quel que soit le thème — la vidéo prime.

### 2.8 Mapping Flutter

```dart
class AppColors {
  // surfaces (dark)
  static const bgBase     = Color(0xFF0B0C0E);
  static const bgSurface  = Color(0xFF141619);
  static const bgElevated = Color(0xFF1D2024);
  static const bgInput    = Color(0xFF191C20);
  // borders
  static const borderSubtle  = Color(0x14FFFFFF);
  static const borderDefault = Color(0x24FFFFFF);
  static const borderStrong  = Color(0xFF2A2E33);
  // text
  static const textPrimary   = Color(0xFFF4F6F8);
  static const textSecondary = Color(0xFFA7AEB6);
  static const textTertiary  = Color(0xFF6B7280);
  static const textOnAccent  = Color(0xFF0B0C0E);
  // accent
  static const accent        = Color(0xFFC5F03A);
  static const accentPressed = Color(0xFFA8D625);
  static const accentSubtle  = Color(0xFF2E3A12);
  // semantic
  static const live    = Color(0xFFFF5247);
  static const success = Color(0xFF3DD68C);
  static const warning = Color(0xFFF5A623);
  static const error   = Color(0xFFFF5247);
  static const offline = Color(0xFF6B7280);

  // light overrides
  static const lBgBase     = Color(0xFFF7F8F5);
  static const lBgSurface  = Color(0xFFFFFFFF);
  static const lBgInput    = Color(0xFFF0F1EE);
  static const lTextPrimary   = Color(0xFF16181B);
  static const lTextSecondary = Color(0xFF5A616B);
  static const lTextTertiary  = Color(0xFF9AA1AB);
  static const lAccentSubtle  = Color(0xFFEAF7C4);
}
```

---

## 3. Typographie

Police système (SF Pro sur iOS, Roboto sur Android via Flutter ; `Inter` comme fallback
explicite pour la cohérence cross-platform). Une famille — le poids et la taille portent la
hiérarchie. Le réglage « taille de police » multiplie l'échelle (`textScale`).

| Token | Taille / Interligne | Poids | Usage |
|---|---|---|---|
| `display` | 34 / 40 | 700 | Hero onboarding uniquement. |
| `h1` | 28 / 34 | 700 | Titres d'écran. |
| `h2` | 22 / 28 | 600 | En-têtes de section, titre de fiche. |
| `h3` | 17 / 22 | 600 | Titres de carte, ligne primaire de liste, en-tête carrousel. |
| `body` | 15 / 22 | 400 | Synopsis, descriptions, libellés réglages. |
| `bodyStrong` | 15 / 20 | 600 | Corps emphatique, libellés de bouton. |
| `caption` | 13 / 18 | 400 | Métadonnées (année · genre · durée), texte secondaire. |
| `micro` | 11 / 14 | 600 | Badges, chips, libellés d'onglet, overlines (MAJUSCULES pour badges). |

**Confort de lecture du synopsis :** `body` 15/22, `text/secondary`, ~70 caractères/ligne max.
Les synopsis longs sont tronqués à 3 lignes avec un « Plus » sur la fiche.

**Échelle typo (réglage Interface) :** `Normal` ×1.0 · `Large` ×1.15. Appliquée globalement
via `MediaQuery.textScaler`, plafonnée pour ne pas casser les layouts (max ×1.3).

```dart
class AppType {
  static const _f = 'Inter';
  static const display    = TextStyle(fontFamily:_f, fontSize:34, height:40/34, fontWeight:FontWeight.w700);
  static const h1         = TextStyle(fontFamily:_f, fontSize:28, height:34/28, fontWeight:FontWeight.w700);
  static const h2         = TextStyle(fontFamily:_f, fontSize:22, height:28/22, fontWeight:FontWeight.w600);
  static const h3         = TextStyle(fontFamily:_f, fontSize:17, height:22/17, fontWeight:FontWeight.w600);
  static const body       = TextStyle(fontFamily:_f, fontSize:15, height:22/15, fontWeight:FontWeight.w400);
  static const bodyStrong = TextStyle(fontFamily:_f, fontSize:15, height:20/15, fontWeight:FontWeight.w600);
  static const caption    = TextStyle(fontFamily:_f, fontSize:13, height:18/13, fontWeight:FontWeight.w400);
  static const micro      = TextStyle(fontFamily:_f, fontSize:11, height:14/11, fontWeight:FontWeight.w600);
}
```

---

## 4. Espacement, radius, élévation, motion

### 4.1 Espacement — base 4pt

| Token | Valeur | Usage |
|---|---|---|
| `space/1` | 4 | Gap icône ↔ libellé. |
| `space/2` | 8 | Stacks serrés, padding de badge. |
| `space/3` | 12 | Padding interne de carte, gaps de ligne. |
| `space/4` | 16 | **Marge horizontale d'écran par défaut.** |
| `space/5` | 20 | Entre cartes empilées. |
| `space/6` | 24 | Rythme vertical de section. |
| `space/8` | 32 | Ruptures de section majeures. |
| `space/10` | 40 | Respiration hero / empty-state. |

### 4.2 Radius

| Token | Valeur | Usage |
|---|---|---|
| `radius/sm` | 8 | Chips, badges, inputs. |
| `radius/md` | 12 | Cartes, boutons, lignes. |
| `radius/lg` | 16 | Feuilles, modales, posters. |
| `radius/xl` | 24 | Coins haut de bottom sheet. |
| `radius/full` | 999 | Pills, avatar, point live. |

### 4.3 Élévation (dark = teinte de surface, pas d'ombre)

En UI sombre, l'élévation se lit via une **surface plus claire**, pas une ombre portée.

| Token | Surface | Ombre |
|---|---|---|
| `elev/0` | `bg/base` | aucune |
| `elev/1` | `bg/surface` | aucune |
| `elev/2` | `bg/elevated` | `0 8 24 rgba(0,0,0,0.4)` (feuilles/modales seulement) |
| `elev/player` | scrim overlay | dégradé haut+bas, cf. Player |

### 4.4 Motion

| Token | Durée | Courbe | Usage |
|---|---|---|---|
| `motion/fast` | 120ms | easeOut | Taps, toggles de chip, anneau de focus. |
| `motion/base` | 220ms | easeInOut | Présentation de feuille, fondu d'onglet, scale au press. |
| `motion/slow` | 360ms | easeInOutCubic | Show/hide overlay player, transition fullscreen. |
| Press scale | — | — | Cartes & boutons → `0.97` au press sur `motion/fast`. |

```dart
class AppSpace  { static const x1=4.0,x2=8.0,x3=12.0,x4=16.0,x5=20.0,x6=24.0,x8=32.0,x10=40.0; }
class AppRadius { static const sm=8.0,md=12.0,lg=16.0,xl=24.0,full=999.0; }
class AppMotion {
  static const fast = Duration(milliseconds:120);
  static const base = Duration(milliseconds:220);
  static const slow = Duration(milliseconds:360);
}
```

---

## 5. États des composants (uniformes)

Tout composant interactif définit : **default · pressed · focused · disabled · (error si saisie)**.

- **Pressed :** scale `0.97` + surface d'un cran plus claire (`surface`→`elevated`).
- **Focused :** anneau `accent/default` 2pt, `radius+2` (prêt pour télécommande/clavier).
- **Disabled :** opacité `0.4`, pas de feedback au press.
- **Selected** (chip/onglet/carte) : fond `accent/subtle` + libellé/icône `accent/default`, ou anneau accent.

---

## 6. Bibliothèque de composants

Chaque composant → un widget Flutter réutilisable (Widgetbook-friendly).

| Composant | Widget | Notes clés |
|---|---|---|
| Bouton primaire | `PrimaryButton` | fond `accent`, texte `text/onAccent`, h50, `radius/md`, 1 par écran max. |
| Bouton secondaire | `SecondaryButton` | transparent + `border/default`. |
| Bouton texte | `TextButtonX` | libellé `accent`. |
| Bouton icône | `IconButtonX` | cercle `bg/elevated` 44×44. |
| Bouton destructif | `DangerButton` | contour `state/error`. |
| Chip / filtre | `FilterChipX` | h34, `radius/full`, sélectionné = `accent/subtle`/`accent`. |
| Badge | `Badge` | h20, MAJ `micro`, cf. map §2.6. |
| Carte poster (VOD) | `MediaPosterCard` | 2:3, badge, barre de reprise, états vu/en cours. |
| Ligne chaîne (live) | `ChannelRow` | h64, logo 44, point live, progression programme. |
| Tuile live | `LiveTile` | 16:9, badge LIVE, scrim. |
| Champ | `AppInput` | h50, `bg/input`, helper slot, états focus/error. |
| Carrousel | `SectionCarousel` | titre + « Voir tout », cartes scrollables. |
| Toast | `AppToast` | bas, au-dessus tab bar, icône d'état colorée seulement. |
| Bottom sheet | `AppBottomSheet` | `bg/elevated`, coins `radius/xl`, grab handle. |
| Skeleton | `SkeletonBox` | shimmer, miroir du layout final, jamais de spinner pour les listes. |
| Empty/Error | `EmptyState` | icône + titre + phrase + 1 action. |
| Toggle ❤️ favori | `FavoriteToggle` | cœur, se remplit `accent` à l'activation, temps réel. |
| Barre de reprise | `ResumeBar` | 3pt `accent` sur track `border/subtle`, % de position. |

---

## 7. Traitements visuels des features

### 7.1 Favoris

- Toggle ❤️ temps réel sur chaînes / films / séries.
- Inactif : contour `text/secondary`. Actif : rempli `accent/default`, micro-animation de
  scale (`motion/fast`, pop à 1.15 → 1.0).
- Accessible via : long-press sur carte/ligne, bouton sur la fiche, swipe sur ligne TV.
- Pseudo-catégorie « Favoris » épinglée en tête des chips TV et un filtre VOD.

### 7.2 Continue Watching

- Sessions de visionnage : position / durée / %, persistées client-side (WatchHistory).
- Retrait automatique de la liste à ≥ 90 % de progression (considéré « terminé »).
- Reprise en un tap : la carte rouvre le player à la position exacte.
- Carte = thumbnail 16:9 + `ResumeBar` (% lime) + « X min restantes » en `caption`.
  Pour le live, affiche le badge LIVE au lieu de la barre.
- Section en tête de l'Accueil (action n°1 du retour utilisateur).

### 7.3 Réglages complets

**Lecture**
- Qualité : Auto · Haute · Limitée (économie data) — segmented.
- Lecture auto de l'épisode suivant : toggle.
- Reprise au lancement (mémoriser dernière position/chaîne) : toggle.
- Gestes du player (volume/luminosité au swipe) : on/off.

**Interface**
- Thème : Dark (défaut) · Light · Système — segmented.
- Taille de police : Normal · Large.
- Langue de l'app : liste.

**Contrôle parental** (cf. 7.4)

**Soutenir le développeur** (cf. 7.5)

**À propos & légal**
- « LimeBeam ne fournit aucun contenu. L'application lit vos playlists ou identifiants IPTV. »
- Politique de confidentialité · CGU · Licences open-source · Version.

### 7.4 Contrôle parental

- PIN 4 chiffres : configuration initiale + modification (saisie de l'ancien PIN requise).
- Masquage des catégories 18+ **partout** : live, VOD, séries, recherche, EPG. Une catégorie
  masquée n'apparaît dans aucune liste, aucun résultat, aucun guide.
- Guard : tenter d'accéder à un contenu protégé → prompt PIN (clavier numérique custom,
  feedback `state/error` au mauvais code, 4 points qui se remplissent en `accent`).
- Déverrouillage de session : une fois le PIN validé, la session reste déverrouillée (option
  « Verrouiller à l'ouverture » pour re-verrouiller au lancement).
- Badge `18+` (contour `state/error`) sur tout contenu sensible visible quand le masquage est off.

### 7.5 Tip Jar — « Soutenir le développeur »

- Section chaleureuse, ton sincère (pas de dark pattern). Titre « Soutenir le développeur »,
  courte phrase de remerciement.
- 3 montants, achats in-app **consumables** via `in_app_purchase` — aucun lien externe :
  - Un café ☕ (petit)
  - Un repas 🍱 (moyen)
  - Grosse session dev 💻 (grand)
- Cartes de don : `bg/surface`, emoji + libellé + prix, le montant moyen peut être discrètement
  mis en avant (contour `accent` 2pt, sans changer le fond).
- Après achat : toast « Merci ❤️ » (`state/success` icône), statut **supporter** mémorisé.
- Rappel non intrusif : bannière douce après usage (seuil ~10 lancements), `bg/surface`,
  dismissible, **désactivable** définitivement. Jamais de pop-up bloquant.
- Un supporter ne revoit jamais la bannière de rappel.

---

## 8. États globaux, erreurs & edge cases

- **AsyncState partout** : chaque écran a `loading` (skeletons) / `data` / `error`.
- Erreurs IPTV centralisées via `computeErrorMessage` (timeout, flux introuvable,
  identifiants invalides, source injoignable, source vide).
- EPG manquant : « Programme indisponible » en `text/tertiary`, **jamais** une couleur d'erreur.
- Hors ligne : bannière `state/warning` « Hors ligne — contenu limité » ; listes en cache
  estompées ; player bloqué avec « Réessayer ».
- Skeletons obligatoires : carrousels Accueil, grille VOD, lignes de programme TV, grille EPG,
  résultats de recherche. Miroir du layout final, shimmer `motion/slow`.

---

## 9. Architecture & implémentation (transverse)

- **Design system** : `AppTheme` (couleurs/typo/espaces/radius/motion) exposé en
  `ThemeExtension<AppTheme>` ; thème clair + scale typo gérés par le theme, jamais en dur.
- **Architecture 4 couches** : presentation / domain / data / infrastructure.
- **Either<Failures, T>** pour la gestion d'erreur fonctionnelle ; pas d'exceptions qui fuient
  vers l'UI.
- **IList** (collections immuables) pour les états.
- **DI : GetIt** (service locator).
- **Routing : AutoRoute**.
- **Parsing off-isolate** : le parsing M3U/Xtream lourd tourne hors de l'isolate UI (compute /
  isolate dédié) → pas de jank au chargement de grosses playlists.
- **Cible** : iOS + Android, 100 % client-side, aucun backend (player pur).
- **Tests** : WatchHistory (continue-watching), favoris, PlayerController
  (position / reprise / erreurs).

### 9.1 ThemeExtension — squelette

```dart
@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  final Color bgBase, bgSurface, bgElevated, bgInput;
  final Color textPrimary, textSecondary, textTertiary, textOnAccent;
  final Color accent, accentPressed, accentSubtle;
  final Color live, success, warning, error, offline;
  const AppTheme({ required this.bgBase, required this.bgSurface, /* … */ });

  static const dark = AppTheme(
    bgBase: AppColors.bgBase, bgSurface: AppColors.bgSurface, /* … */
  );
  static const light = AppTheme(
    bgBase: AppColors.lBgBase, bgSurface: AppColors.lBgSurface, /* … */
  );

  @override AppTheme copyWith({ /* … */ }) => /* … */;
  @override AppTheme lerp(ThemeExtension<AppTheme>? other, double t) => /* … */;
}

// Usage en widget :
final c = Theme.of(context).extension<AppTheme>()!;
Container(color: c.bgSurface);
```

---

## 10. Ordre de build suggéré

1. `AppTheme` (ThemeExtension dark + light + scale) + kit de widgets §6 en isolation (Widgetbook).
2. Onboarding → ajout de source (M3U + Xtream) + validation + loading/success.
3. TV liste de chaînes + favoris + tri (EPG guide ensuite).
4. Player portrait, puis paysage + gestes + state machine (buffering/playing/error/casting).
5. VOD grille + filtres + fiche (+ épisodes de séries).
6. Continue Watching + WatchHistory (alimente l'Accueil).
7. Accueil (dépend de ce qui précède).
8. Recherche (live + VOD unifiée, respecte le masquage parental).
9. Réglages : Lecture, Interface, Contrôle parental, Tip Jar, À propos.
10. Passe états/skeletons/empty/error sur tous les écrans.
