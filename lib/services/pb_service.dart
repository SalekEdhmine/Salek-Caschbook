import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/book.dart';
import '../models/business.dart';
import '../models/category.dart';
import '../models/member.dart';
import '../models/budget.dart';
import '../models/activity.dart';
import '../models/transaction.dart' as model;
import '../utils/id_gen.dart';
import 'local_db.dart';
import 'pb_client.dart';
import 'sync_service.dart';

/// Offline-first Datenzugriff: liest/schreibt ausschließlich gegen die
/// lokale SQLite-Datenbank. Schreibende Operationen werden zusätzlich in
/// die Sync-Queue eingereiht und – sobald online – im Hintergrund mit
/// PocketBase abgeglichen (siehe [SyncService]).
class PbService {
  static final PbService instance = PbService._();
  PbService._();

  String get _uid => pb.authStore.record!.id;

  Future<Database> get _db async => LocalDb.instance.db;

  /// Führt [body] aus; erkennt eine korrupte lokale Datenbank (bekanntes
  /// WebKit/iOS-Problem, "database disk image is malformed") zur Laufzeit,
  /// baut die lokale Kopie automatisch neu auf und versucht es einmal erneut
  /// – statt dass die Seite mit einer rohen SQLite-Fehlermeldung abstürzt.
  Future<T> _resilient<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      if (!LocalDb.isCorruption(e)) rethrow;
      await LocalDb.instance.reset(dueToCorruption: true);
      return await body();
    }
  }

  // ── BUSINESSES ─────────────────────────────────────────────────────────────
  Future<List<Business>> getBusinesses() => _resilient(() async {
    final db = await _db;
    final rows = await db.query('businesses',
        where: 'user_id = ? AND deleted = 0', whereArgs: [_uid], orderBy: 'name');
    return rows.map(_businessFromRow).toList();
  });

  Future<String> insertBusiness(Business b) async {
    final db = await _db;
    final id = generatePbId();
    final row = {
      'id': id, 'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon, 'currency': b.currency,
      'logo': b.logo, 'address': b.address, 'phone': b.phone, 'email': b.email,
      'business_type': b.businessType, 'registration_type': b.registrationType,
      'employee_count': b.employeeCount, 'business_category': b.businessCategory,
      'user_id': _uid, 'dirty': 1, 'deleted': 0,
    };
    await db.insert('businesses', row);
    final body = <String, dynamic>{
      'id': id, 'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon, 'currency': b.currency, 'user': _uid,
    };
    if (b.logo != null) body['logo'] = b.logo;
    await SyncService.instance.enqueue(entity: 'businesses', op: 'create', recordId: id, payload: body);
    return id;
  }

  Future<void> updateBusiness(Business b) async {
    final db = await _db;
    await db.update('businesses', {
      'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon, 'currency': b.currency,
      'logo': b.logo, 'address': b.address, 'phone': b.phone, 'email': b.email,
      'business_type': b.businessType, 'registration_type': b.registrationType,
      'employee_count': b.employeeCount, 'business_category': b.businessCategory,
      'dirty': 1,
    }, where: 'id = ?', whereArgs: [b.id]);
    final body = <String, dynamic>{
      'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon, 'currency': b.currency,
    };
    if (b.logo != null) body['logo'] = b.logo;
    if (b.address != null) body['address'] = b.address;
    if (b.phone != null) body['phone'] = b.phone;
    if (b.email != null) body['email'] = b.email;
    if (b.businessType != null) body['business_type'] = b.businessType;
    if (b.registrationType != null) body['registration_type'] = b.registrationType;
    if (b.employeeCount != null) body['employee_count'] = b.employeeCount;
    if (b.businessCategory != null) body['business_category'] = b.businessCategory;
    await SyncService.instance.enqueue(entity: 'businesses', op: 'update', recordId: b.id!, payload: body);
  }

  Future<void> deleteBusiness(String id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update('businesses', {'deleted': 1, 'deleted_at': now, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'businesses', op: 'update', recordId: id, payload: {'deleted': true, 'deleted_at': now});
  }

  Future<List<Business>> getDeletedBusinesses() => _resilient(() async {
    final db = await _db;
    final rows = await db.query('businesses',
        where: 'user_id = ? AND deleted = 1', whereArgs: [_uid], orderBy: 'deleted_at DESC');
    return rows.map(_businessFromRow).toList();
  });

  Future<void> restoreBusiness(String id) async {
    final db = await _db;
    await db.update('businesses', {'deleted': 0, 'deleted_at': null, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'businesses', op: 'update', recordId: id, payload: {'deleted': false, 'deleted_at': null});
  }

  Future<void> permanentlyDeleteBusiness(String id) async {
    final db = await _db;
    await db.delete('businesses', where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'businesses', op: 'delete', recordId: id);
  }

  // ── BOOKS ───────────────────────────────────────────────────────────────────
  Future<List<Book>> getBooks(String businessId) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('books',
        where: 'business_id = ? AND deleted = 0', whereArgs: [businessId], orderBy: 'name');
    return rows.map(_bookFromRow).toList();
  });

  Future<List<Book>> getSharedBooks() => _resilient(() async {
    final email = pb.authStore.record?.getStringValue('email') ?? '';
    if (email.isEmpty) return <Book>[];
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT b.* FROM books b
      INNER JOIN members m ON m.book_id = b.id
      WHERE m.email = ? AND b.deleted = 0 AND m.deleted = 0
    ''', [email]);
    return rows.map(_bookFromRow).toList();
  });

  Future<String> insertBook(Book b) async {
    final db = await _db;
    final id = generatePbId();
    await db.insert('books', {
      'id': id, 'business_id': b.businessId, 'name': b.name,
      'description': b.description ?? '', 'color_value': b.colorValue,
      'icon': b.icon, 'initial_balance': b.initialBalance,
      'currency': b.currency, 'logo': b.logo,
      'created': DateTime.now().toIso8601String(),
      'dirty': 1, 'deleted': 0,
    });
    await SyncService.instance.enqueue(entity: 'books', op: 'create', recordId: id, payload: {
      'id': id, 'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon,
      'initial_balance': b.initialBalance, 'business': b.businessId,
      'currency': b.currency, 'logo': b.logo ?? '',
    });
    return id;
  }

  Future<void> updateBook(Book b) async {
    final db = await _db;
    await db.update('books', {
      'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon,
      'initial_balance': b.initialBalance,
      'currency': b.currency, 'logo': b.logo, 'dirty': 1,
    }, where: 'id = ?', whereArgs: [b.id]);
    await SyncService.instance.enqueue(entity: 'books', op: 'update', recordId: b.id!, payload: {
      'name': b.name, 'description': b.description ?? '',
      'color_value': b.colorValue, 'icon': b.icon,
      'initial_balance': b.initialBalance,
      'currency': b.currency, 'logo': b.logo ?? '',
    });
  }

  Future<void> deleteBook(String id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update('books', {'deleted': 1, 'deleted_at': now, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'books', op: 'update', recordId: id, payload: {'deleted': true, 'deleted_at': now});
  }

  Future<List<Book>> getDeletedBooks(String businessId) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('books',
        where: 'business_id = ? AND deleted = 1', whereArgs: [businessId], orderBy: 'deleted_at DESC');
    return rows.map(_bookFromRow).toList();
  });

  Future<void> restoreBook(String id) async {
    final db = await _db;
    await db.update('books', {'deleted': 0, 'deleted_at': null, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'books', op: 'update', recordId: id, payload: {'deleted': false, 'deleted_at': null});
  }

  Future<void> permanentlyDeleteBook(String id) async {
    final db = await _db;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'books', op: 'delete', recordId: id);
  }

  // ── CATEGORIES ─────────────────────────────────────────────────────────────
  Future<List<Category>> getCategories({TransactionType? type}) => _resilient(() async {
    final db = await _db;
    String where = 'user_id = ? AND deleted = 0';
    final args = [_uid];
    if (type != null) { where += ' AND type = ?'; args.add(type.name); }
    final rows = await db.query('categories', where: where, whereArgs: args, orderBy: 'name');
    return rows.map(_categoryFromRow).toList();
  });

  Future<String> insertCategory(Category c) async {
    final db = await _db;
    final id = generatePbId();
    await db.insert('categories', {
      'id': id, 'user_id': _uid, 'name': c.name, 'icon': c.icon,
      'color_value': c.colorValue, 'type': c.type.name, 'dirty': 1, 'deleted': 0,
    });
    await SyncService.instance.enqueue(entity: 'categories', op: 'create', recordId: id, payload: {
      'id': id, 'name': c.name, 'icon': c.icon, 'color_value': c.colorValue,
      'type': c.type.name, 'user': _uid,
    });
    return id;
  }

  Future<void> updateCategory(Category c) async {
    final db = await _db;
    await db.update('categories', {
      'name': c.name, 'icon': c.icon, 'color_value': c.colorValue,
      'type': c.type.name, 'dirty': 1,
    }, where: 'id = ?', whereArgs: [c.id]);
    await SyncService.instance.enqueue(entity: 'categories', op: 'update', recordId: c.id!, payload: {
      'name': c.name, 'icon': c.icon, 'color_value': c.colorValue, 'type': c.type.name,
    });
  }

  Future<void> deleteCategory(String id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update('categories', {'deleted': 1, 'deleted_at': now, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'categories', op: 'update', recordId: id, payload: {'deleted': true, 'deleted_at': now});
  }

  Future<List<Category>> getDeletedCategories() => _resilient(() async {
    final db = await _db;
    final rows = await db.query('categories',
        where: 'user_id = ? AND deleted = 1', whereArgs: [_uid], orderBy: 'deleted_at DESC');
    return rows.map(_categoryFromRow).toList();
  });

  Future<void> restoreCategory(String id) async {
    final db = await _db;
    await db.update('categories', {'deleted': 0, 'deleted_at': null, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'categories', op: 'update', recordId: id, payload: {'deleted': false, 'deleted_at': null});
  }

  Future<void> permanentlyDeleteCategory(String id) async {
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'categories', op: 'delete', recordId: id);
  }

  Future<void> insertDefaultCategories() async {
    for (final cat in defaultCategories) {
      await insertCategory(cat);
    }
  }

  // ── TRANSACTIONS ────────────────────────────────────────────────────────────
  Future<List<model.Transaction>> getTransactions({
    required String bookId,
    DateTime? from, DateTime? to,
    String? categoryId,
    String? searchQuery,
    TransactionType? type,
  }) => _resilient(() async {
    final db = await _db;
    String where = 'book_id = ? AND deleted = 0';
    final args = <Object?>[bookId];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    if (categoryId != null) { where += ' AND category_id = ?'; args.add(categoryId); }
    if (type != null) { where += ' AND type = ?'; args.add(type.name); }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (title LIKE ? OR note LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    final rows = await db.query('transactions', where: where, whereArgs: args, orderBy: 'date DESC');
    return rows.map(_txFromRow).toList();
  });

  Future<Map<String, dynamic>> getTransactionsPaginated({
    required String bookId,
    required double initialBalance,
    int page = 1,
    int perPage = 50,
    DateTime? from, DateTime? to,
    String? categoryId,
    String? searchQuery,
    TransactionType? type,
  }) => _resilient(() async {
    final db = await _db;
    String where = 'book_id = ? AND deleted = 0';
    final args = <Object?>[bookId];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    if (categoryId != null) { where += ' AND category_id = ?'; args.add(categoryId); }
    if (type != null) { where += ' AND type = ?'; args.add(type.name); }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (title LIKE ? OR note LIKE ? OR contact LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    final totalItems = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE $where', args)) ?? 0;
    final totalPages = totalItems == 0 ? 1 : ((totalItems + perPage - 1) ~/ perPage);

    final rows = await db.query('transactions',
        where: where, whereArgs: args, orderBy: 'date DESC',
        limit: perPage, offset: (page - 1) * perPage);
    final items = rows.map(_txFromRow).toList();

    // ── Laufenden Saldo berechnen ────────────────────────────────────
    List<double> balances = [];
    if (items.isNotEmpty) {
      final allRows = await db.query('transactions',
          columns: ['id', 'amount', 'type'],
          where: where, whereArgs: args, orderBy: 'date ASC, created ASC');
      double running = initialBalance;
      for (final r in allRows) {
        final amt = (r['amount'] as num).toDouble();
        final typ = r['type'] as String;
        running += typ == 'income' ? amt : -amt;
        if (r['id'] == items.first.id) {
          running -= typ == 'income' ? amt : -amt;
          break;
        }
      }
      for (final item in items) {
        running += item.type == TransactionType.income ? item.amount : -item.amount;
        balances.add(running);
      }
    }

    return {
      'items': items, 'balances': balances,
      'totalItems': totalItems, 'totalPages': totalPages, 'page': page,
    };
  });

  Future<int> getTransactionCount(String bookId, {String? searchQuery, TransactionType? type, DateTime? from, DateTime? to}) async {
    final db = await _db;
    String where = 'book_id = ? AND deleted = 0';
    final args = <Object?>[bookId];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    if (type != null) { where += ' AND type = ?'; args.add(type.name); }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (title LIKE ? OR note LIKE ? OR contact LIKE ?)';
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    return Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE $where', args)) ?? 0;
  }

  /// Sucht die echte, lokal gespeicherte Buchung zu einem Bank-Umsatz
  /// (external_ref = Enable-Banking-Dedup-Schlüssel). Liefert `null`, wenn
  /// der Hintergrund-Sync die Buchung noch nicht heruntergesynct hat.
  Future<model.Transaction?> getTransactionByExternalRef(String externalRef) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('transactions',
        where: 'external_ref = ? AND deleted = 0', whereArgs: [externalRef], limit: 1);
    return rows.isEmpty ? null : _txFromRow(rows.first);
  });

  Future<List<model.Transaction>> getAllTransactions(String bookId) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('transactions',
        where: 'book_id = ? AND deleted = 0', whereArgs: [bookId], orderBy: 'date DESC');
    return rows.map(_txFromRow).toList();
  });

  Future<String> insertTransaction(model.Transaction tx) async {
    final db = await _db;
    final id = generatePbId();
    final category = tx.categoryId.isNotEmpty
        ? (await db.query('categories', where: 'id = ?', whereArgs: [tx.categoryId])).firstOrNull
        : null;
    await db.insert('transactions', {
      'id': id, 'book_id': tx.bookId, 'category_id': tx.categoryId,
      'title': tx.title, 'amount': tx.amount, 'type': tx.type.name,
      'date': tx.date.toIso8601String(), 'note': tx.note ?? '',
      'attachments': jsonEncode(tx.attachments),
      'payment_mode': tx.paymentMode, 'contact': tx.contact,
      'is_recurring': tx.isRecurring ? 1 : 0, 'recurrence_interval': tx.recurrenceInterval,
      'external_ref': tx.externalRef,
      'created': DateTime.now().toIso8601String(),
      'category_name': category?['name'], 'category_icon': category?['icon'],
      'category_color': category?['color_value'],
      'dirty': 1, 'deleted': 0,
    });
    final body = <String, dynamic>{
      'id': id, 'book': tx.bookId, 'title': tx.title,
      'amount': tx.amount, 'type': tx.type.name,
      'date': tx.date.toIso8601String(),
      'note': tx.note ?? '', 'attachments': tx.attachments,
    };
    if (tx.categoryId.isNotEmpty) body['category'] = tx.categoryId;
    if (tx.paymentMode != null && tx.paymentMode!.isNotEmpty) body['payment_mode'] = tx.paymentMode;
    if (tx.contact != null && tx.contact!.isNotEmpty) body['contact'] = tx.contact;
    if (tx.isRecurring) {
      body['is_recurring'] = true;
      if (tx.recurrenceInterval != null) body['recurrence_interval'] = tx.recurrenceInterval;
    }
    if (tx.externalRef != null && tx.externalRef!.isNotEmpty) body['external_ref'] = tx.externalRef;
    await SyncService.instance.enqueue(entity: 'transactions', op: 'create', recordId: id, payload: body);
    await logActivity(bookId: tx.bookId, action: 'created', entityType: 'transaction', entityId: id, details: tx.title);
    return id;
  }

  Future<void> updateTransaction(model.Transaction tx) async {
    final db = await _db;
    final category = tx.categoryId.isNotEmpty
        ? (await db.query('categories', where: 'id = ?', whereArgs: [tx.categoryId])).firstOrNull
        : null;
    await db.update('transactions', {
      'title': tx.title, 'amount': tx.amount, 'type': tx.type.name,
      'date': tx.date.toIso8601String(), 'note': tx.note ?? '',
      'attachments': jsonEncode(tx.attachments),
      'category_id': tx.categoryId,
      'payment_mode': tx.paymentMode, 'contact': tx.contact,
      'is_recurring': tx.isRecurring ? 1 : 0, 'recurrence_interval': tx.recurrenceInterval,
      'category_name': category?['name'], 'category_icon': category?['icon'],
      'category_color': category?['color_value'],
      'dirty': 1,
    }, where: 'id = ?', whereArgs: [tx.id]);
    final body = <String, dynamic>{
      'title': tx.title, 'amount': tx.amount, 'type': tx.type.name,
      'date': tx.date.toIso8601String(), 'note': tx.note ?? '',
      'attachments': tx.attachments,
      'category': tx.categoryId.isNotEmpty ? tx.categoryId : null,
      'payment_mode': tx.paymentMode, 'contact': tx.contact,
      'is_recurring': tx.isRecurring, 'recurrence_interval': tx.recurrenceInterval,
    };
    await SyncService.instance.enqueue(entity: 'transactions', op: 'update', recordId: tx.id!, payload: body);
    await logActivity(bookId: tx.bookId, action: 'updated', entityType: 'transaction', entityId: tx.id, details: tx.title);
  }

  Future<void> deleteTransaction(String id, {String? bookId}) async {
    final db = await _db;
    final row = (await db.query('transactions', where: 'id = ?', whereArgs: [id])).firstOrNull;
    final bid = bookId ?? row?['book_id'] as String? ?? '';
    final title = row?['title'] as String? ?? '';
    final now = DateTime.now().toIso8601String();
    await db.update('transactions', {'deleted': 1, 'deleted_at': now, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'transactions', op: 'update', recordId: id, payload: {'deleted': true, 'deleted_at': now});
    await logActivity(bookId: bid, action: 'deleted', entityType: 'transaction', entityId: id, details: title);
  }

  Future<List<model.Transaction>> getDeletedTransactions(String bookId) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('transactions',
        where: 'book_id = ? AND deleted = 1', whereArgs: [bookId], orderBy: 'deleted_at DESC');
    return rows.map(_txFromRow).toList();
  });

  Future<void> restoreTransaction(String id) async {
    final db = await _db;
    await db.update('transactions', {'deleted': 0, 'deleted_at': null, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'transactions', op: 'update', recordId: id, payload: {'deleted': false, 'deleted_at': null});
  }

  Future<void> permanentlyDeleteTransaction(String id) async {
    final db = await _db;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'transactions', op: 'delete', recordId: id);
  }

  Future<void> deleteAllTransactions(String bookId) async {
    final db = await _db;
    final rows = await db.query('transactions', columns: ['id'], where: 'book_id = ? AND deleted = 0', whereArgs: [bookId]);
    for (final r in rows) {
      await deleteTransaction(r['id'] as String, bookId: bookId);
    }
    await logActivity(bookId: bookId, action: 'deleted', entityType: 'transaction', details: 'Alle Buchungen gelöscht');
  }

  Future<int> bulkDeleteTransactions(List<String> ids, {String? bookId}) async {
    int deleted = 0;
    for (final id in ids) {
      try {
        await deleteTransaction(id, bookId: bookId);
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  Future<String> moveTransaction(model.Transaction tx, String targetBookId) async {
    final newId = await insertTransaction(tx.copyWith(bookId: targetBookId));
    await deleteTransaction(tx.id!, bookId: tx.bookId);
    return newId;
  }

  Future<String> copyTransaction(model.Transaction tx, String targetBookId) async {
    return insertTransaction(tx.copyWith(id: null, bookId: targetBookId));
  }

  Future<String> copyOppositeTransaction(model.Transaction tx, String targetBookId) async {
    final opposite = tx.type == TransactionType.income
        ? TransactionType.expense
        : TransactionType.income;
    return insertTransaction(tx.copyWith(id: null, bookId: targetBookId, type: opposite));
  }

  // ── MEMBERS ────────────────────────────────────────────────────────────────
  Future<List<Member>> getMembers(String bookId) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('members',
        where: 'book_id = ? AND deleted = 0', whereArgs: [bookId], orderBy: 'name');
    return rows.map(_memberFromRow).toList();
  });

  Future<String> insertMember(Member m) async {
    final db = await _db;
    final id = generatePbId();
    await db.insert('members', {
      'id': id, 'book_id': m.bookId, 'name': m.name, 'email': m.email,
      'role': m.role.pbValue, 'dirty': 1, 'deleted': 0,
    });
    await SyncService.instance.enqueue(entity: 'members', op: 'create', recordId: id, payload: {
      'id': id, 'book': m.bookId, 'name': m.name, 'email': m.email, 'role': m.role.pbValue,
    });
    return id;
  }

  Future<void> updateMember(Member m) async {
    final db = await _db;
    await db.update('members', {
      'name': m.name, 'email': m.email, 'role': m.role.pbValue, 'dirty': 1,
    }, where: 'id = ?', whereArgs: [m.id]);
    await SyncService.instance.enqueue(entity: 'members', op: 'update', recordId: m.id!, payload: {
      'name': m.name, 'email': m.email, 'role': m.role.pbValue,
    });
  }

  Future<void> deleteMember(String id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update('members', {'deleted': 1, 'deleted_at': now, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'members', op: 'update', recordId: id, payload: {'deleted': true, 'deleted_at': now});
  }

  Future<List<Member>> getDeletedMembers(String bookId) => _resilient(() async {
    final db = await _db;
    final rows = await db.query('members',
        where: 'book_id = ? AND deleted = 1', whereArgs: [bookId], orderBy: 'deleted_at DESC');
    return rows.map(_memberFromRow).toList();
  });

  Future<void> restoreMember(String id) async {
    final db = await _db;
    await db.update('members', {'deleted': 0, 'deleted_at': null, 'dirty': 1}, where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'members', op: 'update', recordId: id, payload: {'deleted': false, 'deleted_at': null});
  }

  Future<void> permanentlyDeleteMember(String id) async {
    final db = await _db;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.enqueue(entity: 'members', op: 'delete', recordId: id);
  }

  Future<MemberRole?> getCurrentUserRole(String bookId) async {
    final email = pb.authStore.record?.getStringValue('email') ?? '';
    if (email.isEmpty) return null;
    final db = await _db;
    final rows = await db.query('members',
        where: 'book_id = ? AND email = ? AND deleted = 0', whereArgs: [bookId, email]);
    if (rows.isEmpty) return null;
    return MemberRoleX.fromString(rows.first['role'] as String);
  }

  // ── ACTIVITY LOG ──────────────────────────────────────────────────────────
  Future<List<Activity>> getActivityLog(String bookId, {int page = 1, int perPage = 50}) async {
    final db = await _db;
    final rows = await db.query('activity_logs',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'created DESC',
        limit: perPage, offset: (page - 1) * perPage);
    return rows.map((r) => Activity.fromMap({
      'id': r['id'], 'book': r['book_id'], 'action': r['action'],
      'entity_type': r['entity_type'], 'entity_id': r['entity_id'],
      'details': r['details'], 'user_email': r['user_email'],
      'user_name': r['user_name'], 'created': r['created'],
    })).toList();
  }

  Future<void> logActivity({
    required String bookId,
    required String action,
    required String entityType,
    String? entityId,
    String details = '',
  }) async {
    final email = pb.authStore.record?.getStringValue('email') ?? '';
    final name = pb.authStore.record?.getStringValue('name') ?? '';
    final db = await _db;
    final id = generatePbId();
    final now = DateTime.now().toIso8601String();
    await db.insert('activity_logs', {
      'id': id, 'book_id': bookId, 'action': action, 'entity_type': entityType,
      'entity_id': entityId ?? '', 'details': details,
      'user_email': email, 'user_name': name.isEmpty ? email : name,
      'created': now, 'dirty': 1,
    });
    await SyncService.instance.enqueue(entity: 'activity_logs', op: 'create', recordId: id, payload: {
      'id': id, 'book': bookId, 'action': action, 'entity_type': entityType,
      'entity_id': entityId ?? '', 'details': details,
      'user_email': email, 'user_name': name.isEmpty ? email : name,
    });
  }

  // ── SUMMARY ────────────────────────────────────────────────────────────────
  Future<Map<String, double>> getSummary(String bookId, {DateTime? from, DateTime? to}) => _resilient(() async {
    final db = await _db;
    String where = 'book_id = ? AND deleted = 0';
    final args = <Object?>[bookId];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    final rows = await db.query('transactions', columns: ['amount', 'type'], where: where, whereArgs: args);
    double income = 0, expense = 0;
    for (final r in rows) {
      final amt = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') { income += amt; } else { expense += amt; }
    }
    final bookRow = (await db.query('books', where: 'id = ?', whereArgs: [bookId])).firstOrNull;
    final init = (bookRow?['initial_balance'] as num?)?.toDouble() ?? 0.0;
    return {'income': income, 'expense': expense, 'balance': init + income - expense};
  });

  Future<List<Map<String, dynamic>>> getCategoryTotals(
      String bookId, TransactionType type, {DateTime? from, DateTime? to}) async {
    final db = await _db;
    String where = 'book_id = ? AND type = ? AND deleted = 0';
    final args = <Object?>[bookId, type.name];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    final rows = await db.query('transactions',
        columns: ['amount', 'category_id', 'category_name', 'category_icon', 'category_color'],
        where: where, whereArgs: args);
    final map = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final catId = r['category_id'] as String? ?? '';
      map[catId] ??= {
        'name': r['category_name'] ?? 'Unbekannt',
        'icon': r['category_icon'] ?? 'label',
        'colorValue': r['category_color'] ?? 0xFF9E9E9E,
        'total': 0.0,
      };
      map[catId]!['total'] = (map[catId]!['total'] as double) + (r['amount'] as num).toDouble();
    }
    return map.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  }

  Future<List<Map<String, dynamic>>> getDailyTotals(String bookId, {DateTime? from, DateTime? to}) async {
    final db = await _db;
    String where = 'book_id = ? AND deleted = 0';
    final args = <Object?>[bookId];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    final rows = await db.query('transactions', columns: ['amount', 'type', 'date'], where: where, whereArgs: args);
    final map = <String, Map<String, double>>{};
    for (final r in rows) {
      final day = (r['date'] as String).substring(0, 10);
      map[day] ??= {'income': 0.0, 'expense': 0.0};
      final amt = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') { map[day]!['income'] = map[day]!['income']! + amt; }
      else { map[day]!['expense'] = map[day]!['expense']! + amt; }
    }
    return map.entries
        .map((e) => {'day': e.key, 'income': e.value['income'], 'expense': e.value['expense']})
        .toList()
      ..sort((a, b) => (b['day'] as String).compareTo(a['day'] as String));
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals(String bookId, {int months = 6}) async {
    final db = await _db;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - months + 1, 1);
    final rows = await db.query('transactions',
        columns: ['amount', 'type', 'date'],
        where: 'book_id = ? AND deleted = 0 AND date >= ?',
        whereArgs: [bookId, from.toIso8601String()]);
    final map = <String, Map<String, double>>{};
    for (final r in rows) {
      final month = (r['date'] as String).substring(0, 7);
      map[month] ??= {'income': 0.0, 'expense': 0.0};
      final amt = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') { map[month]!['income'] = map[month]!['income']! + amt; }
      else { map[month]!['expense'] = map[month]!['expense']! + amt; }
    }
    for (int i = 0; i < months; i++) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      map[key] ??= {'income': 0.0, 'expense': 0.0};
    }
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return map.entries
        .map((e) => {
          'month': e.key,
          'income': e.value['income'],
          'expense': e.value['expense'],
          'label': '${monthNames[(int.tryParse(e.key.split('-')[1]) ?? 1) - 1]} ${e.key.split('-')[0]}',
        })
        .toList()
      ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
  }

  // ── BUDGETS (bereits lokal, unverändert über SharedPreferences) ────────────
  Future<List<Budget>> getBudgets(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('budgets_$bookId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Budget.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> saveBudgets(String bookId, List<Budget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(budgets.map((b) => b.toMap()).toList());
    await prefs.setString('budgets_$bookId', raw);
  }

  Future<void> setBudget(Budget budget) async {
    final budgets = await getBudgets(budget.bookId);
    final idx = budgets.indexWhere((b) => b.categoryId == budget.categoryId);
    if (idx >= 0) { budgets[idx] = budget; } else { budgets.add(budget); }
    await saveBudgets(budget.bookId, budgets);
  }

  Future<void> deleteBudget(String bookId, String categoryId) async {
    final budgets = await getBudgets(bookId);
    budgets.removeWhere((b) => b.categoryId == categoryId);
    await saveBudgets(bookId, budgets);
  }

  Future<Map<String, double>> getBudgetSpending(String bookId, {DateTime? from, DateTime? to}) async {
    final fromDate = from ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final toDate = to ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59);
    final db = await _db;
    final rows = await db.query('transactions',
        columns: ['amount', 'category_id'],
        where: 'book_id = ? AND type = "expense" AND deleted = 0 AND date >= ? AND date <= ?',
        whereArgs: [bookId, fromDate.toIso8601String(), toDate.toIso8601String()]);
    final map = <String, double>{};
    for (final r in rows) {
      final catId = r['category_id'] as String? ?? '';
      map[catId] = (map[catId] ?? 0) + (r['amount'] as num).toDouble();
    }
    return map;
  }

  // ── Row Mappers ──────────────────────────────────────────────────────────
  Business _businessFromRow(Map<String, Object?> r) => Business(
    id: r['id'] as String?, name: r['name'] as String? ?? '',
    description: (r['description'] as String?)?.isEmpty ?? true ? null : r['description'] as String,
    colorValue: (r['color_value'] as int?) ?? 0xFF1976D2,
    icon: (r['icon'] as String?)?.isNotEmpty == true ? r['icon'] as String : 'business',
    currency: (r['currency'] as String?)?.isNotEmpty == true ? r['currency'] as String : 'EUR',
    logo: (r['logo'] as String?)?.isNotEmpty == true ? r['logo'] as String : null,
    address: (r['address'] as String?)?.isNotEmpty == true ? r['address'] as String : null,
    phone: (r['phone'] as String?)?.isNotEmpty == true ? r['phone'] as String : null,
    email: (r['email'] as String?)?.isNotEmpty == true ? r['email'] as String : null,
    businessType: (r['business_type'] as String?)?.isNotEmpty == true ? r['business_type'] as String : null,
    registrationType: (r['registration_type'] as String?)?.isNotEmpty == true ? r['registration_type'] as String : null,
    employeeCount: r['employee_count'] as int?,
    businessCategory: (r['business_category'] as String?)?.isNotEmpty == true ? r['business_category'] as String : null,
  );

  Book _bookFromRow(Map<String, Object?> r) => Book(
    id: r['id'] as String?, businessId: r['business_id'] as String? ?? '',
    name: r['name'] as String? ?? '', description: r['description'] as String?,
    colorValue: (r['color_value'] as int?) ?? 0xFF4CAF50,
    icon: (r['icon'] as String?)?.isNotEmpty == true ? r['icon'] as String : 'menu_book',
    initialBalance: (r['initial_balance'] as num?)?.toDouble() ?? 0.0,
    currency: (r['currency'] as String?)?.isNotEmpty == true ? r['currency'] as String : 'EUR',
    logo: (r['logo'] as String?)?.isNotEmpty == true ? r['logo'] as String : null,
    createdAt: DateTime.tryParse(r['created'] as String? ?? ''),
  );

  Category _categoryFromRow(Map<String, Object?> r) => Category(
    id: r['id'] as String?, name: r['name'] as String? ?? '',
    icon: r['icon'] as String? ?? '', colorValue: (r['color_value'] as int?) ?? 0xFF9E9E9E,
    type: TransactionType.values.firstWhere(
      (e) => e.name == r['type'], orElse: () => TransactionType.expense),
  );

  model.Transaction _txFromRow(Map<String, Object?> r) {
    List<String> attachments = [];
    final raw = r['attachments'] as String?;
    if (raw != null && raw.isNotEmpty && raw != 'null') {
      try { attachments = List<String>.from(jsonDecode(raw)); } catch (_) {}
    }
    return model.Transaction(
      id: r['id'] as String?, bookId: r['book_id'] as String? ?? '',
      categoryId: r['category_id'] as String? ?? '', title: r['title'] as String? ?? '',
      amount: (r['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == r['type'], orElse: () => TransactionType.expense),
      date: DateTime.parse(r['date'] as String),
      note: (r['note'] as String?)?.isEmpty ?? true ? null : r['note'] as String,
      attachments: attachments,
      categoryName: r['category_name'] as String?,
      categoryIcon: r['category_icon'] as String?,
      categoryColor: r['category_color'] as int?,
      paymentMode: r['payment_mode'] as String?,
      contact: r['contact'] as String?,
      isRecurring: r['is_recurring'] == 1,
      recurrenceInterval: r['recurrence_interval'] as String?,
      externalRef: r['external_ref'] as String?,
      createdAt: DateTime.tryParse(r['created'] as String? ?? ''),
    );
  }

  Member _memberFromRow(Map<String, Object?> r) => Member(
    id: r['id'] as String?, bookId: r['book_id'] as String? ?? '',
    name: r['name'] as String? ?? '', email: r['email'] as String? ?? '',
    role: MemberRoleX.fromString(r['role'] as String? ?? ''),
  );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
