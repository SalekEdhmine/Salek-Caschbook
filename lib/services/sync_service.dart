import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqflite/sqflite.dart';
import 'local_db.dart';
import 'pb_client.dart';

/// Gleicht offline angesammelte Änderungen (pending_ops) mit PocketBase ab,
/// sobald wieder Internet verfügbar ist, und zieht danach den aktuellen
/// Serverstand in die lokale Datenbank.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get isOnlineStream => _statusController.stream;
  bool isOnline = false;
  bool _syncing = false;

  /// Anzahl der Änderungen, die noch auf den Server übertragen werden müssen.
  Future<int> getPendingOpsCount() async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('pending_ops');
    return rows.length;
  }

  StreamSubscription? _connSub;
  Timer? _retryTimer;

  Future<void> start() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      isOnline = !conn.contains(ConnectivityResult.none);
      _connSub = Connectivity().onConnectivityChanged.listen((result) async {
        final nowOnline = !result.contains(ConnectivityResult.none);
        if (nowOnline && !isOnline) {
          isOnline = true;
          _statusController.add(true);
          await syncNow();
        } else if (!nowOnline) {
          isOnline = false;
          _statusController.add(false);
        }
      });
      if (isOnline) await syncNow();
    } catch (e) {
      // Connectivity-Erkennung oder erster Sync fehlgeschlagen (z.B. fehlende
      // Plattform-Unterstützung) – App soll trotzdem normal weiterlaufen.
      isOnline = false;
      _statusController.add(false);
    }

    // Verbindungs-Events allein reichen nicht: Sie merken nur, ob das Gerät
    // ein Netzwerk hat, nicht ob der Server selbst gerade erreichbar war.
    // Deshalb zusätzlich regelmäßig erneut versuchen, damit liegen gebliebene
    // Änderungen nicht für immer in der Warteschlange hängen bleiben.
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 20), (_) => syncNow());
  }

  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
  }

  /// Sendet die Offline-Warteschlange an den Server und holt danach den
  /// aktuellen Stand ab. Sicher mehrfach aufrufbar (läuft nicht parallel).
  Future<void> syncNow() async {
    if (_syncing || !pb.authStore.isValid) return;
    _syncing = true;
    try {
      await _pushQueue();
      await _pullAll();
      isOnline = true;
      _statusController.add(true);
    } catch (_) {
      isOnline = false;
      _statusController.add(false);
    } finally {
      _syncing = false;
    }
  }

  // ── Push: lokale Änderungen zum Server ────────────────────────────────────
  Future<void> _pushQueue() async {
    final db = await LocalDb.instance.db;
    final ops = await db.query('pending_ops', orderBy: 'seq ASC');
    for (final op in ops) {
      final entity = op['entity'] as String;
      final action = op['op'] as String;
      final recordId = op['record_id'] as String;
      final payload = op['payload'] as String?;
      final collection = pb.collection(entity);
      try {
        if (action == 'create') {
          final body = Map<String, dynamic>.from(jsonDecode(payload!));
          await collection.create(body: body);
        } else if (action == 'update') {
          final body = Map<String, dynamic>.from(jsonDecode(payload!));
          await collection.update(recordId, body: body);
        } else if (action == 'delete') {
          await collection.delete(recordId);
        }
      } catch (e) {
        // ClientException mit statusCode 0 = keine Verbindung zum Server ->
        // abbrechen, später im Ganzen erneut versuchen. Alles andere (404,
        // 400 Validierungsfehler, unerwartete Fehler in genau diesem einen
        // Eintrag) ist ein dauerhaftes Problem nur mit diesem Eintrag – den
        // überspringen wir, statt für immer alle nachfolgenden Syncs
        // (inkl. Pull!) zu blockieren.
        if (e is ClientException && e.statusCode == 0) rethrow;
      }
      if (action != 'delete') {
        await db.update(entity, {'dirty': 0}, where: 'id = ?', whereArgs: [recordId]);
      }
      await db.delete('pending_ops', where: 'seq = ?', whereArgs: [op['seq']]);
    }
    // Hinweis: Als "deleted" markierte Einträge werden NICHT automatisch
    // entfernt – sie bleiben im Papierkorb, bis der Nutzer sie wiederherstellt
    // oder endgültig löscht (siehe PbService.permanentlyDeleteX).
  }

  /// IDs einer Tabelle, die lokal noch nicht hochgeladene Änderungen haben.
  /// Der Pull darf diese Zeilen nicht mit dem (älteren) Serverstand
  /// überschreiben, sonst gehen gerade gemachte Änderungen verloren.
  Future<Set<String>> _dirtyIds(Database db, String table) async {
    final rows = await db.query(table, columns: ['id'], where: 'dirty = 1');
    return rows.map((r) => r['id'] as String).toSet();
  }

  // ── Pull: Serverstand in lokale DB übernehmen ─────────────────────────────
  Future<void> _pullAll() async {
    final db = await LocalDb.instance.db;
    final uid = pb.authStore.record!.id;

    final businesses = await pb.collection('businesses').getFullList(filter: 'user = "$uid"');
    final dirtyBusinessIds = await _dirtyIds(db, 'businesses');
    final batch = db.batch();
    batch.delete('businesses', where: 'dirty = 0');
    for (final r in businesses) {
      // Eine lokale, noch nicht hochgeladene Änderung darf der Pull nicht
      // überschreiben (sonst verschwindet z.B. ein gerade gesetztes Logo
      // wieder, wenn Push und Pull sich überlappen).
      if (dirtyBusinessIds.contains(r.id)) continue;
      batch.insert('businesses', {
        'id': r.id, 'name': r.getStringValue('name'),
        'description': r.getStringValue('description'),
        'color_value': r.getIntValue('color_value'),
        'icon': r.getStringValue('icon'),
        'currency': r.getStringValue('currency'),
        'logo': r.getStringValue('logo'),
        'address': r.getStringValue('address'),
        'phone': r.getStringValue('phone'),
        'email': r.getStringValue('email'),
        'business_type': r.getStringValue('business_type'),
        'registration_type': r.getStringValue('registration_type'),
        'employee_count': r.getIntValue('employee_count'),
        'business_category': r.getStringValue('business_category'),
        'user_id': uid, 'dirty': 0,
        'deleted': r.data['deleted'] == true ? 1 : 0,
        'deleted_at': r.getStringValue('deleted_at').isEmpty ? null : r.getStringValue('deleted_at'),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    for (final business in businesses) {
      final books = await pb.collection('books').getFullList(filter: 'business = "${business.id}"');
      final dirtyBookIds = await _dirtyIds(db, 'books');
      final bookBatch = db.batch();
      bookBatch.delete('books', where: 'business_id = ? AND dirty = 0', whereArgs: [business.id]);
      for (final r in books) {
        if (dirtyBookIds.contains(r.id)) continue;
        bookBatch.insert('books', {
          'id': r.id, 'business_id': r.getStringValue('business'),
          'name': r.getStringValue('name'), 'description': r.getStringValue('description'),
          'color_value': r.getIntValue('color_value'), 'icon': r.getStringValue('icon'),
          'initial_balance': r.getDoubleValue('initial_balance'),
          'currency': r.getStringValue('currency'), 'logo': r.getStringValue('logo'),
          'created': r.getStringValue('created'),
          'dirty': 0,
          'deleted': r.data['deleted'] == true ? 1 : 0,
          'deleted_at': r.getStringValue('deleted_at').isEmpty ? null : r.getStringValue('deleted_at'),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await bookBatch.commit(noResult: true);

      for (final book in books) {
        await _pullTransactionsForBook(book.id);
        await _pullMembersForBook(book.id);
        await _pullActivityLogsForBook(book.id);
      }
    }

    await _pullSharedBooks();

    final categories = await pb.collection('categories').getFullList(filter: 'user = "$uid"');
    final dirtyCategoryIds = await _dirtyIds(db, 'categories');
    final catBatch = db.batch();
    catBatch.delete('categories', where: 'dirty = 0');
    for (final r in categories) {
      if (dirtyCategoryIds.contains(r.id)) continue;
      catBatch.insert('categories', {
        'id': r.id, 'user_id': uid, 'name': r.getStringValue('name'),
        'icon': r.getStringValue('icon'), 'color_value': r.getIntValue('color_value'),
        'type': r.getStringValue('type'), 'dirty': 0,
        'deleted': r.data['deleted'] == true ? 1 : 0,
        'deleted_at': r.getStringValue('deleted_at').isEmpty ? null : r.getStringValue('deleted_at'),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await catBatch.commit(noResult: true);
  }

  /// Bücher, die mir (per E-Mail) als Mitglied freigegeben wurden, aber nicht
  /// in einem meiner eigenen Businesses liegen, müssen separat geholt werden –
  /// sie tauchen sonst nie in der lokalen DB des eingeladenen Nutzers auf.
  Future<void> _pullSharedBooks() async {
    final db = await LocalDb.instance.db;
    final email = pb.authStore.record?.getStringValue('email') ?? '';
    if (email.isEmpty) return;
    final dirtyBookIds = await _dirtyIds(db, 'books');
    final memberRecords = await pb.collection('members').getFullList(
      filter: 'email = "$email"', expand: 'book',
    );
    for (final r in memberRecords) {
      final bookRecord = r.get<RecordModel?>('expand.book');
      if (bookRecord == null) continue;
      // Auch hier gilt: ein eingeladenes Mitglied kann die Bucheinstellungen
      // offline ändern; eine noch nicht hochgeladene Änderung darf der Pull
      // nicht überschreiben.
      if (!dirtyBookIds.contains(bookRecord.id)) {
        await db.insert('books', {
          'id': bookRecord.id, 'business_id': bookRecord.getStringValue('business'),
          'name': bookRecord.getStringValue('name'), 'description': bookRecord.getStringValue('description'),
          'color_value': bookRecord.getIntValue('color_value'), 'icon': bookRecord.getStringValue('icon'),
          'initial_balance': bookRecord.getDoubleValue('initial_balance'),
          'currency': bookRecord.getStringValue('currency'), 'logo': bookRecord.getStringValue('logo'),
          'created': bookRecord.getStringValue('created'),
          'dirty': 0,
          'deleted': bookRecord.data['deleted'] == true ? 1 : 0,
          'deleted_at': bookRecord.getStringValue('deleted_at').isEmpty ? null : bookRecord.getStringValue('deleted_at'),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await _pullTransactionsForBook(bookRecord.id);
      await _pullMembersForBook(bookRecord.id);
      await _pullActivityLogsForBook(bookRecord.id);
    }
  }

  Future<void> _pullActivityLogsForBook(String bookId) async {
    final db = await LocalDb.instance.db;
    final records = await pb.collection('activity_logs').getFullList(
      filter: 'book = "$bookId"', sort: '-created',
    );
    final dirtyLogIds = await _dirtyIds(db, 'activity_logs');
    final batch = db.batch();
    // Ein gerade lokal erzeugter Log-Eintrag liegt noch in pending_ops und
    // ist serverseitig noch nicht vorhanden – würde er hier ungeschützt
    // gelöscht, käme er nie wieder zurück.
    batch.delete('activity_logs', where: 'book_id = ? AND dirty = 0', whereArgs: [bookId]);
    for (final r in records) {
      if (dirtyLogIds.contains(r.id)) continue;
      batch.insert('activity_logs', {
        'id': r.id, 'book_id': bookId, 'action': r.getStringValue('action'),
        'entity_type': r.getStringValue('entity_type'), 'entity_id': r.getStringValue('entity_id'),
        'details': r.getStringValue('details'), 'user_email': r.getStringValue('user_email'),
        'user_name': r.getStringValue('user_name'), 'created': r.getStringValue('created'),
        'dirty': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _pullTransactionsForBook(String bookId) async {
    final db = await LocalDb.instance.db;
    final records = await pb.collection('transactions').getFullList(
      filter: 'book = "$bookId"', expand: 'category',
    );
    final dirtyTxIds = await _dirtyIds(db, 'transactions');
    final batch = db.batch();
    batch.delete('transactions', where: 'book_id = ? AND dirty = 0', whereArgs: [bookId]);
    for (final r in records) {
      if (dirtyTxIds.contains(r.id)) continue;
      final cat = r.get<RecordModel?>('expand.category');
      var attachments = r.data['attachments'];
      final attachStr = attachments is List ? jsonEncode(attachments) : (attachments?.toString() ?? '[]');
      batch.insert('transactions', {
        'id': r.id, 'book_id': bookId, 'category_id': r.getStringValue('category'),
        'title': r.getStringValue('title'), 'amount': r.getDoubleValue('amount'),
        'type': r.getStringValue('type'), 'date': r.getStringValue('date'),
        'note': r.getStringValue('note'), 'attachments': attachStr,
        'payment_mode': r.getStringValue('payment_mode'), 'contact': r.getStringValue('contact'),
        'is_recurring': r.data['is_recurring'] == true ? 1 : 0,
        'recurrence_interval': r.data['recurrence_interval'] as String?,
        'created': r.getStringValue('created'),
        'category_name': cat?.getStringValue('name'), 'category_icon': cat?.getStringValue('icon'),
        'category_color': cat?.getIntValue('color_value'),
        'dirty': 0,
        'deleted': r.data['deleted'] == true ? 1 : 0,
        'deleted_at': r.getStringValue('deleted_at').isEmpty ? null : r.getStringValue('deleted_at'),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _pullMembersForBook(String bookId) async {
    final db = await LocalDb.instance.db;
    final records = await pb.collection('members').getFullList(filter: 'book = "$bookId"');
    final dirtyMemberIds = await _dirtyIds(db, 'members');
    final batch = db.batch();
    batch.delete('members', where: 'book_id = ? AND dirty = 0', whereArgs: [bookId]);
    for (final r in records) {
      if (dirtyMemberIds.contains(r.id)) continue;
      batch.insert('members', {
        'id': r.id, 'book_id': bookId, 'name': r.getStringValue('name'),
        'email': r.getStringValue('email'), 'role': r.getStringValue('role'),
        'dirty': 0,
        'deleted': r.data['deleted'] == true ? 1 : 0,
        'deleted_at': r.getStringValue('deleted_at').isEmpty ? null : r.getStringValue('deleted_at'),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// In die Offline-Warteschlange einreihen; wird bei nächster Gelegenheit
  /// (Connectivity-Wechsel oder manueller [syncNow]-Aufruf) gesendet.
  Future<void> enqueue({
    required String entity,
    required String op,
    required String recordId,
    Map<String, dynamic>? payload,
  }) async {
    final db = await LocalDb.instance.db;
    await db.insert('pending_ops', {
      'entity': entity, 'op': op, 'record_id': recordId,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
    if (isOnline) {
      // Im Hintergrund versuchen, nicht blockierend für die UI.
      unawaited(syncNow());
    }
  }
}
