import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../models/bank_connection.dart';
import '../models/app_notification.dart';
import '../services/pb_service.dart';
import '../services/sync_service.dart';
import '../services/bank_service.dart';
import '../services/notify_service.dart';
import '../l10n/app_strings.dart';

// ── Theme (persisted) ─────────────────────────────────────────────────────────
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('dark_mode') ?? false;
  }

  @override
  set state(bool value) {
    super.state = value;
    SharedPreferences.getInstance().then((p) => p.setBool('dark_mode', value));
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>(
  (ref) => ThemeModeNotifier(),
);

// ── Locale (persisted) ────────────────────────────────────────────────────────
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('de')) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale') ?? 'de';
    _apply(code);
  }

  void _apply(String code) {
    AppStrings.setLang(code);
    super.state = Locale(code);
    SharedPreferences.getInstance().then((p) => p.setString('locale', code));
  }

  @override
  set state(Locale value) => _apply(value.languageCode);

  void setLanguage(String code) => _apply(code);
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

// ── Notifications (persisted) ─────────────────────────────────────────────────
class NotificationsNotifier extends StateNotifier<bool> {
  NotificationsNotifier() : super(false) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('notifications_enabled') ?? false;
  }

  @override
  set state(bool value) {
    super.state = value;
    SharedPreferences.getInstance().then((p) => p.setBool('notifications_enabled', value));
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, bool>(
  (ref) => NotificationsNotifier(),
);

// ── Offline state (folgt SyncService – Daten kommen immer aus der lokalen DB) ──
class _OfflineNotifier extends StateNotifier<bool> {
  _OfflineNotifier() : super(!SyncService.instance.isOnline) {
    _sub = SyncService.instance.isOnlineStream.listen((online) => state = !online);
  }
  late final StreamSubscription<bool> _sub;

  void setOffline(bool value) => state = value;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final isOfflineProvider = StateNotifierProvider<_OfflineNotifier, bool>(
  (ref) => _OfflineNotifier(),
);

// ── Navigation State ──────────────────────────────────────────────────────────
final selectedBusinessProvider = StateProvider<Business?>((ref) => null);
final selectedBookProvider     = StateProvider<Book?>((ref) => null);
final selectedMonthProvider    = StateProvider<DateTime>((ref) => DateTime.now());

// ── Businesses ────────────────────────────────────────────────────────────────
final businessesProvider = FutureProvider<List<Business>>((ref) async {
  return PbService.instance.getBusinesses();
});

// ── Books ─────────────────────────────────────────────────────────────────────
final booksProvider = FutureProvider.family<List<Book>, String>((ref, businessId) {
  return PbService.instance.getBooks(businessId);
});

// ── Shared Books ──────────────────────────────────────────────────────────────
final sharedBooksProvider = FutureProvider<List<Book>>((ref) {
  return PbService.instance.getSharedBooks();
});

// ── Categories ────────────────────────────────────────────────────────────────
final categoriesProvider = FutureProvider.family<List<Category>, TransactionType?>((ref, type) {
  return PbService.instance.getCategories(type: type);
});

// ── Transactions (monatlich, immer aus lokaler DB) ─────────────────────────────
final transactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, bookId) async {
  final month = ref.watch(selectedMonthProvider);
  final from  = DateTime(month.year, month.month, 1);
  final to    = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return PbService.instance.getTransactions(bookId: bookId, from: from, to: to);
});

// ── Summary (monatlich, immer aus lokaler DB) ──────────────────────────────────
final summaryProvider = FutureProvider.family<Map<String, double>, String>((ref, bookId) async {
  final month = ref.watch(selectedMonthProvider);
  final from  = DateTime(month.year, month.month, 1);
  final to    = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return PbService.instance.getSummary(bookId, from: from, to: to);
});

// ── Book Total Balance (all time) ─────────────────────────────────────────────
final bookTotalBalanceProvider = FutureProvider.family<double, String>((ref, bookId) async {
  final s = await PbService.instance.getSummary(bookId);
  return s['balance'] ?? 0;
});

// ── All-time summary (no month filter) ───────────────────────────────────────
final allTimeSummaryProvider = FutureProvider.family<Map<String, double>, String>((ref, bookId) async {
  return PbService.instance.getSummary(bookId);
});

// ── Transaction filter state ───────────────────────────────────────────
class TransactionFilter {
  final String searchQuery;
  final String typeFilter;
  final String? categoryId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const TransactionFilter({
    this.searchQuery = '',
    this.typeFilter = 'all',
    this.categoryId,
    this.dateFrom,
    this.dateTo,
  });

  TransactionFilter copyWith({
    String? searchQuery, String? typeFilter, String? categoryId,
    DateTime? dateFrom, DateTime? dateTo,
  }) => TransactionFilter(
    searchQuery: searchQuery ?? this.searchQuery,
    typeFilter: typeFilter ?? this.typeFilter,
    categoryId: categoryId ?? this.categoryId,
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo: dateTo ?? this.dateTo,
  );
}

final transactionFilterProvider = StateNotifierProvider.family<TransactionFilterNotifier, TransactionFilter, String>(
  (ref, bookId) => TransactionFilterNotifier(),
);

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(const TransactionFilter());

  void setSearch(String q) => state = state.copyWith(searchQuery: q, categoryId: null);
  void setType(String t) => state = state.copyWith(typeFilter: t);
  void setCategory(String? c) => state = state.copyWith(categoryId: c);
  void setDateRange(DateTime? from, DateTime? to) => state = state.copyWith(dateFrom: from, dateTo: to);
  void clear() => state = const TransactionFilter();
}

