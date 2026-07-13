import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bank_connection.dart';
import 'pb_client.dart';

/// Spricht ausschließlich mit unserem eigenen enablebanking_service
/// (`/api/banks/...`), niemals direkt mit Enable Banking – der private
/// Schlüssel dafür liegt nur auf dem Server. Authentifizierung läuft über
/// das normale PocketBase-Sitzungstoken, das der Backend-Dienst gegen
/// PocketBase verifiziert.
class BankService {
  static final BankService instance = BankService._();
  BankService._();

  static const _baseUrl = 'https://cashbooksakel.chickenkiller.com';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': pb.authStore.token,
      };

  /// Extrahiert die eigentliche Fehlermeldung aus der FastAPI-`detail`-Hülle
  /// (die wiederum oft den rohen Enable-Banking-Fehlertext enthält), damit
  /// z.B. "Wrong transactions period requested" statt nur "(422)" sichtbar ist.
  String _errorMessage(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      final detail = body is Map ? body['detail'] : null;
      if (detail is String && detail.isNotEmpty) return '$fallback: $detail';
    } catch (_) {}
    return '$fallback (${res.statusCode})';
  }

  Future<List<BankAspsp>> getAspsps({String country = 'DE'}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/banks/aspsps?country=$country'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Banken konnten nicht geladen werden'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['aspsps'] as List? ?? const [];
    return list.map((e) => BankAspsp.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<String> startConnect({required String aspspName, required String aspspCountry, String? logo}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/banks/connect'),
      headers: _headers,
      body: jsonEncode({'aspsp_name': aspspName, 'aspsp_country': aspspCountry, 'logo': logo}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Verbindung konnte nicht gestartet werden'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<List<BankConnection>> getConnections() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/banks/connections'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Bankverbindungen konnten nicht geladen werden'));
    }
    final data = jsonDecode(res.body) as List;
    return data.map((e) => BankConnection.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<bool> deleteConnection(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/banks/connections/$id'), headers: _headers);
    return res.statusCode == 200;
  }

  /// Stößt einen sofortigen Sync aller Bankverbindungen dieses Nutzers an
  /// (holt neue Umsätze von Enable Banking in den Cache). Läuft zusätzlich
  /// automatisch alle 6h im Hintergrund auf dem Server.
  Future<void> triggerSync() async {
    final res = await http.post(Uri.parse('$_baseUrl/api/banks/sync'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Sync fehlgeschlagen'));
    }
  }

  /// Liefert die vom Nutzer gewählte Ziel-Buch-ID für Bank-Auto-Import
  /// (`null`, falls noch keine Wahl getroffen wurde - dann greift serverseitig
  /// der Fallback auf ein automatisch angelegtes "Bank-Import"-Buch).
  Future<String?> getTargetBook() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/banks/settings'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Einstellungen konnten nicht geladen werden'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['target_book'] as String?;
  }

  /// Setzt das Ziel-Buch fuer genau eine Bankverbindung (jede verbundene
  /// Bank kann in ein anderes Buch importieren). `bookId: null` setzt sie
  /// zurueck auf den Fallback (globale Einstellung bzw. automatisches Buch).
  Future<void> setConnectionTargetBook(String connectionId, String? bookId) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/banks/connections/$connectionId/target-book'),
      headers: _headers,
      body: jsonEncode({'target_book': bookId}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Einstellungen konnten nicht gespeichert werden'));
    }
  }

  Future<void> setTargetBook(String? bookId) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/banks/settings'),
      headers: _headers,
      body: jsonEncode({'target_book': bookId}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Einstellungen konnten nicht gespeichert werden'));
    }
  }

  Future<List<BankTransaction>> getTransactions({
    required String accountUid,
    required DateTime from,
    required DateTime to,
  }) async {
    final df = from.toIso8601String().split('T').first;
    final dt = to.toIso8601String().split('T').first;
    final res = await http.get(
      Uri.parse('$_baseUrl/api/banks/accounts/$accountUid/transactions?date_from=$df&date_to=$dt'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Umsätze konnten nicht geladen werden'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final txs = data['transactions'] as List? ?? const [];
    return txs.map((e) => BankTransaction.fromMap(e as Map<String, dynamic>)).toList();
  }
}
