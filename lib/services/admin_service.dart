import 'dart:convert';
import 'package:http/http.dart' as http;

/// Eigener, vom normalen App-Login komplett getrennter Zugriff auf die
/// PocketBase-Admin-API. Das Admin-Token liegt NUR im Arbeitsspeicher dieser
/// Klasse (nicht persistiert, nicht im Code hinterlegt) – beim Schließen der
/// App oder Logout ist es weg. So bleibt der normale Nutzer-Login/Sync der
/// App davon unberührt, und es liegen keine Admin-Zugangsdaten im Build.
class AdminService {
  static final AdminService instance = AdminService._();
  AdminService._();

  static const _baseUrl = 'https://cashbooksakel.chickenkiller.com';

  String? _token;
  bool get isLoggedIn => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': _token!,
  };

  /// Gibt bei Erfolg null zurück, sonst eine Fehlermeldung.
  Future<String?> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/admins/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identity': email, 'password': password}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['token'] != null) {
        _token = data['token'] as String;
        return null;
      }
      return data['message']?.toString() ?? 'Login fehlgeschlagen (${res.statusCode})';
    } catch (e) {
      return 'Verbindungsfehler: $e';
    }
  }

  void logout() => _token = null;

  Future<List<Map<String, dynamic>>> getUsers() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/collections/users/records?perPage=200&sort=-created'),
      headers: _headers,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
  }

  Future<bool> setUserPassword(String userId, String newPassword) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/api/collections/users/records/$userId'),
      headers: _headers,
      body: jsonEncode({'password': newPassword, 'passwordConfirm': newPassword}),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteUser(String userId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/collections/users/records/$userId'),
      headers: _headers,
    );
    return res.statusCode == 204 || res.statusCode == 200;
  }

  Future<int> _count(String collection) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/collections/$collection/records?perPage=1'),
      headers: _headers,
    );
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['totalItems'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> getStats() async {
    final results = await Future.wait([
      _count('users'), _count('businesses'), _count('books'),
      _count('transactions'), _count('members'),
    ]);
    return {
      'users': results[0], 'businesses': results[1], 'books': results[2],
      'transactions': results[3], 'members': results[4],
    };
  }

  Future<List<String>> listBackups() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/backups'), headers: _headers);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is List) return data.map((e) => e['key']?.toString() ?? e.toString()).toList();
    return [];
  }

  Future<bool> createBackup() async {
    final res = await http.post(Uri.parse('$_baseUrl/api/backups'), headers: _headers, body: jsonEncode({}));
    return res.statusCode == 200 || res.statusCode == 204;
  }

  Future<bool> deleteBackup(String key) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/backups/$key'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }

  String backupDownloadUrl(String key) => '$_baseUrl/api/backups/$key?token=$_token';
}
