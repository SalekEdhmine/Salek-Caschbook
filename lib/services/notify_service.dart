import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_notification.dart';
import 'pb_client.dart';

/// Spricht mit den /api/notify + /api/notifications-Routen des
/// enablebanking_service-Backends (In-App-Benachrichtigungen + Web-Push).
class NotifyService {
  static final NotifyService instance = NotifyService._();
  NotifyService._();

  static const _baseUrl = 'https://cashbooksakel.chickenkiller.com';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': pb.authStore.token,
      };

  Future<List<AppNotification>> getNotifications() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/notifications'), headers: _headers);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as List;
    return data.map((e) => AppNotification.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String id) async {
    await http.post(Uri.parse('$_baseUrl/api/notifications/$id/read'), headers: _headers);
  }

  Future<void> markAllRead() async {
    await http.post(Uri.parse('$_baseUrl/api/notifications/read-all'), headers: _headers);
  }

  /// Best-effort: benachrichtigt die anderen Mitglieder des Buchs über eine
  /// neu angelegte Buchung. Darf nie einen Fehler nach außen werfen - das
  /// Speichern der Buchung selbst muss davon unberührt bleiben.
  Future<void> notifyTransactionCreated({required String transactionId, required String bookId}) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notify/transaction-created'),
        headers: _headers,
        body: jsonEncode({'transaction_id': transactionId, 'book_id': bookId}),
      );
    } catch (_) {
      // Push-/Benachrichtigungsversand ist nice-to-have, kein kritischer Pfad.
    }
  }
}
