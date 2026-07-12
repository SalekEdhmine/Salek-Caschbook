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

  Future<List<BankAspsp>> getAspsps({String country = 'DE'}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/banks/aspsps?country=$country'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Banken konnten nicht geladen werden (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as List;
    return data.map((e) => BankAspsp.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<String> startConnect({required String aspspName, required String aspspCountry}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/banks/connect'),
      headers: _headers,
      body: jsonEncode({'aspsp_name': aspspName, 'aspsp_country': aspspCountry}),
    );
    if (res.statusCode != 200) {
      throw Exception('Verbindung konnte nicht gestartet werden (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<List<BankConnection>> getConnections() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/banks/connections'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Bankverbindungen konnten nicht geladen werden (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as List;
    return data.map((e) => BankConnection.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<bool> deleteConnection(String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/banks/connections/$id'), headers: _headers);
    return res.statusCode == 200;
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
      throw Exception('Umsätze konnten nicht geladen werden (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final txs = data['transactions'] as List? ?? const [];
    return txs.map((e) => BankTransaction.fromMap(e as Map<String, dynamic>)).toList();
  }
}