// ── Pagination state ──────────────────────────────────────────────────
final paginationPageProvider = StateProvider.family<int, String>((ref, bookId) => 1);
final paginationTotalProvider = StateProvider.family<int, String>((ref, bookId) => 0);
final paginationLoadingProvider = StateProvider.family<bool, String>((ref, bookId) => false);

// ── Paginated transactions ────────────────────────────────────────────
final paginatedTransactionsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookId) async {
  final page = ref.watch(paginationPageProvider(bookId));
  final filter = ref.watch(transactionFilterProvider(bookId));
  final books = ref.watch(booksProvider(bookId)).valueOrNull ?? [];
  final book = books.isEmpty ? null : books.first;
  final initialBalance = book?.initialBalance ?? 0.0;
  TransactionType? type;
  if (filter.typeFilter == 'income') type = TransactionType.income;
  if (filter.typeFilter == 'expense') type = TransactionType.expense;

  try {
    final result = await PbService.instance.getTransactionsPaginated(
      bookId: bookId,
      initialBalance: initialBalance,
      page: page,
      perPage: 50,
      searchQuery: filter.searchQuery.isNotEmpty ? filter.searchQuery : null,
      type: type,
      from: filter.dateFrom,
      to: filter.dateTo,
      categoryId: filter.categoryId,
    );
    ref.read(isOfflineProvider.notifier).setOffline(false);
    ref.read(paginationTotalProvider(bookId).notifier).state = result['totalPages'] as int;
    return result;
  } catch (_) {
    ref.read(isOfflineProvider.notifier).setOffline(true);
    rethrow;
  }
});

// ── All transactions (no date filter, for transactions tab) ───────────────────
final allTransactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, bookId) async {
  try {
    final txs = await PbService.instance.getAllTransactions(bookId);
    ref.read(isOfflineProvider.notifier).setOffline(false);
    return txs;
  } catch (_) {
    ref.read(isOfflineProvider.notifier).setOffline(true);
    rethrow;
  }
});

// ── Category Totals ───────────────────────────────────────────────────────────
final categoryTotalsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String bookId, TransactionType type})>((ref, args) {
  final month = ref.watch(selectedMonthProvider);
  final from  = DateTime(month.year, month.month, 1);
  final to    = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return PbService.instance.getCategoryTotals(args.bookId, args.type, from: from, to: to);
});

// ── Daily Totals ──────────────────────────────────────────────────────────────
final dailyTotalsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bookId) {
  final month = ref.watch(selectedMonthProvider);
  final from  = DateTime(month.year, month.month, 1);
  final to    = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return PbService.instance.getDailyTotals(bookId, from: from, to: to);
});

// ── Configurable month count for reports ──────────────────────────────
final reportMonthCountProvider = StateProvider<int>((ref) => 6);

// ── Monthly Totals (last N months) ────────────────────────────────────────────
final monthlyTotalsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bookId) {
  final months = ref.watch(reportMonthCountProvider);
  return PbService.instance.getMonthlyTotals(bookId, months: months);
});

// ── Budgets ───────────────────────────────────────────────────────────────────
final budgetsProvider = FutureProvider.family<List<Budget>, String>((ref, bookId) async {
  return PbService.instance.getBudgets(bookId);
});

final budgetSpendingProvider = FutureProvider.family<Map<String, double>, String>((ref, bookId) async {
  final month = ref.watch(selectedMonthProvider);
  final from  = DateTime(month.year, month.month, 1);
  final to    = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return PbService.instance.getBudgetSpending(bookId, from: from, to: to);
});

// ── Bankverbindungen (Enable Banking) ──────────────────────────────────────────
final bankConnectionsProvider = FutureProvider<List<BankConnection>>((ref) {
  return BankService.instance.getConnections();
});

final bankAspspsProvider = FutureProvider.family<List<BankAspsp>, String>((ref, country) {
  return BankService.instance.getAspsps(country: country);
});

final bankTargetBookProvider = FutureProvider<String?>((ref) {
  return BankService.instance.getTargetBook();
});

// ── Benachrichtigungen (In-App-Liste) ─────────────────────────────────────
// Heißt bewusst "appNotificationsProvider", nicht "notificationsProvider" -
// dieser Name ist bereits fuer den simplen "Benachrichtigungen an/aus"-
// Einstellungs-Schalter (State<bool>) oben vergeben.
final appNotificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return NotifyService.instance.getNotifications();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(appNotificationsProvider).valueOrNull?.where((n) => !n.read).length ?? 0;
});

// ── Alle Bücher über alle Businesses hinweg (fürs Ziel-Buch-Picker je Bank) ──
final allBooksWithBusinessProvider = FutureProvider<List<(Book, String)>>((ref) async {
  final businesses = await ref.watch(businessesProvider.future);
  final result = <(Book, String)>[];
  for (final biz in businesses) {
    final books = await ref.watch(booksProvider(biz.id!).future);
    for (final b in books) {
      result.add((b, biz.name));
    }
  }
  return result;
});

final bankTransactionsProvider = FutureProvider.family<List<BankTransaction>,
    ({String accountUid, DateTime from, DateTime to})>((ref, args) {
  return BankService.instance.getTransactions(accountUid: args.accountUid, from: args.from, to: args.to);
});
