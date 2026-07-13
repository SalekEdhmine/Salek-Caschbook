import 'dart:js_interop';
import 'pb_client.dart';

// Rufen die Funktionen aus web/push_client.js auf (bewusst reines
// Vanilla-JS, siehe Kommentar dort) - so kann sich hier kein Dart-
// Compile-Fehler durch wechselnde Web-Interop-APIs einschleichen.
@JS('getNotificationPermission')
external JSString _getNotificationPermission();

@JS('subscribeToPush')
external JSPromise<JSString> _subscribeToPush(JSString token, JSString apiBase);

@JS('unsubscribeFromPush')
external JSPromise<JSAny?> _unsubscribeFromPush(JSString token, JSString apiBase);

class PushService {
  static final PushService instance = PushService._();
  PushService._();

  static const _baseUrl = 'https://cashbooksakel.chickenkiller.com';

  /// 'default' (noch nicht gefragt) | 'granted' | 'denied' | 'unsupported'.
  String get permissionStatus {
    try {
      return _getNotificationPermission().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  /// Fragt die Berechtigung ab (falls nötig) und meldet dieses Gerät beim
  /// Push-Dienst an. Gibt den resultierenden Berechtigungsstatus zurück.
  Future<String> subscribe() async {
    try {
      final result = await _subscribeToPush(pb.authStore.token.toJS, _baseUrl.toJS).toDart;
      return result.toDart;
    } catch (_) {
      return 'error';
    }
  }

  Future<void> unsubscribe() async {
    try {
      await _unsubscribeFromPush(pb.authStore.token.toJS, _baseUrl.toJS).toDart;
    } catch (_) {}
  }
}
