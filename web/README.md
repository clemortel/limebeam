# LimeBeam — site (privacy & support)

Static [Astro](https://astro.build) site serving the legal pages referenced by
the App Store / Play Store listings. Isolated from the Flutter workspace (its own
`package.json`, plain Node — it does not touch the Dart pub workspace).

## Pages

| URL | Fichier |
|-----|---------|
| `/` , `/en/` | landing |
| `/privacy` , `/en/privacy` | **politique de confidentialité** (URL des fiches) |
| `/support` , `/en/support` | aide + contact |

## Dev / build

```sh
cd web
npm install
npm run dev      # http://localhost:4321
npm run build    # -> web/dist/  (static)
```

## Déploiement — Cloudflare Pages

1. Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git**.
2. Sélectionne ce repo. Réglages de build :
   - **Root directory**: `web`
   - **Build command**: `npm run build`
   - **Build output directory**: `dist`
3. Le projet est servi sur `https://<nom-projet>.pages.dev`.
   - ⚠️ Si le nom n'est pas `limebeam`, mets à jour `astro.config.mjs` (`site`)
     **et** les URLs dans `ios/fastlane/metadata/*/{privacy,support,marketing}_url.txt`.
4. Plus tard : connecte le domaine `limebeam.app` (Pages → Custom domains) puis
   repasse les URLs des fiches sur `https://limebeam.app/...`.

## Rappel store

- **Apple** : l'URL de confidentialité se renseigne via la fiche (déjà câblée
  dans `ios/fastlane/metadata/*/privacy_url.txt`).
- **Google Play** : l'URL de confidentialité se colle dans la console
  (**Politique de confidentialité** + section **Data safety**) — `supply` ne la
  gère pas. Utilise `https://<projet>.pages.dev/privacy`.
