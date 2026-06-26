import "failures.dart";

/// Pure mapping from [Failures] to a user-facing message.
///
/// Lives in iptv_core so iptv_ui widgets stay primitive-only: call sites
/// compute the String here and pass it into a component.
extension FailuresX on Failures {
  String computeErrorMessage() {
    return switch (this) {
      NetworkError() => "No internet connection. Check your network.",
      ServerError(:final int code) => "Server error ($code). Try again later.",
      NotFound() => "The requested content was not found.",
      Unexpected() => "Something went wrong. Please try again.",
      InvalidPlaylist() => "This playlist could not be read. Check the source.",
      PortalAuthFailure() => "Login failed. Check your portal credentials.",
      StreamUnavailable() => "This stream is currently unavailable.",
      EpgUnavailable() => "The TV guide could not be loaded right now.",
      CastUnavailable() => "No cast devices found. Check your Wi-Fi network.",
      CastConnectionFailed() =>
        "Could not connect to the cast device. Try again.",
    };
  }
}
