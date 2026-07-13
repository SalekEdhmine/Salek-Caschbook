import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../models/business.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/app_providers.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_list_tile.dart';
import '../services/export_service.dart';
import '../services/pb_service.dart';
import '../services/import_service.dart';
import '../services/download_helper.dart';
import '../l10n/app_strings.dart';
import 'add_transaction_screen.dart';
import 'entry_detail_screen.dart';
import 'book_settings_screen.dart';
import '../models/member.dart';
import 'members_screen.dart';
import 'activity_log_screen.dart';
import 'book_trash_screen.dart';
import 'reports_screen.dart';
import '../utils/formatters.dart';
import '../utils/icon_helper.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final Book book;
  final Business business;

  const BookDetailScreen({super.key, required this.book, required this.business});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  int _tab = 0;
  late Book _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  void _refresh() {
    ref.invalidate(allTransactionsProvider(_book.id!));
    ref.invalidate(allTimeSummaryProvider(_book.id!));
    ref.invalidate(transactionsProvider(_book.id!));
    ref.invalidate(summaryProvider(_book.id!));
    ref.invalidate(categoryTotalsProvider);
    ref.invalidate(dailyTotalsProvider);
    ref.invalidate(monthlyTotalsProvider(_book.id!));
    ref.invalidate(paginatedTransactionsProvider(_book.id!));
    ref.invalidate(budgetsProvider(_book.id!));
    ref.invalidate(budgetSpendingProvider(_book.id!));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final width  = MediaQuery.of(context).size.width;
    final isWide = width >= 720;
    final color  = Color(_book.colorValue);

    final tabs = [
      _DashboardTab(book: _book, business: widget.business, onRefresh: _refresh,
          onViewReports: () => setState(() => _tab = 2)),
      _TransactionsTab(book: _book, currency: _book.currency, onRefresh: _refresh,
          onViewReports: () => setState(() => _tab = 2)),
      ReportsScreen(bookId: _book.id!, currency: _book.currency),
      MembersScreen(book: _book, showAppBar: false),
    ];

    final destinations = [
      NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: AppStrings.tr('nav_overview')),
      NavigationDestination(icon: const Icon(Icons.list_alt_outlined),  selectedIcon: const Icon(Icons.list_alt),  label: AppStrings.tr('nav_transactions')),
      NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: AppStrings.tr('nav_reports')),
      NavigationDestination(icon: const Icon(Icons.group_outlined),     selectedIcon: const Icon(Icons.group),     label: AppStrings.tr('nav_members')),
    ];

    final railDestinations = [
      NavigationRailDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: Text(AppStrings.tr('nav_overview'))),
      NavigationRailDestination(icon: const Icon(Icons.list_alt_outlined),  selectedIcon: const Icon(Icons.list_alt),  label: Text(AppStrings.tr('nav_transactions'))),
      NavigationRailDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: Text(AppStrings.tr('nav_reports'))),
      NavigationRailDestination(icon: const Icon(Icons.group_outlined),     selectedIcon: const Icon(Icons.group),     label: Text(AppStrings.tr('nav_members'))),
    ];

    final appBar = AppBar(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_book.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(widget.business.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
      backgroundColor: color.withValues(alpha: 0.08),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'pdf',      child: ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(AppStrings.tr('export_pdf')))),
            PopupMenuItem(value: 'excel',    child: ListTile(leading: const Icon(Icons.table_chart_outlined),    title: Text(AppStrings.tr('export_excel')))),
            PopupMenuItem(value: 'csv', child: ListTile(leading: const Icon(Icons.description_outlined),         title: Text(AppStrings.tr('export_csv')))),
            PopupMenuItem(value: 'import',   child: ListTile(leading: const Icon(Icons.upload_outlined),         title: Text(AppStrings.tr('import_excel')))),
            PopupMenuItem(value: 'share',    child: ListTile(leading: const Icon(Icons.share_outlined),          title: Text(AppStrings.tr('share_book')))),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'activity', child: ListTile(leading: const Icon(Icons.history),                  title: Text(AppStrings.tr('activity_log')))),
            PopupMenuItem(value: 'trash', child: ListTile(leading: const Icon(Icons.delete_outline),              title: Text(AppStrings.tr('trash')))),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'move_book', child: ListTile(leading: const Icon(Icons.drive_file_move_outlined), title: Text(AppStrings.tr('move_book')))),
            PopupMenuItem(value: 'copy_book', child: ListTile(leading: const Icon(Icons.copy_outlined),           title: Text(AppStrings.tr('copy_book')))),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_outlined),       title: Text(AppStrings.tr('book_settings')))),
          ],
          onSelected: (v) => _handleMenu(context, v),
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            destinations: railDestinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: tabs[_tab]),
        ]),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }

  Future<void> _handleMenu(BuildContext ctx, String action) async {
    switch (action) {
      case 'pdf':      await _exportPdf(ctx);   break;
      case 'excel':    await _exportExcel(ctx);  break;
      case 'csv':      await _exportCsv(ctx);    break;
      case 'import':   await _importFile(ctx);   break;
      case 'share':    await _shareBook(ctx);    break;
      case 'activity': Navigator.push(ctx, MaterialPageRoute(builder: (_) => ActivityLogScreen(bookId: _book.id!, bookName: _book.name))); break;
      case 'trash':
        await Navigator.push(ctx, MaterialPageRoute(builder: (_) => BookTrashScreen(book: _book)));
        _refresh();
        break;
      case 'move_book': await _moveOrCopyBook(ctx, move: true); break;
      case 'copy_book': await _moveOrCopyBook(ctx, move: false); break;
      case 'settings': await _openSettings(ctx); break;
    }
  }

  Future<void> _moveOrCopyBook(BuildContext ctx, {required bool move}) async {
    final businesses = await PbService.instance.getBusinesses();
    final others = businesses.where((b) => b.id != widget.business.id).toList();
    if (others.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(AppStrings.tr('no_other_business'))),
        );
      }
      return;
    }
    if (!ctx.mounted) return;
    final target = await showModalBottomSheet<Business>(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(move ? AppStrings.tr('move_to_where') : AppStrings.tr('copy_to_where'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(height: 1),
        ...others.map((b) => ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(b.colorValue).withValues(alpha: 0.15),
            child: Icon(Icons.business_rounded, color: Color(b.colorValue), size: 20),
          ),
          title: Text(b.name),
          onTap: () => Navigator.pop(ctx, b),
        )),
        const SizedBox(height: 8),
      ])),
    );
    if (target == null || !ctx.mounted) return;

    try {
      if (move) {
        final updated = _book.copyWith(businessId: target.id!);
        await PbService.instance.updateBook(updated);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppStrings.tr('moved_to').replaceAll('{name}', target.name))));
          Navigator.pop(ctx);
        }
      } else {
        final newBookId = await PbService.instance.insertBook(_book.copyWith(id: null, businessId: target.id!));
        final txs = await PbService.instance.getAllTransactions(_book.id!);
        for (final tx in txs) {
          await PbService.instance.insertTransaction(tx.copyWith(id: null, bookId: newBookId));
        }
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppStrings.tr('copied_to').replaceAll('{name}', target.name).replaceAll('{count}', '${txs.length}'))));
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _openSettings(BuildContext ctx) async {
    final updated = await Navigator.push<Book>(ctx, MaterialPageRoute(
      builder: (_) => BookSettingsScreen(book: _book),
    ));
    if (updated != null) setState(() => _book = updated);
    _refresh();
  }

  Future<void> _exportPdf(BuildContext ctx) async {
    try {
      await ExportService.exportPdf(context: ctx, book: _book, business: widget.business);
    } catch (e) {
      if (ctx.mounted) _showSnack(ctx, '${AppStrings.tr('error')}: $e', error: true);
    }
  }

  Future<void> _exportExcel(BuildContext ctx) async {
    try {
      final bytes = await ExportService.exportExcel(book: _book, business: widget.business);
      if (!ctx.mounted) return;
      _triggerDownload(ctx, bytes, '${_book.name}.xlsx');
    } catch (e) {
      if (ctx.mounted) _showSnack(ctx, '${AppStrings.tr('error')}: $e', error: true);
    }
  }

  void _triggerDownload(BuildContext ctx, List<int> bytes, String filename) {
    try {
      downloadBytes(bytes, filename);
      _showSnack(ctx, filename);
    } catch (_) {
      _showSnack(ctx, 'Datei erstellt (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
    }
  }

  Future<void> _exportCsv(BuildContext ctx) async {
    try {
      final bytes = await ExportService.exportCsv(book: _book, business: widget.business);
      if (!ctx.mounted) return;
      _triggerDownload(ctx, bytes, '${_book.name}.csv');
    } catch (e) {
      if (ctx.mounted) _showSnack(ctx, '${AppStrings.tr('error')}: $e', error: true);
    }
  }

  Future<void> _importFile(BuildContext ctx) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!ctx.mounted) return;
      _showSnack(ctx, AppStrings.tr('error'), error: true);
      return;
    }

    final isCsv = file.name.toLowerCase().endsWith('.csv');
    final import = isCsv
        ? await ImportService.parseCsv(bytes: bytes, bookId: _book.id!)
        : await ImportService.parseExcel(bytes: bytes, bookId: _book.id!);
    if (!ctx.mounted) return;
    await _showImportPreview(ctx, import);
  }

  Future<void> _showImportPreview(BuildContext ctx, ImportResult import) async {
    await showDialog(
      context: ctx,
      builder: (_) => _ImportPreviewDialog(
        result: import,
        onConfirm: () async {
          final count = await ImportService.saveImport(import.preview);
          _refresh();
          if (ctx.mounted) _showSnack(ctx, '$count ${AppStrings.tr('nav_transactions')}');
        },
      ),
    );
  }

  Future<void> _shareBook(BuildContext ctx) async {
    final members = await PbService.instance.getMembers(_book.id!);
    if (!ctx.mounted) return;

    final emailCtrl   = TextEditingController();
    MemberRole selRole = MemberRole.employee;

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(AppStrings.tr('share_book')),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (members.isNotEmpty) ...[
                Text(AppStrings.tr('share_access'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 8),
                ...members.map((m) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 16, child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?')),
                  title: Text(m.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(m.email, style: const TextStyle(fontSize: 11)),
                  trailing: Chip(
                    label: Text(m.role.label, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                  ),
                )),
                const Divider(),
              ],
              Text(AppStrings.tr('share_invite'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: AppStrings.tr('share_email'), prefixIcon: const Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MemberRole>(
                value: selRole,
                decoration: InputDecoration(labelText: AppStrings.tr('share_role')),
                items: MemberRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                onChanged: (v) => setDialogState(() => selRole = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(AppStrings.tr('close'))),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: Text(AppStrings.tr('share_invite_btn')),
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;
                try {
                  await PbService.instance.insertMember(Member(
                    bookId: _book.id!,
                    name:   email.split('@').first,
                    email:  email,
                    role:   selRole,
                  ));
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ctx.mounted) _showSnack(ctx, email);
                } catch (e) {
                  if (ctx.mounted) _showSnack(ctx, '${AppStrings.tr('error')}: $e', error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, {bool error = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }
}

// ─── Import Preview Dialog ────────────────────────────────────────────────────
class _ImportPreviewDialog extends StatelessWidget {
  final ImportResult result;
  final VoidCallback onConfirm;

  const _ImportPreviewDialog({required this.result, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${AppStrings.tr('import_prefix')}: ${result.preview.length} ${AppStrings.tr('nav_transactions')}'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (result.errors.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.tr('warnings_count').replaceAll('{count}', '${result.errors.length}'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ...result.errors.take(3).map((e) => Text(e, style: const TextStyle(fontSize: 12))),
                if (result.errors.length > 3) Text(AppStrings.tr('and_more').replaceAll('{count}', '${result.errors.length - 3}')),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          if (result.preview.isEmpty)
            Text(AppStrings.tr('tx_no_entries'))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: result.preview.length.clamp(0, 20),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final tx = result.preview[i];
                  final isIncome = tx.type == TransactionType.income;
                  return ListTile(
                    dense: true,
                    title: Text(tx.categoryName ?? '', style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${tx.date.day}.${tx.date.month}.${tx.date.year}  ${tx.note ?? ''}'),
                    trailing: Text(
                      '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          if (result.preview.length > 20) Text(AppStrings.tr('and_more').replaceAll('{count}', '${result.preview.length - 20}')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.tr('cancel'))),
        if (result.preview.isNotEmpty)
          FilledButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            child: Text('${result.preview.length} ${AppStrings.tr('confirm')}'),
          ),
      ],
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerWidget {
  final Book book;
  final Business business;
  final VoidCallback onRefresh;
  final VoidCallback onViewReports;

  const _DashboardTab({
    required this.book,
    required this.business,
    required this.onRefresh,
    required this.onViewReports,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final summaryAsync = ref.watch(allTimeSummaryProvider(book.id!));
    final transAsync   = ref.watch(allTransactionsProvider(book.id!));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: summaryAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (s) => SummaryCard(
                summary: s,
                currency: book.currency,
                onViewReports: onViewReports,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CashButtons(bookId: book.id!, currency: book.currency, onRefresh: onRefresh),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppStrings.tr('tx_recent'), style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          transAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error:   (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
            data: (txs) {
              if (txs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.all(32),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(AppStrings.tr('tx_no_entries')),
                    ])),
                  ),
                );
              }
              final recent = txs;
              return SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final books = ref.read(booksProvider(business.id!)).valueOrNull ?? [];
                  return TransactionListTile(
                    transaction: recent[i],
                    currency: book.currency,
                    onTap: () => _openDetail(ctx, ref, recent[i], books),
                    onEdit: () => _editTx(ctx, ref, recent[i]),
                    onDelete: () => _deleteTx(ctx, ref, recent[i].id!),
                  );
                },
                childCount: recent.length,
              ));
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ]),
      ),
    );
  }

  void _openDetail(BuildContext ctx, WidgetRef ref, Transaction tx, List<Book> books) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => EntryDetailScreen(
        transaction:    tx,
        currency:       book.currency,
        availableBooks: books,
        onChanged:      onRefresh,
      ),
    ));
  }

  void _editTx(BuildContext ctx, WidgetRef ref, Transaction tx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AddTransactionScreen(bookId: book.id!, existing: tx, currency: book.currency),
    )).then((_) => onRefresh());
  }

  Future<void> _deleteTx(BuildContext ctx, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('tx_delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.tr('delete'))),
        ],
      ),
    );
    if (ok == true) {
      await PbService.instance.deleteTransaction(id, bookId: book.id);
      onRefresh();
    }
  }
}

