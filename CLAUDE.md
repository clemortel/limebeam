# Green IPTV — Project Instructions

Melos monorepo IPTV client. **Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
before writing code** — it is the canonical reference for layout and conventions.

## Hard rules (enforced by `flutter-architecture-enforcer`)

- State: use the custom `AsyncState` union from `iptv_core`, never Riverpod's
  `AsyncValue`. Consume with an exhaustive `switch` and NO default case.
- Errors: repositories return `Future<Either<Failures, T>>`, wrap I/O in
  try/catch, funnel through `catchError`. Never leak exceptions upward.
- No magic numbers — model constants, design tokens, or `_k`-prefixed file
  constants only.
- No `Widget _buildX()` helpers / no top-level Widget-returning functions —
  extract real widget classes.
- All business logic / timers / debouncing in notifiers, never in widget state.
- `iptv_ui` is publishable: zero business-logic deps (no `Failures`, no Riverpod).
- Explicit types everywhere, `const` constructors, English, comments ≤80 chars.
- Models immutable (Freezed); collections use `IList` everywhere.

## Layer template

`packages/libraries/iptv_live` is the worked reference. New feature libraries
copy its `src/{models,infrastructure,riverpods,ui}` shape and single barrel.

## Codegen

Run `melos run build_runner` after touching `@freezed`, `@riverpod`,
`@injectable`, routes, or `@GenerateMocks`. Generated files
(`*.freezed.dart`, `*.g.dart`, `*.gr.dart`, `*.config.dart`, `*.mocks.dart`)
are gitignored and the developer's job to regenerate.

## Skills that map to this architecture

`freezed-class`, `concrete-repository`, `repository-method`,
`riverpod-notifier-action`, `async-state-widget`, `flutter-test-notifier`.
