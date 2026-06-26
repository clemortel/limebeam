# IPTV Flutter App — Architecture

Canonical reference for how code is organised. New code must follow this.
The `flutter-architecture-enforcer` agent checks these rules before commits.

## 1. Monorepo layout (Melos)

Mirrors Stairling's libraries / parts / forks split.

```
packages/
  libraries/
    iptv_core/        Failures, AsyncState, http base, env, shared models/utils
    iptv_ui/          Publishable design system — pure widgets, NO business logic
    iptv_api/         HttpService + provider clients (Xtream Codes, M3U, XMLTV)
    iptv_auth/        Portal credentials, multi-profile, parental PIN
    iptv_playlist/    M3U/M3U8 + Xtream playlist parsing & sync
    iptv_epg/         XMLTV EPG fetch, cache, now/next lookup
    iptv_live/        Live channels + categories      <- reference 4-layer impl
    iptv_vod/         Movies (VOD)
    iptv_series/      Series / seasons / episodes
    iptv_player/      Playback abstraction (wraps media_kit / video_player)
    iptv_favorites/   Favorites + continue-watching / resume positions
  parts/
    iptv_home_part/   Composed home dashboard flow
    iptv_player_part/ Full player screen + controls + EPG overlay
    iptv_settings_part/ Profiles, parental, playback prefs
  forks/              Any patched dependency
```

Top-level `lib/` stays thin: `main_*.dart` flavor entrypoints, `bootstrap.dart`,
`injection.dart`, `router/`. Workspace tasks run via the `melos:` scripts in the
root `pubspec.yaml` (Dart pub workspace).

## 2. The four layers (per feature library)

```
<feature>/lib/src/
  models/          Freezed + JSON: Channel, Category, EpgEntry…
  infrastructure/  Repository (@LazySingleton, Either<Failures, T>)
  riverpods/       Notifiers (@riverpod) + providers.dart wrappers
  ui/              ConsumerWidgets, exhaustive switch on AsyncState
```

Keep implementation private under `src/`; expose a single barrel `<feature>.dart`.
`iptv_live` is the worked reference — copy its shape.

## 3. State management — custom AsyncState

Do NOT use Riverpod's `AsyncValue`. Reuse the 4-state union from `iptv_core`:

```dart
AsyncState.idle()              // initial / reset
AsyncState.loading()           // fetching playlist / EPG / stream auth
AsyncState.success(T data)
AsyncState.error(Failures failure)
```

Widgets consume it with an exhaustive `switch` and **no default case**, so a new
state is a compile error.

## 4. Error handling

`Failures` is a Freezed union in `iptv_core` (network variants + IPTV-specific:
`invalidPlaylist`, `portalAuth`, `streamUnavailable`, `epgUnavailable`).
Repositories return `Future<Either<Failures, T>>`, wrap I/O in try/catch, and
funnel errors through `catchError(error, stackTrace)`. `FailuresX.computeErrorMessage()`
keeps `iptv_ui` primitive-only.

## 5. Layer patterns

| Layer      | Pattern |
|------------|---------|
| Repository | `@LazySingleton(as: I…)`, `Either<Failures, T>`, try/catch → `catchError`. |
| Notifier   | `@riverpod` class; `build()` triggers fetch and returns `AsyncState.loading()`; `.fold()` the Either into success/error. `@Riverpod(keepAlive: true)` for long-lived caches (playlist, EPG, favorites). |
| Provider   | `providers.dart` bridges GetIt repositories into Riverpod. |
| Widget     | `ConsumerWidget` + exhaustive switch on `AsyncState`. Read via `ref`, never prop-drill. |

## 6. IPTV-specific decisions baked in early

- **Provider abstraction** — `IPlaylistSource` (in `iptv_api`) with
  `XtreamCodesClient` / `M3uClient`. Rest of the app depends on the interface.
- **Player abstraction** — `iptv_player` exposes `PlaybackController`; media_kit
  stays behind the package boundary.
- **Heavy caching** — persist parsed playlists/EPG (Hive/Isar/sqlite); network is
  a sync source. `keepAlive: true` notifiers + silent refresh avoid flicker.
- **Parse off the UI isolate** — M3U/XMLTV parsing of thousands of entries runs in
  `compute()`/an isolate inside the repository.
- **TV / D-pad** — `iptv_ui` components use `Focus`/`FocusNode` (see `IptvFocusable`)
  with focus states in the design tokens.
- **Immutable + IList** — Freezed everywhere; `IList` for all collections in
  models, state, signatures, fixtures.

## 7. Code conventions

- No magic numbers — model constants (`Channel.maxRetryCount`), design tokens
  (`IptvSpacing.spacing10`), or `_k`-prefixed private file constants.
- No `Widget _buildX()` helpers and no top-level Widget-returning functions —
  extract real widget classes. `void showParentalPinDialog(...)` is fine.
- No `?? Default()` in widget builds — cache empty/default instances in state.
- All business logic, timers, debouncing live in notifiers — never in widget
  state.
- Explicit types everywhere, `const` constructors, English, comments ≤80 chars.
- `iptv_ui` is publishable → zero business-logic deps. Components take primitives
  + callbacks; call sites compute primitives via `iptv_core` helpers.

## 8. DI, routing, codegen

- **GetIt + @injectable** service locator (`injection.dart` with `@InjectableInit`);
  Riverpod for state/DI on top.
- **AutoRoute** declarative routing with `AuthGuard` (portal logged-in) and
  `ParentalGuard` (PIN-gated). Sub-routers: AuthRouter, HomeRouter, PlayerRouter.
- Run `melos run build_runner` after touching routes, `@freezed`, `@riverpod`, or
  `@GenerateMocks`.

## 9. Testing

80% coverage goal, Arrange-Act-Assert, descriptive `should …` names. Always cover
success / error / edge cases. Mock repositories with Mockito + `provideDummy` for
`Either`/`AsyncState`. High-value targets: M3U/XMLTV parser (malformed input,
encodings), now/next EPG lookup at time boundaries, resume-position logic,
category filtering/search.

## 10. Tooling

- `melos.yaml` scripts + `analysis_options.yaml` (base) / `analysis_options.ci.yaml`.
- Custom agents: `flutter-architecture-enforcer`, `flutter-package-analyzer`.
- Skills: `freezed-class`, `concrete-repository`, `repository-method`,
  `riverpod-notifier-action`, `async-state-widget`, `flutter-test-notifier`.
