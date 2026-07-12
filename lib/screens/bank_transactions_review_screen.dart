import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_connection.dart';
import '../models/book.dart';
import '../models/business.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/app_providers.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

/// Zeigt die Umsätze eines verbundenen Bankkontos und erlaubt es, einzelne
/// noch nicht importierte Umsätze als normale CashBook-Buchung zu übernehmen
/// (über [PbService.insertTransaction] – nutzt damit automatisch Offline-Sync,
/// Papierkorb, Berichte und Budgets, ohne Zusatzarbeit).
class BankTransactionsReviewScreen extends ConsumerStatefulWidget {
  final BankAccount account;
  const BankTransactionsReviewScreen({super.key, required this.account});

  @override
  ConsumerState<BankTransactionsReviewScreen> createState() => _BankTransactionsReviewScreenState();
}

class _BankTransactionsReviewScreenState extends ConsumerState<BankTransactionsReviewScreen> {
  // Enable Banking erlaubt "bis zu 90 Tage" - exakt 90 wird an der Grenze
  // abgelehnt (WRONG_TRANSACTIONS_PERIOD), daher etwas Sicherheitsabstand.
  late DateTime _from = DateTime.now().subtract(const Duration(days: 85));
  final DateTime _to = DateTime.now();
  bool _hideImported = true;

  @override
  Widget build(BuildContext context) {
    final args = (accountUid: widget.account.uid, from: _from, to: _to);
    final txAsync = ref.watch(bankTransactionsProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name?.isNotEmpty == true ? widget.account.name! : 'Umsätze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Zeitraum',
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(bankTransactionsProvider(args)),
          ),
        ],
      ),
      body: Column(children: [
        SwitchListTile(
          value: _hideImported,
          onChanged: (v) => setState(() => _hideImported = v),
          title: const Text('Nur neue Umsätze anzeigen'),
          dense: true,
        ),
        const Divider(height: 1),
        Expanded(
          child: txAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
            data: (transactions) {
              final items = _hideImported
                  ? transactions.where((t) => !t.alreadyImported).toList()
                  : transactions;
              if (items.isEmpty) {
                return const Center(child: Text('Keine Umsätze in diesem Zeitraum'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _BankTxTile(
                  tx: items[i],
                  currency: widget.account.currency ?? 'EUR',
                  onImported: () => ref.invalidate(bankTransactionsProvider(args)),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) setState(() => _from = range.start);
  }
}

class _BankTxTile extends StatelessWidget {
  final BankTransaction tx;
  final String currency;
  final VoidCallback onImported;
  const _BankTxTile({required this.tx, required this.currency, required this.onImported});

  @override
  Widget build(BuildContext context) {
    final color = tx.isCredit ? Colors.green : Colors.red;
    final title = tx.counterparty?.isNotEmpty == true
        ? tx.counterparty!
        : (tx.remittanceInfo?.isNotEmpty == true ? tx.remittanceInfo! : 'Umsatz');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [formatDate(tx.date), if (tx.remittanceInfo != null && tx.remittanceInfo != title) tx.remittanceInfo]
            .whereType<String>()
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${tx.isCredit ? '+' : '-'}${formatCurrency(tx.amount, currency: currency)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (tx.alreadyImported)
            const Chip(
              label: Text('Importiert', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          else
            SizedBox(
              height: 28,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: () => _openImportSheet(context),
                child: const Text('Importieren', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  void _openImportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ImportSheet(tx: tx, onImported: onImported),
    );
  }
}

class _ImportSheet extends ConsumerStatefulWidget {
  final BankTransaction tx;
  final VoidCallback onImported;
  const _ImportSheet({required this.tx, required this.onImported});

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  final _titleCtrl = TextEditingController();
  Business? _business;
  Book? _book;
  Category? _category;
  bool _saving = false;

  TransactionType get _type => widget.tx.isCredit ? TransactionType.income : TransactionType.expense;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.tx.counterparty?.isNotEmpty == true
        ? widget.tx.counterparty!
        : (widget.tx.remittanceInfo ?? 'Bankumsatz');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(businessesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Umsatz importieren', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${widget.tx.isCredit ? '+' : '-'}${formatCurrency(widget.tx.amount)} · ${formatDate(widget.tx.date)}',
            style: TextStyle(color: widget.tx.isCredit ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Bezeichnung', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          businessesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (businesses) {
              _business ??= businesses.firstOrNull;
              return DropdownButtonFormField<Business>(
                value: _business,
                decoration: const InputDecoration(labelText: 'Firma / Bereich', border: OutlineInputBorder()),
                items: businesses.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                onChanged: (b) => setState(() { _business = b; _book = null; }),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_business?.id != null)
            Consumer(builder: (context, ref, _) {
              final booksAsync = ref.watch(booksProvider(_business!.id!));
              return booksAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (books) {
                  _book ??= books.firstOrNull;
                  return DropdownButtonFormField<Book>(
                    value: _book,
                    decoration: const InputDecoration(labelText: 'Kassenbuch', border: OutlineInputBorder()),
                    items: books.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                    onChanged: (b) => setState(() => _book = b),
                  );
                },
              );
            }),
          const SizedBox(height: 12),
          Consumer(builder: (context, ref, _) {
            final catsAsync = ref.watch(categoriesProvider(_type));
            return catsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (cats) {
                final selected = cats.any((c) => c.id == _category?.id) ? _category : null;
                return DropdownButtonFormField<Category>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Kategorie', border: OutlineInputBorder()),
                  items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (c) => setState(() => _category = c),
                );
              },
            );
          }),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (_saving || _book == null || _category == null) ? null : _import,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_done),
            label: Text(_saving ? 'Importiere...' : 'Importieren'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ]),
      ),
    );
  }

  Future<void> _import() async {
    if (_book?.id == null || _category?.id == null) return;
    setState(() => _saving = true);
    try {
      await PbService.instance.insertTransaction(Transaction(
        bookId: _book!.id!,
        categoryId: _category!.id!,
        title: _titleCtrl.text.trim().isEmpty ? 'Bankumsatz' : _titleCtrl.text.trim(),
        amount: widget.tx.amount,
        type: _type,
        date: widget.tx.date,
        contact: widget.tx.counterparty,
        note: widget.tx.remittanceInfo,
        paymentMode: 'bank',
        externalRef: widget.tx.externalRef,
      ));
      widget.onImported();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
