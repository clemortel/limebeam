# Green IPTV

IPTV client (live, VOD, series) built as a Melos monorepo.

> Architecture & conventions: see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
> `packages/libraries/iptv_live` is the worked reference for the 4-layer pattern.

## Layout

```
lib/                     Thin app shell — flavor entrypoints, bootstrap, DI, router
packages/libraries/      Foundation + feature libraries (4-layer each)
packages/parts/          Composed screens/flows
forks/                   Patched dependencies
docs/                    Architecture reference
```

## Getting started

This is a **Dart pub workspace** (Melos 7+): the root `pubspec.yaml` lists every
member under `workspace:` and each package declares `resolution: workspace`.

```bash
flutter pub get          # resolves the whole workspace (shared lockfile)

# Code generation — run per package that needs it (freezed / json / riverpod /
# mockito / auto_route). From the repo root:
dart run build_runner build --delete-conflicting-outputs            # app (router)
for d in packages/libraries/*; do (cd "$d" && \
  dart run build_runner build --delete-conflicting-outputs); done

dart analyze             # static analysis (0 issues expected)
flutter test             # run a package's tests from its directory
```

Melos scripts also live under the `melos:` key in the root `pubspec.yaml`
(`analyze`, `build_runner`, `test`).

Run a flavor:

```bash
flutter run --target lib/main_development.dart
flutter run --target lib/main_production.dart
```

## Status

Xtream auth flux + design system integrated (Xtream-only this round):

- **Design system** — `iptv_ui` ships `AppTheme` (`AppColors`/`AppType`/`AppSpace`
  /`AppRadius`/`AppMotion`) + the full widget kit (buttons, chips, badges, poster
  card, channel row, live tile, input, carousel, toast, sheet, skeleton, empty).
- **Xtream flux** — onboarding (Welcome → type → form → résumé → connecting →
  succès), `XtreamCodesClient` (player_api.php + xmltv.php), secure-storage
  credentials, eager sync (live/VOD/series/EPG) cached in Hive, and the TV +
  Films & Séries tabs render from cache. EPG now/next shows on channel rows.
- **Deferred**: video playback (tap → toast), Accueil dashboard, Search, M3U,
  EPG guide grid, multi-profile, parental PIN.

Generated files (`*.freezed.dart` / `*.g.dart` / `*.gr.dart` / `*.mocks.dart`)
are gitignored — run code generation (above) after cloning. `dart analyze`
reports **no issues**; unit tests pass for `iptv_api`, `iptv_auth`, `iptv_live`.
