import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'web_reload.dart';

/// Lokale SQLite-Datenbank – Quelle der Wahrheit für die App.
/// Alle Lese-/Schreibzugriffe laufen hierüber; Synchronisation mit
/// PocketBase passiert separat im [SyncService], sobald Internet da ist.
class LocalDb {
  static final LocalDb instance = LocalDb._();
  LocalDb._();

  Database? _db;
  DatabaseFactory? _factory;
  String? _path;
  bool inMemoryFallbackActive = false;

  // Keine proaktive Prüfung mehr beim Start (PRAGMA integrity_check hat auf
  // manchen Plattformen ein anderes Antwortformat geliefert und dadurch
  // fälschlich "korrupt" erkannt -> Reload-Schleife mit weißem Bildschirm).
  // Stattdessen nur noch reaktiv: ein Fehler während eines echten Zugriffs
  // (siehe [PbService._resilient]) löst den Reset/Fallback aus.
  Future<Database> get db async {
    if (_db != null) return _db!;
    if (kIsWeb && hadRecentDbReset()) {
      return _db = await _openInMemory();
    }
    return _db = await _open();
  }

  /// Datenbank rein im Arbeitsspeicher (kein IndexedDB/Dateisystem) – immun
  /// gegen die WebKit/iOS-Korruption, aber nicht über einen Reload hinweg
  /// gespeichert. Nur als letzter Ausweg, wenn der persistente Speicher auf
  /// diesem Gerät nachweislich nicht funktioniert.
  Future<Database> _openInMemory() async {
    inMemoryFallbackActive = true;
    final factory = kIsWeb ? databaseFactoryFfiWeb : databaseFactoryFfi;
    if (!kIsWeb) sqfliteFfiInit();
    return factory.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(version: 2, onCreate: _onCreate),
    );
  }

  /// Prüft, ob eine Exception auf eine korrupte lokale Datenbank hindeutet
  /// (z.B. "database disk image is malformed", bekanntes WebKit/iOS-Problem).
  static bool isCorruption(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('malformed') || msg.contains('disk image') || msg.contains('not a database');
  }

  Future<void> _deleteDatabaseFile() async {
    if (_factory != null && _path != null) {
      try { await _factory!.deleteDatabase(_path!); } catch (_) {}
    }
  }

  Future<Database> _open() async {
    DatabaseFactory factory;
    if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory; // Android / iOS native sqflite
    }

    String path;
    if (kIsWeb) {
      path = 'cashbook.db';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, 'cashbook.db');
    }
    _factory = factory;
    _path = path;

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade),
    );
  }

  /// Lokale Daten verwerfen und frisch neu anlegen (z.B. nach erkannter
  /// Korruption oder manuell über den Reset-Knopf). Der nächste Sync füllt
  /// alles wieder vom Server.
  ///
  /// [dueToCorruption]: true, wenn dies als Reaktion auf eine erkannte
  /// Korruption während eines echten Zugriffs ausgelöst wurde. Tritt das
  /// erneut innerhalb von 20s auf (persistenter Speicher auf diesem Gerät
  /// ist nachweislich kaputt), wechselt die App beim nächsten Öffnen auf
  /// einen reinen Arbeitsspeicher-Modus statt es endlos erneut zu versuchen.
  Future<void> reset({bool dueToCorruption = false}) async {
    try { await _db?.close(); } catch (_) {}
    _db = null;
    await _deleteDatabaseFile();
    if (dueToCorruption && kIsWeb) markDbReset();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE books ADD COLUMN currency TEXT DEFAULT 'EUR'");
      await db.execute('ALTER TABLE books ADD COLUMN logo TEXT');
    }
    if (oldVersion < 3) {
      for (final table in ['businesses', 'books', 'categories', 'transactions', 'members']) {
        await db.execute('ALTER TABLE $table ADD COLUMN deleted_at TEXT');
      }
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE books ADD COLUMN created TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE transactions ADD COLUMN external_ref TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE businesses (
        id TEXT PRIMARY KEY, name TEXT, description TEXT,
        color_value INTEGER, icon TEXT, currency TEXT, logo TEXT,
        address TEXT, phone TEXT, email TEXT, business_type TEXT,
        registration_type TEXT, employee_count INTEGER, business_category TEXT,
        user_id TEXT, dirty INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY, business_id TEXT, name TEXT, description TEXT,
        color_value INTEGER, icon TEXT, initial_balance REAL,
        currency TEXT DEFAULT 'EUR', logo TEXT, created TEXT,
        dirty INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY, user_id TEXT, name TEXT, icon TEXT,
        color_value INTEGER, type TEXT,
        dirty INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY, book_id TEXT, category_id TEXT, title TEXT,
        amount REAL, type TEXT, date TEXT, note TEXT, attachments TEXT,
        payment_mode TEXT, contact TEXT, is_recurring INTEGER DEFAULT 0,
        recurrence_interval TEXT, external_ref TEXT, created TEXT,
        category_name TEXT, category_icon TEXT, category_color INTEGER,
        dirty INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, deleted_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_tx_book ON transactions(book_id, date)');
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY, book_id TEXT, name TEXT, email TEXT, role TEXT,
        dirty INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY, book_id TEXT, action TEXT, entity_type TEXT,
        entity_id TEXT, details TEXT, user_email TEXT, user_name TEXT,
        created TEXT, dirty INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_ops (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT, op TEXT, record_id TEXT, payload TEXT, created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)
    ''');
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    await d?.close();
  }
}
