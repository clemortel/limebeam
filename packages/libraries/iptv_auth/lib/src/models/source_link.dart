import "package:freezed_annotation/freezed_annotation.dart";

part "source_link.freezed.dart";

/// A pasted provider address, classified. Lets a user skip the type picker
/// and the form: providers hand out one link, not four fields.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class SourceLink with _$SourceLink {
  const SourceLink._();

  /// `http://host:port/get.php?username=u&password=p&type=m3u_plus` or the
  /// `player_api.php` flavour: the credentials are inside the query.
  const factory SourceLink.xtream({
    required String host,
    required String username,
    required String password,
  }) = XtreamSourceLink;

  /// Any other http(s) address is treated as a plain playlist URL.
  const factory SourceLink.m3u({required String url}) = M3uSourceLink;

  /// Returns null when [raw] is not an http(s) address.
  static SourceLink? parse(String raw) {
    final String text = raw.trim();
    if (text.isEmpty || text.contains(RegExp(r"\s"))) return null;
    final Uri? uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == "http" || uri.scheme == "https") ||
        uri.host.isEmpty) {
      return null;
    }
    final String? user = uri.queryParameters["username"];
    final String? pass = uri.queryParameters["password"];
    if (user != null && user.isNotEmpty && pass != null && pass.isNotEmpty) {
      return SourceLink.xtream(
        host: uri.origin,
        username: user,
        password: pass,
      );
    }
    return SourceLink.m3u(url: text);
  }
}
