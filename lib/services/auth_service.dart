import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'pb_client.dart';
import 'pb_service.dart';

class AuthService {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyEmail = 'saved_login_email';
  static const _keyPassword = 'saved_login_password';
  static const _keyRememberMe = 'remember_me';

  /// "Angemeldet bleiben"-Häkchen: per Default aktiv, auch über das
  /// Abmelden hinweg gespeichert (nur die Server-Session wird geleert).
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? true;
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
    if (!value) await clearSavedCredentials();
  }

  static Future<({String email, String password})?> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: _keyEmail);
      final password = await _secureStorage.read(key: _keyPassword);
      if (email != null && password != null) return (email: email, password: password);
    } catch (_) {}
    // Fallback, falls die Verschlüsselungs-API der Plattform nicht
    // verfügbar ist (z.B. Browser ohne vertrauenswürdigen HTTPS-Kontext).
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    final password = prefs.getString(_keyPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  static Future<void> _saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _keyEmail, value: email);
      await _secureStorage.write(key: _keyPassword, value: password);
      return;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
  }

  static Future<void> clearSavedCredentials() async {
    try {
      await _secureStorage.delete(key: _keyEmail);
      await _secureStorage.delete(key: _keyPassword);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
  }

  // ── Register ──────────────────────────────────────────────────
  static Future<({bool success, String? error})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) return (success: false, error: 'Name darf nicht leer sein');
    if (password.length < 8) return (success: false, error: 'Passwort muss mind. 8 Zeichen haben');
    try {
      await pb.collection('users').create(body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'passwordConfirm': password,
      });
      await pb.collection('users').authWithPassword(
        email.trim().toLowerCase(),
        password,
      );
      await PbService.instance.insertDefaultCategories();
      return (success: true, error: null);
    } on ClientException catch (e) {
      return (success: false, error: _translate(e));
    }
  }

  // ── Login ─────────────────────────────────────────────────────
  static Future<({bool success, String? error})> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      await pb.collection('users').authWithPassword(
        email.trim().toLowerCase(),
        password,
      );
      // Login bei PocketBase ist bereits erfolgreich – ein Fehler beim
      // Speichern der Zugangsdaten (z.B. fehlender Secure-Storage-Zugriff
      // im Browser) darf den erfolgreichen Login nicht mehr blockieren.
      try {
        await setRememberMe(rememberMe);
        if (rememberMe) {
          await _saveCredentials(email.trim().toLowerCase(), password);
        } else {
          await clearSavedCredentials();
        }
      } catch (_) {}
      return (success: true, error: null);
    } on ClientException catch (e) {
      return (success: false, error: _translate(e));
    }
  }

  // ── Session ───────────────────────────────────────────────────
  static bool isLoggedIn() => pb.authStore.isValid;

  static AppUser? currentUser() {
    final model = pb.authStore.record;
    if (model == null || !pb.authStore.isValid) return null;
    return AppUser(
      id: model.id,
      name: model.getStringValue('name'),
      email: model.getStringValue('email'),
    );
  }

  static void logout() => pb.authStore.clear();

  static Future<void> resetPassword(String email) async {
    await pb.collection('users').requestPasswordReset(email.trim().toLowerCase());
  }

  // ── Update Profile ────────────────────────────────────────────
  static Future<void> updateName(String name) async {
    final user = pb.authStore.record;
    if (user == null) return;
    await pb.collection('users').update(user.id, body: {'name': name.trim()});
    await pb.collection('users').authRefresh();
  }

  static Future<({bool success, String? error})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) return (success: false, error: 'Mind. 8 Zeichen');
    final user = pb.authStore.record;
    if (user == null) return (success: false, error: 'Nicht eingeloggt');
    try {
      await pb.collection('users').update(user.id, body: {
        'oldPassword': currentPassword,
        'password': newPassword,
        'passwordConfirm': newPassword,
      });
      return (success: true, error: null);
    } on ClientException catch (e) {
      return (success: false, error: _translate(e));
    }
  }

  static String _translate(ClientException e) {
    // statusCode 0 = keine Verbindung zum Server – ohne Internet kann der
    // Login nicht überprüft werden, die App bleibt dann bei der zuletzt
    // erfolgreich eingeloggten Sitzung (nicht bei den neu eingegebenen
    // Zugangsdaten!), damit das nicht verwechselt wird.
    if (e.statusCode == 0) {
      return 'Keine Internetverbindung – Anmelden/Konto wechseln ist nur online möglich. Du bist weiterhin mit deinem zuletzt aktiven Konto angemeldet.';
    }
    final msg = e.response.toString().toLowerCase();
    if (msg.contains('invalid credentials') || msg.contains('failed to authenticate')) {
      return 'E-Mail oder Passwort falsch';
    }
    if (msg.contains('already exists') || msg.contains('unique')) {
      return 'E-Mail bereits registriert';
    }
    if (msg.contains('oldpassword') || msg.contains('old_password')) {
      return 'Aktuelles Passwort falsch';
    }
    return e.response['message']?.toString() ?? 'Unbekannter Fehler';
  }
}
