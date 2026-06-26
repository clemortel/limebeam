import "package:freezed_annotation/freezed_annotation.dart";

import "../failures/failures.dart";

part "async_state.freezed.dart";

/// The project's custom 4-state union. Deliberately replaces Riverpod's
/// AsyncValue so every consumer handles exactly these states.
///
/// Widgets consume it with an exhaustive `switch` and NO default case, so a
/// new state becomes a compile error rather than a silent fallthrough.
///
/// Run `melos run build_runner` after editing this union.
@freezed
sealed class AsyncState<T> with _$AsyncState<T> {
  const factory AsyncState.idle() = AsyncIdle<T>; // initial / reset
  const factory AsyncState.loading() = AsyncLoading<T>; // fetching
  const factory AsyncState.success(T data) = AsyncSuccess<T>;
  const factory AsyncState.error(Failures failure) = AsyncError<T>;
}
