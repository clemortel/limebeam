import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:dartz/dartz.dart";
import "package:iptv_core/iptv_core.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as shelf_io;
import "package:shelf_web_socket/shelf_web_socket.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../models/pairing.dart";

/// Length (hex chars) of the one-time token embedded in the pairing URL. Only a
/// phone that scanned the QR knows it; the server rejects every request without
/// it. Not a substitute for TLS — see the security note on [PairingServer].
const int _kTokenBytes = 16;

/// On-device HTTP + WebSocket server backing "type on your phone".
///
/// Flow: [start] binds an ephemeral port on the LAN and builds the pairing URL
/// (`http://<lan-ip>:<port>/?t=<token>`). The phone opens it, a WebSocket
/// carries the typed [PhoneCredentials] back, and [onConnected] / [credentials]
/// surface progress to the UI. Tear down with [dispose] the moment the transfer
/// is done.
///
/// SECURITY: this speaks plain HTTP/WS over the LAN, so the password is
/// sniffable on a shared network. Mitigations: a random one-time token gates
/// every request, the server is short-lived (only while the pairing sheet is
/// open), and the value is applied only after the user confirms on the TV. A
/// LAN self-signed cert would only add browser interstitials, so we rely on the
/// token + confirmation + short lifetime instead.
class PairingServer {
  PairingServer._(this._server, this.url, this._events);

  final HttpServer _server;

  /// The URL to encode in the QR code.
  final String url;

  final StreamController<PhoneCredentials> _events;

  /// Fires once when a phone first opens the page.
  void Function()? onConnected;

  /// Emits the credentials each time the phone taps "send".
  Stream<PhoneCredentials> get credentials => _events.stream;

  /// Binds the server on the Wi-Fi interface. Left = no usable LAN address or a
  /// bind failure; the UI then falls back to remote text entry.
  static Future<Either<Failures, PairingServer>> start() async {
    try {
      final String? ip = await _lanIpv4();
      if (ip == null) return left(const Failures.network());

      final String token = _randomToken();
      final StreamController<PhoneCredentials> events =
          StreamController<PhoneCredentials>.broadcast();
      late final PairingServer instance;

      final Handler wsHandler = webSocketHandler(
        (WebSocketChannel webSocket, String? subprotocol) {
          instance.onConnected?.call();
          webSocket.stream.listen((dynamic message) {
            final PhoneCredentials? creds = _parse(message);
            if (creds != null) {
              events.add(creds);
              webSocket.sink.add(jsonEncode(<String, String>{"type": "ack"}));
            }
          });
        },
      );

      // Every request must carry the one-time token; the root serves the phone
      // page and `/ws` upgrades to the WebSocket relay.
      FutureOr<Response> handler(Request request) {
        if (request.url.queryParameters["t"] != token) {
          return Response.forbidden("invalid token");
        }
        final String path = request.url.path;
        if (path.isEmpty || path == "/") {
          return Response.ok(
            _phonePageHtml(token),
            headers: <String, String>{
              "content-type": "text/html; charset=utf-8",
            },
          );
        }
        if (path == "ws") return wsHandler(request);
        return Response.notFound("not found");
      }

      // Bind on all IPv4 interfaces so the phone on the LAN can reach it.
      final HttpServer server =
          await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      final String pairingUrl = "http://$ip:${server.port}/?t=$token";
      instance = PairingServer._(server, pairingUrl, events);
      return right(instance);
    } catch (_) {
      return left(const Failures.unexpected());
    }
  }

  /// Stops the server and releases the port. Idempotent.
  Future<void> dispose() async {
    await _events.close();
    await _server.close(force: true);
  }

  /// The first non-loopback, non-link-local IPv4 address (the Wi-Fi/Ethernet
  /// LAN address the phone can route to).
  static Future<String?> _lanIpv4() async {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress addr in interface.addresses) {
        if (!addr.isLoopback && !addr.address.startsWith("169.254")) {
          return addr.address;
        }
      }
    }
    return null;
  }

  static String _randomToken() {
    final Random rng = Random.secure();
    final List<int> bytes =
        List<int>.generate(_kTokenBytes, (_) => rng.nextInt(256));
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, "0")).join();
  }

  /// Parses a `{"type":"submit", ...}` payload into [PhoneCredentials], or null
  /// if the message is malformed or not a submit.
  static PhoneCredentials? _parse(dynamic message) {
    if (message is! String) return null;
    try {
      final Object? decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded["type"] != "submit") return null;
      String field(String key) => (decoded[key] as String?)?.trim() ?? "";
      return PhoneCredentials(
        name: field("name"),
        host: field("host"),
        username: field("username"),
        password: field("password"),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The self-contained page the phone browser loads. Reads its own `?t=` token
/// to open the WebSocket. No external assets (CSP-safe, works offline on LAN).
String _phonePageHtml(String token) => """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
<title>LimeBeam — type on your phone</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: -apple-system, Roboto, system-ui, sans-serif;
         background: #0B0C0E; color: #F2F3F5; padding: 20px; }
  h1 { font-size: 20px; margin: 8px 0 4px; }
  p.sub { color: #9AA0A6; margin: 0 0 20px; font-size: 14px; }
  label { display: block; font-size: 13px; color: #9AA0A6; margin: 14px 0 6px; }
  input { width: 100%; padding: 14px; font-size: 16px; border-radius: 10px;
          border: 1px solid #2A2E33; background: #17191C; color: #F2F3F5; }
  button { width: 100%; margin-top: 24px; padding: 16px; font-size: 16px;
           font-weight: 600; border: 0; border-radius: 10px; background: #B6FF3B;
           color: #0B0C0E; }
  button:disabled { opacity: .5; }
  #status { margin-top: 16px; font-size: 13px; text-align: center; color: #9AA0A6; }
</style>
</head>
<body>
  <h1>Type on your phone</h1>
  <p class="sub">Fill in your IPTV details, then tap Send to TV.</p>
  <label>Name</label><input id="name" autocomplete="off" />
  <label>Portal URL</label>
  <input id="host" inputmode="url" autocapitalize="off" autocorrect="off"
         placeholder="http://portal.tv:8080" />
  <label>Username</label>
  <input id="username" autocomplete="off" autocapitalize="off" autocorrect="off" />
  <label>Password</label><input id="password" type="password" />
  <button id="send" disabled>Send to TV</button>
  <div id="status">Connecting…</div>
<script>
  var token = "$token";
  var proto = location.protocol === "https:" ? "wss:" : "ws:";
  var ws = new WebSocket(proto + "//" + location.host + "/ws?t=" + token);
  var send = document.getElementById("send");
  var status = document.getElementById("status");
  ws.onopen = function () { send.disabled = false; status.textContent = "Connected to TV."; };
  ws.onclose = function () { send.disabled = true; status.textContent = "Disconnected."; };
  ws.onmessage = function (e) {
    try { if (JSON.parse(e.data).type === "ack") status.textContent = "Sent to TV ✓"; }
    catch (_) {}
  };
  send.onclick = function () {
    ws.send(JSON.stringify({
      type: "submit",
      name: document.getElementById("name").value,
      host: document.getElementById("host").value,
      username: document.getElementById("username").value,
      password: document.getElementById("password").value
    }));
    status.textContent = "Sending…";
  };
</script>
</body>
</html>
""";