// ─── CASH IN / CASH OUT quick buttons ────────────────────────────────────────
class _CashButtons extends ConsumerWidget {
  final String bookId;
  final String currency;
  final VoidCallback onRefresh;

  const _CashButtons({required this.bookId, required this.currency, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: Text(AppStrings.tr('tx_cash_in'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                bookId: bookId,
                currency: currency,
                initialType: TransactionType.income,
              ),
            )).then((_) => onRefresh()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(AppStrings.tr('tx_cash_out'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                bookId: bookId,
                currency: currency,
                initialType: TransactionType.expense,
              ),
            )).then((_) => onRefresh()),
          ),
        ),
      ]),
    );
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────
class _TransactionsTab extends ConsumerStatefulWidget {
  final Book book;
  final String currency;
  final VoidCallback onRefresh;
  final VoidCallback onViewReports;

  const _TransactionsTab({required this.book, required this.currency, required this.onRefresh, required this.onViewReports});

  @override
  ConsumerState<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<_TransactionsTab> {
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  bool _batchMode     = false;
  final Set<String>   _selectedIds = {};
  bool _recurringChecked = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      final totalPages = ref.read(paginationTotalProvider(widget.book.id!));
      final page       = ref.read(paginationPageProvider(widget.book.id!));
      if (page < totalPages) {
        ref.read(paginationPageProvider(widget.book.id!).notifier).state = page + 1;
      }
    }
  }

  void _pushFilter() {
    ref.read(paginationPageProvider(widget.book.id!).notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final filter      = ref.watch(transactionFilterProvider(widget.book.id!));
    final transAsync  = ref.watch(paginatedTransactionsProvider(widget.book.id!));
    final totalPages  = ref.watch(paginationTotalProvider(widget.book.id!));
    final page        = ref.watch(paginationPageProvider(widget.book.id!));
    final isOffline   = ref.watch(isOfflineProvider);

    // Check recurring once
    if (!_recurringChecked) {
      _recurringChecked = true;
      _checkRecurringLater();
    }

    return Scaffold(
      body: Column(children: [
        if (isOffline)
          Container(
            width: double.infinity,
            color: Colors.orange.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(AppStrings.tr('offline_banner'),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
          ),
        // Filterleiste: Mehr-Optionen, Datum wählen, Eintragstyp
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: AppStrings.tr('search_title'),
                onPressed: () => _showSearchSheet(context),
              ),
              const SizedBox(width: 4),
              _FilterDropdownButton(
                icon: Icons.calendar_today_outlined,
                label: filter.dateFrom != null || filter.dateTo != null
                    ? _buildDateRangeLabel(filter)
                    : AppStrings.tr('time_filter'),
                highlighted: filter.dateFrom != null || filter.dateTo != null,
                onTap: () => _showDateFilterSheet(context),
                onClear: filter.dateFrom != null || filter.dateTo != null
                    ? () {
                        ref.read(transactionFilterProvider(widget.book.id!).notifier).setDateRange(null, null);
                        _pushFilter();
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              _FilterDropdownButton(
                icon: Icons.category_outlined,
                label: _categoryNameFor(filter.categoryId) ?? AppStrings.tr('category'),
                highlighted: filter.categoryId != null,
                onTap: () => _showCategoryFilterSheet(context),
                onClear: filter.categoryId != null
                    ? () {
                        ref.read(transactionFilterProvider(widget.book.id!).notifier).setCategory(null);
                        _pushFilter();
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              _FilterDropdownButton(
                icon: Icons.swap_vert,
                label: _typeFilterLabel(filter.typeFilter),
                highlighted: filter.typeFilter != 'all',
                onTap: () => _showTypeFilterSheet(context),
                onClear: filter.typeFilter != 'all'
                    ? () {
                        ref.read(transactionFilterProvider(widget.book.id!).notifier).setType('all');
                        _pushFilter();
                      }
                    : null,
              ),
            ]),
          ),
        ),
        // Batch mode bar
        if (_batchMode)
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              Text(AppStrings.tr('selected_count').replaceAll('{count}', '${_selectedIds.length}'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(AppStrings.tr('all'), style: const TextStyle(fontSize: 12)),
                onPressed: _selectAll,
              ),
              if (_selectedIds.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: Text(AppStrings.tr('delete_count').replaceAll('{count}', '${_selectedIds.length}'), style: const TextStyle(fontSize: 12, color: Colors.red)),
                  onPressed: _bulkDelete,
                ),
              TextButton(
                onPressed: () => setState(() { _batchMode = false; _selectedIds.clear(); }),
                child: Text(AppStrings.tr('done'), style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        _NettoSaldoCard(bookId: widget.book.id!, currency: widget.currency, onViewReports: widget.onViewReports),
        Expanded(
          child: transAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(AppStrings.tr('offline_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            data: (result) {
              final txs      = (result['items'] as List<Transaction>);
              final balances = (result['balances'] as List<double>);
              final totalItems = result['totalItems'] as int;
              if (txs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(AppStrings.tr('tx_no_entries')),
                ]));
              }

              // Build balance map
              final balanceMap = <String, double>{};
              for (int i = 0; i < txs.length; i++) {
                if (txs[i].id != null) balanceMap[txs[i].id!] = balances[i];
              }

              final groups = <String, List<Transaction>>{};
              for (final tx in txs) {
                groups.putIfAbsent(_dateKey(tx.date), () => []).add(tx);
              }
              final books = ref.read(booksProvider(widget.book.id!)).maybeWhen(data: (b) => b, orElse: () => <Book>[]);
              final items = <_ListItem>[];
              groups.forEach((key, group) {
                final di = group.where((t) => t.type == TransactionType.income).fold(0.0,  (s, t) => s + t.amount);
                final de = group.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.amount);
                items.add(_ListItem.header(key, di, de));
                for (final tx in group) { items.add(_ListItem.tx(tx)); }
              });

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(children: [
                    Text(AppStrings.tr('showing_entries')
                            .replaceAll('{count}', '$totalItems')
                            .replaceAll('{entries}', AppStrings.tr(totalItems == 1 ? 'entry_singular' : 'entry_plural')),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                ),
                Expanded(child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: items.length + (page < totalPages ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final item = items[i];
                  if (item.isHeader) {
                    return _DateHeader(label: item.dateLabel!, dayIncome: item.dayIncome!, dayExpense: item.dayExpense!, currency: widget.currency);
                  }
                  final tx = item.tx!;
                  return TransactionListTile(
                    transaction: tx,
                    currency: widget.currency,
                    balance: balanceMap[tx.id],
                    selected: _selectedIds.contains(tx.id),
                    onTap: _batchMode
                        ? () => _toggleSelect(tx.id!)
                        : () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => EntryDetailScreen(transaction: tx, currency: widget.currency, availableBooks: books, onChanged: widget.onRefresh),
                          )),
                    onEdit: _batchMode ? null : () => Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(bookId: widget.book.id!, existing: tx, currency: widget.currency),
                    )).then((_) => widget.onRefresh()),
                    onDelete: _batchMode ? null : () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          title: Text(AppStrings.tr('tx_delete_confirm')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.tr('cancel'))),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.tr('delete'))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await PbService.instance.deleteTransaction(tx.id!, bookId: widget.book.id);
                        widget.onRefresh();
                      }
                    },
                    onLongPress: () {
                      if (!_batchMode) {
                        setState(() { _batchMode = true; _selectedIds.add(tx.id!); });
                      }
                    },
                  );
                },
              )),
              ]);
            },
          ),
        ),
      ]),
      floatingActionButton: _batchMode
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton(
                heroTag: 'fab_income',
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                mini: true,
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(bookId: widget.book.id!, currency: widget.currency, initialType: TransactionType.income),
                )).then((_) => widget.onRefresh()),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'fab_expense',
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.remove),
                label: Text(AppStrings.tr('tx_cash_out')),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(bookId: widget.book.id!, currency: widget.currency, initialType: TransactionType.expense),
                )).then((_) => widget.onRefresh()),
              ),
            ]),
    );
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _batchMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final result = ref.read(paginatedTransactionsProvider(widget.book.id!)).valueOrNull;
    final txs = (result?['items'] as List<Transaction>?) ?? [];
    setState(() => _selectedIds.addAll(txs.where((t) => t.id != null).map((t) => t.id!)));
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('bulk_delete_title').replaceAll('{count}', '${_selectedIds.length}')),
        content: Text(AppStrings.tr('bulk_delete_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('delete'))),
        ],
      ),
    );
    if (ok == true) {
      final ids = _selectedIds.toList();
      final deleted = await PbService.instance.bulkDeleteTransactions(ids, bookId: widget.book.id);
      setState(() { _batchMode = false; _selectedIds.clear(); });
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.tr('bulk_deleted_snackbar').replaceAll('{count}', '$deleted'))),
        );
      }
    }
  }

  String? _categoryNameFor(String? categoryId) {
    if (categoryId == null) return null;
    final categories = ref.read(categoriesProvider(null)).maybeWhen(data: (c) => c, orElse: () => <Category>[]);
    for (final c in categories) {
      if (c.id == categoryId) return c.name;
    }
    return null;
  }

  void _showCategoryFilterSheet(BuildContext context) {
    final filter = ref.read(transactionFilterProvider(widget.book.id!));
    final categoriesAsync = ref.read(categoriesProvider(null));
    final categories = categoriesAsync.maybeWhen(data: (c) => c, orElse: () => <Category>[]);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (sheetCtx, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(AppStrings.tr('category'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              RadioListTile<String?>(
                title: Text(AppStrings.tr('all_categories')), value: null, groupValue: filter.categoryId,
                onChanged: (v) { ref.read(transactionFilterProvider(widget.book.id!).notifier).setCategory(v); _pushFilter(); Navigator.pop(context); },
              ),
              ...categories.map((c) => RadioListTile<String?>(
                title: Row(children: [
                  Icon(categoryIcon(c.icon), size: 18, color: Color(c.colorValue)),
                  const SizedBox(width: 10),
                  Text(c.name),
                ]),
                value: c.id, groupValue: filter.categoryId,
                onChanged: (v) { ref.read(transactionFilterProvider(widget.book.id!).notifier).setCategory(v); _pushFilter(); Navigator.pop(context); },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _typeFilterLabel(String typeFilter) {
    switch (typeFilter) {
      case 'income':  return AppStrings.tr('income');
      case 'expense': return AppStrings.tr('expense');
      default:        return AppStrings.tr('type');
    }
  }

  void _showTypeFilterSheet(BuildContext context) {
    final filter = ref.read(transactionFilterProvider(widget.book.id!));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(AppStrings.tr('type'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          RadioListTile<String>(
            title: Text(AppStrings.tr('all')), value: 'all', groupValue: filter.typeFilter,
            onChanged: (v) { ref.read(transactionFilterProvider(widget.book.id!).notifier).setType(v!); _pushFilter(); Navigator.pop(sheetCtx); },
          ),
          RadioListTile<String>(
            title: Text(AppStrings.tr('income')), value: 'income', groupValue: filter.typeFilter,
            onChanged: (v) { ref.read(transactionFilterProvider(widget.book.id!).notifier).setType(v!); _pushFilter(); Navigator.pop(sheetCtx); },
          ),
          RadioListTile<String>(
            title: Text(AppStrings.tr('expense')), value: 'expense', groupValue: filter.typeFilter,
            onChanged: (v) { ref.read(transactionFilterProvider(widget.book.id!).notifier).setType(v!); _pushFilter(); Navigator.pop(sheetCtx); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.tr('search_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppStrings.tr('search'),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(transactionFilterProvider(widget.book.id!).notifier).setSearch('');
                        _pushFilter();
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              ref.read(transactionFilterProvider(widget.book.id!).notifier).setSearch(v);
              _pushFilter();
            },
            onSubmitted: (_) => Navigator.pop(sheetCtx),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  String _buildDateRangeLabel(TransactionFilter filter) {
    if (filter.dateFrom != null && filter.dateTo != null) return '${_fmtDate(filter.dateFrom!)} – ${_fmtDate(filter.dateTo!)}';
    if (filter.dateFrom != null) return '${AppStrings.tr('filter_from')} ${_fmtDate(filter.dateFrom!)}';
    return '${AppStrings.tr('filter_to')} ${_fmtDate(filter.dateTo!)}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _showDateFilterSheet(BuildContext context) async {
    final filter = ref.read(transactionFilterProvider(widget.book.id!));
    DateTime? tempFrom = filter.dateFrom;
    DateTime? tempTo   = filter.dateTo;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.tr('filter_date_range'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _DatePickerField(
                  label: AppStrings.tr('filter_from'),
                  value: tempFrom,
                  lastDate: tempTo,
                  onPicked: (d) => setSheetState(() => tempFrom = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePickerField(
                  label: AppStrings.tr('filter_to'),
                  value: tempTo,
                  firstDate: tempFrom,
                  onPicked: (d) => setSheetState(() => tempTo = d),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  ref.read(transactionFilterProvider(widget.book.id!).notifier).setDateRange(null, null);
                  _pushFilter();
                },
                child: Text(AppStrings.tr('filter_clear')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  ref.read(transactionFilterProvider(widget.book.id!).notifier).setDateRange(tempFrom, tempTo);
                  _pushFilter();
                },
                child: Text(AppStrings.tr('filter_apply')),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _dateKey(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(d.year, d.month, d.day);
    if (day == today) return '${AppStrings.tr('today')}, ${formatDate(d)}';
    if (day == today.subtract(const Duration(days: 1))) return '${AppStrings.tr('yesterday')}, ${formatDate(d)}';
    return formatDate(d);
  }

  void _checkRecurringLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allTransactionsProvider(widget.book.id!).future).then((txs) {
        if (mounted) _checkRecurring(context, txs);
      });
    });
  }

  Future<void> _checkRecurring(BuildContext context, List<Transaction> allTxs) async {
    final now       = DateTime.now();
    final monthFrom = DateTime(now.year, now.month, 1);
    final monthTo   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final currentTxs  = allTxs.where((t) => !t.date.isBefore(monthFrom) && !t.date.isAfter(monthTo)).toList();
    final prevFrom    = DateTime(now.year, now.month - 1, 1);
    final prevTo      = DateTime(now.year, now.month, 0, 23, 59, 59);

    try {
      final prevTxs       = await PbService.instance.getTransactions(bookId: widget.book.id!, from: prevFrom, to: prevTo);
      final prevRecurring = prevTxs.where((t) => t.isRecurring).toList();
      if (prevRecurring.isEmpty) return;

      final currentTitles = currentTxs
          .where((t) => t.isRecurring)
          .map((t) => '${t.title}_${t.type.name}')
          .toSet();
      final missing = prevRecurring
          .where((t) => !currentTitles.contains('${t.title}_${t.type.name}'))
          .toList();
      if (missing.isEmpty || !context.mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppStrings.tr('recurring_prompt_title')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${missing.length} ${AppStrings.tr('nav_transactions')}:'),
            const SizedBox(height: 8),
            ...missing.take(5).map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(t.type == TransactionType.income ? Icons.add : Icons.remove,
                    size: 14, color: t.type == TransactionType.income ? Colors.green : Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(t.title, style: const TextStyle(fontSize: 13))),
                Text(formatCurrency(t.amount, currency: widget.currency),
                    style: const TextStyle(fontSize: 12)),
              ]),
            )),
            if (missing.length > 5) Text(AppStrings.tr('and_more').replaceAll('{count}', '${missing.length - 5}')),
            const SizedBox(height: 8),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('recurring_skip'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('recurring_create'))),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        for (final t in missing) {
          final copy = Transaction(
            bookId:      widget.book.id!,
            categoryId:  t.categoryId,
            title:       t.title,
            amount:      t.amount,
            type:        t.type,
            date:        DateTime(now.year, now.month, t.date.day.clamp(1, 28)),
            note:        t.note,
            paymentMode: t.paymentMode,
            contact:     t.contact,
            isRecurring: true,
            recurrenceInterval: t.recurrenceInterval ?? 'monthly',
          );
          await PbService.instance.insertTransaction(copy);
        }
        widget.onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${missing.length} ${AppStrings.tr('nav_transactions')}')),
          );
        }
      }
    } catch (_) {}
  }
}

// ─── Date Picker Field ────────────────────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = value != null
        ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
        : '–';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2100),
        );
        onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Text(fmt, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

// ─── Date Group Header ────────────────────────────────────────────────────────
// ── Filter-Dropdown-Knopf (Datum/Eintragstyp) ──────────────────────────────────
class _FilterDropdownButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterDropdownButton({
    required this.icon, required this.label, required this.highlighted,
    required this.onTap, this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? Theme.of(context).colorScheme.primary : Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlighted ? color : Colors.grey.shade300),
          color: highlighted ? color.withValues(alpha: 0.08) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal)),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 14, color: color)),
          ] else ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 15, color: color),
          ],
        ]),
      ),
    );
  }
}

