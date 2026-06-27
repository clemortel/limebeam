# Fiches store (App Store + Play Store) — pilotage CLI

Les fiches sont versionnées sous forme de fichiers texte et poussées via fastlane
(`deliver` pour iOS, `supply` pour Android). Langues : **fr-FR** + **en-US**.

## Arborescence

```
ios/fastlane/metadata/
  fr-FR/ , en-US/        name, subtitle, description, keywords,
                         promotional_text, release_notes, *_url
  review_information/    notes + contact + (demo vide = pas de login requis)
  copyright.txt
android/fastlane/metadata/android/
  fr-FR/ , en-US/        title, short_description, full_description
                         changelogs/1.txt   (1 = versionCode)
```

## Commandes

Pré-requis (une fois) : `cd ios && bundle install` et `cd android && bundle install`.

| But | Commande |
|-----|----------|
| **Tout livrer (codegen+analyze+iOS+Android)** | `bin/release.sh` (`ios`/`android`/`--no-deploy` en option) |
| Créer la fiche App Store (1×) | `cd ios && bundle exec fastlane create_app` |
| Pousser la fiche App Store | `cd ios && bundle exec fastlane upload_metadata` |
| Pousser la fiche Play Store | `cd android && bundle exec fastlane upload_metadata` |
| Binaire iOS → TestFlight | `cd ios && bundle exec fastlane beta` |
| Binaire Android → Play (interne) | `cd android && bundle exec fastlane beta` |

> La lane `android beta` pousse aussi la fiche + le changelog en même temps que
> l'AAB. La lane `ios beta` n'envoie que le binaire (métadonnée séparée).
> L'app Play Store existe déjà → `upload_metadata` fonctionne directement.

## À REMPLIR avant de pousser (placeholders)

- **URL de confidentialité** — la page existe désormais dans `web/` (Astro) et
  les fichiers `*/privacy_url.txt` pointent sur `https://limebeam.pages.dev/...`.
  Il faut **déployer `web/` sur Cloudflare Pages** (voir `web/README.md`) pour que
  l'URL réponde (Apple ET Google la vérifient). Si le nom de projet Pages diffère
  de `limebeam`, mets à jour ces fichiers. Côté **Play Console**, colle aussi
  l'URL de confidentialité (champ dédié + Data safety) — `supply` ne la gère pas.
- **Téléphone review iOS** — `ios/fastlane/metadata/review_information/phone_number.txt`
  contient un placeholder `+33600000000` → mets ton vrai numéro.
- **Catégorie** : iOS = `ENTERTAINMENT` (dans la lane). Ajuste si besoin.

## Ce qui reste MANUEL (non automatisable proprement)

1. **Screenshots** — requis par les deux stores (iOS : 6.7" + 6.5" min ;
   Android : téléphone). Un harnais Flutter `integration_test` est fourni : il
   pilote l'app via le **mode démo** (sans identifiants) et capture welcome /
   accueil / films & séries / réglages / tip jar. Lance-le **par taille
   d'écran** sur le simulateur/émulateur voulu :

   ```sh
   flutter drive \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/screenshots_test.dart \
     -d <device_id>      # ex. un iPhone 15 Pro Max (6.7"), puis un 6.5", etc.
   ```

   Les PNG atterrissent dans `screenshots/`. Déplace-les ensuite dans
   `ios/fastlane/screenshots/<locale>/` et
   `android/fastlane/metadata/android/<locale>/images/phoneScreenshots/`, puis
   retire les `skip_screenshots` / `skip_upload_screenshots` des lanes.
   (Sélecteurs par libellé dans le test — ajuste si la copie UI change.)
2. **Apple App Privacy** (nutrition labels) et **Google Data safety** — formulaires
   console. LimeBeam : aucune collecte (déclarer « Données non collectées »).
3. **Classification d'âge** — questionnaire console (probable 17+).
4. **Produits in-app** Tip Jar — `tip.coffee/meal/devsession` (iOS, déjà créés) et
   `tip-coffee/meal/devsession` (Play — traits d'union, pas underscores).

## Notes de review (déjà rédigées)

`ios/fastlane/metadata/review_information/notes.txt` explique que l'app ne fournit
aucun contenu et indique au reviewer d'utiliser **« Essayer la démo »** (aucun
identifiant requis). Reprends le même texte côté Play Console (champ instructions).
