// Web Push ist eine reine Web-Funktion (dart:js_interop). Auf Android/iOS
// (native APK-Builds, siehe CLAUDE.md "Android APK bauen") gibt es keinen
// Service Worker/PushManager - dort greift die No-Op-Stub-Implementierung,
// damit `flutter build apk` nicht an einem nicht auflösbaren dart:js_interop-
// Import scheitert.
export 'push_service_stub.dart' if (dart.library.js_interop) 'push_service_web.dart';
