import "package:json_annotation/json_annotation.dart";

/// Health of a saved source, shown as a dot in Réglages (§4.6).
enum ConnectionStatus {
  @JsonValue("ok")
  ok,
  @JsonValue("error")
  error,
  @JsonValue("offline")
  offline,
  @JsonValue("unknown")
  unknown,
}
