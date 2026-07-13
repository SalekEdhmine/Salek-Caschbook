/// No-Op-Stub für Nicht-Web-Plattformen (Android/iOS native Builds) - dort
/// gibt es kein Web-Push. Gleiche öffentliche API wie push_service_web.dart.
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  String get permissionStatus => 'unsupported';

  Future<String> subscribe() async => 'unsupported';

  Future<void> unsubscribe() async {}
}