// ── Nettosaldo-Karte mit Link zu den Berichten ─────────────────────────────────
class _NettoSaldoCard extends ConsumerWidget {
  final String bookId;
  final String currency;
  final VoidCallback onViewReports;

  const _NettoSaldoCard({required this.bookId, required this.currency, required this.onViewReports});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(allTimeSummaryProvider(bookId));
    return summaryAsync.when(
      loading: () => const SizedBox(height: 4),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        final balance = s['balance'] ?? 0;
        final income = s['income'] ?? 0;
        final expense = s['expense'] ?? 0;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(AppStrings.tr('net_balance'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const Spacer(),
              Text(formatCurrency(balance, currency: currency),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 16),
            Row(children: [
              Text(AppStrings.tr('total_in'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const Spacer(),
              Text(formatCurrency(income, currency: currency),
                  style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text(AppStrings.tr('total_out'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const Spacer(),
              Text(formatCurrency(expense, currency: currency),
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onViewReports,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(AppStrings.tr('summary_view_reports'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.primary),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  final double dayIncome;
  final double dayExpense;
  final String currency;

  const _DateHeader({required this.label, required this.dayIncome, required this.dayExpense, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const Spacer(),
        if (dayIncome > 0)
          Text('+${formatCurrency(dayIncome, currency: currency)}',
              style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
        if (dayIncome > 0 && dayExpense > 0) const Text('  ', style: TextStyle(fontSize: 11)),
        if (dayExpense > 0)
          Text('-${formatCurrency(dayExpense, currency: currency)}',
              style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── List Item helper ─────────────────────────────────────────────────────────
class _ListItem {
  final bool isHeader;
  final String? dateLabel;
  final double? dayIncome;
  final double? dayExpense;
  final Transaction? tx;

  const _ListItem._({required this.isHeader, this.dateLabel, this.dayIncome, this.dayExpense, this.tx});

  factory _ListItem.header(String label, double income, double expense) =>
      _ListItem._(isHeader: true, dateLabel: label, dayIncome: income, dayExpense: expense);

  factory _ListItem.tx(Transaction t) => _ListItem._(isHeader: false, tx: t);
}
