/// Transport-agnostic HTTP contract used by provider clients in iptv_api.
///
/// The concrete implementation (Dio/http) lives in iptv_api; keeping the
/// interface in core lets other libraries depend on the contract without the
/// engine. Implementations throw [HttpStatusException] on non-2xx so
/// `catchError` can map status codes precisely.
abstract interface class HttpService {
  /// Perform a GET and return the decoded body.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// Perform a GET and return the raw response body as a String
  /// (used for M3U / XMLTV payloads parsed off-isolate downstream).
  Future<String> getRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });
}
