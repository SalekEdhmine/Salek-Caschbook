// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

const _kResetMarker = 'cashbook_db_reset_at';

void reloadPage() {
  html.window.location.reload();
}

/// True, wenn in den letzten 20 Sekunden bereits ein automatischer DB-Reset
/// + Reload passiert ist – verhindert eine Reload-Endlosschleife, falls die
/// Korruption auch nach dem Neuanlegen sofort wieder auftritt.
bool hadRecentDbReset() {
  final raw = html.window.sessionStorage[_kResetMarker];
  if (raw == null) return false;
  final at = DateTime.tryParse(raw);
  if (at == null) return false;
  return DateTime.now().difference(at) < const Duration(seconds: 20);
}

void markDbReset() {
  html.window.sessionStorage[_kResetMarker] = DateTime.now().toIso8601String();
}
