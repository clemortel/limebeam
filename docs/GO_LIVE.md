# LimeBeam — passage en production (étapes manuelles)

Tout le build/upload est automatisé (`bin/release.sh`). Ce qui suit ne se fait
que dans les **consoles / comptes** (impossible en CLI sans ton login).

Repères utiles :
- Bundle / package : `com.limebeam.app`
- Apple : app id `6780801137`, team **Diseed Inc** `84QCKW49ZQ`
- Builds déjà uploadés : iOS TestFlight #2, Android Play interne (versionCode 3)

---

## 0. Site privacy/support en ligne (prérequis des deux stores)

1. Cloudflare → **Workers & Pages → Create → Pages → Connect to Git** → repo
   `clemortel/limebeam`.
2. Réglages build : **Root** `web` · **Build command** `npm run build` ·
   **Output** `dist`.
3. Note l'URL `https://<projet>.pages.dev`. Si le projet ≠ `limebeam`, mets à
   jour `web/astro.config.mjs` (`site`) et
   `ios/fastlane/metadata/*/{privacy,support,marketing}_url.txt`, puis relance
   `cd ios && bundle exec fastlane ios upload_metadata`.
   - URLs finales : `…/privacy` (FR), `…/en/privacy` (EN), idem `/support`.

---

## 1. Achats in-app (Tip Jar) — sur les DEUX stores

Produits **consommables**, mêmes prix conseillés (café < repas < session).

**App Store Connect** → ton app → *Monetization → In-App Purchases* → créer 3
**Consumable** :
- `tip.coffee` · `tip.meal` · `tip.devsession`

**Play Console** → ton app → *Monetize → Products → In-app products* → créer 3 :
- `tip_coffee` · `tip_meal` · `tip_devsession`
  (Play interdit les points — d'où les underscores ; le code choisit le bon id
  selon la plateforme.)

> Tant qu'ils ne sont pas créés + approuvés, l'écran « Soutenir » affiche
> « Bientôt ». Tester sur **device réel** avec un compte **sandbox**.

---

## 2. Screenshots (requis par les deux stores)

Lance le harnais une fois par taille d'écran (simulateur/émulateur ouvert) :

```sh
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d <device_id>
```

Tailles minimales : iOS **6.7"** + **6.5"** ; Android **téléphone**. Les PNG
sortent dans `screenshots/`. Place-les ensuite dans :
- `ios/fastlane/screenshots/<locale>/`
- `android/fastlane/metadata/android/<locale>/images/phoneScreenshots/`
puis retire les `skip_screenshots` / `skip_upload_screenshots` des lanes et
relance `upload_metadata`. (Ou glisse-les à la main dans les consoles.)

---

## 3. App Store Connect — finaliser la fiche & soumettre

1. **TestFlight** : la build #2 « processe » quelques minutes → ajoute-la à un
   groupe de test (interne au moins). Réponds au questionnaire export
   compliance (HTTPS standard → « exempt »).
2. **App Privacy** (*App Information → App Privacy*) : déclare **aucune donnée
   collectée** (Data Not Collected).
3. **Age rating** : questionnaire → contenu fourni par l'utilisateur, non
   filtré → **17+** vraisemblable.
4. **Pricing & Availability** : gratuit + pays.
5. **Screenshots** (étape 2) + vérifier nom/sous-titre/description (déjà
   uploadés FR/EN).
6. **n° de téléphone review** : remplace le placeholder dans
   `ios/fastlane/metadata/review_information/phone_number.txt` (`+33600000000`)
   puis `upload_metadata`, ou saisis-le directement dans *App Review Information*.
   Les notes de review sont déjà rédigées (mode démo, aucun login requis).
7. **Submit for Review** (sélectionne la build #2).

---

## 4. Play Console — finaliser la fiche & soumettre

1. **Politique de confidentialité** (*Policy → App content*) : colle
   `https://<projet>.pages.dev/privacy` (`supply` ne gère pas ce champ).
2. **Data safety** : **aucune donnée collectée/partagée**.
3. **Content rating** : questionnaire (probable PEGI 16/18 selon réponses).
4. **Store listing** : icône + screenshots + feature graphic (1024×500).
5. **Countries / régions** + gratuit.
6. La build est sur le track **interne** (versionCode 3) → quand tout est vert,
   **promeus interne → production** :
   ```sh
   # (lane de promotion à ajouter si tu veux — voir plus bas)
   ```
   ou via la console : *Release → Production → Create release → Add from
   library*.

---

## 5. (Optionnel) domaine limebeam.app

Quand tu l'achètes : Cloudflare Pages → *Custom domains* → ajoute `limebeam.app`,
puis repasse les `*_url.txt` des fiches sur `https://limebeam.app/...` et
`upload_metadata`.

---

## Rappel — livrer une nouvelle build (automatisé)

```sh
bin/release.sh            # iOS TestFlight + Android interne (build no. auto)
bin/release.sh ios        # une seule plateforme
bin/release.sh --no-deploy   # juste compiler/analyser
```
