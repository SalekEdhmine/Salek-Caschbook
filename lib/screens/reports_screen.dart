import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';
import '../widgets/transaction_list_tile.dart';
import 'entry_detail_screen.dart';

enum _RangeMode { all, thisMonth, last3, last6, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String currency;

  const ReportsScreen({super.key, required this.bookId, required this.currency});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _RangeMode _rangeMode = _RangeMode.all; // Default: alles, von Anfang an
  DateTime? _customFrom;
  DateTime? _customTo;
  TransactionType? _typeFilter; // null = alle

  ({DateTime? from, DateTime? to}) get _effectiveRange {
    final now = DateTime.now();
    switch (_rangeMode) {
      case _RangeMode.all:
        return (from: null, to: null);
      case _RangeMode.thisMonth:
        return (from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _RangeMode.last3:
        return (from: DateTime(now.year, now.month - 2, 1), to: now);
      case _RangeMode.last6:
        return (from: DateTime(now.year, now.month - 5, 1), to: now);
      case _RangeMode.custom:
        return (from: _customFrom, to: _customTo);
    }
  }

  Future<void> _pickCustomRange() async {
    final initial = _customFrom != null && _customTo != null
        ? DateTimeRange(start: _customFrom!, end: _customTo!)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _rangeMode = _RangeMode.custom;
        _customFrom = picked.start;
        _customTo = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  String get _rangeLabel {
    switch (_rangeMode) {
      case _RangeMode.all: return 'Gesamter Zeitraum';
      case _RangeMode.thisMonth: return 'Dieser Monat';
      case _RangeMode.last3: return 'Letzte 3 Monate';
      case _RangeMode.last6: return 'Letzte 6 Monate';
      case _RangeMode.custom:
        if (_customFrom == null || _customTo == null) return 'Eigener Zeitraum';
        return '${formatDate(_customFrom!)} – ${formatDate(_customTo!)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _effectiveRange;
    final txAsync = ref.watch(allTransactionsProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Berichte'),
      ),
      body: Column(children: [
        _RangeFilterBar(
          label: _rangeLabel,
          mode: _rangeMode,
          onModeChanged: (m) {
            if (m == _RangeMode.custom) {
              _pickCustomRange();
            } else {
              setState(() => _rangeMode = m);
            }
          },
        ),
        Expanded(
          child: txAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (allTxs) {
              final inRange = allTxs.where((t) {
                if (range.from != null && t.date.isBefore(range.from!)) return false;
                if (range.to != null && t.date.isAfter(range.to!)) return false;
                return true;
              }).toList();

              // Alles auf einer Seite, ohne Tabs – alle Funktionen bleiben,
              // nur untereinander statt in separaten Tabs.
              return _OverviewTab(
                transactions: inRange,
                currency: widget.currency,
                typeFilter: _typeFilter,
                onTypeFilterChanged: (t) => setState(() => _typeFilter = t),
                bookId: widget.bookId,
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Zeitraum-Filterleiste ──────────────────────────────────────────────────────
class _RangeFilterBar extends StatelessWidget {
  final String label;
  final _RangeMode mode;
  final ValueChanged<_RangeMode> onModeChanged;

  const _RangeFilterBar({required this.label, required this.mode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.date_range, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(context, 'Gesamt', _RangeMode.all),
            _chip(context, 'Dieser Monat', _RangeMode.thisMonth),
            _chip(context, '3 Monate', _RangeMode.last3),
            _chip(context, '6 Monate', _RangeMode.last6),
            _chip(context, 'Eigener Zeitraum…', _RangeMode.custom),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(BuildContext context, String label, _RangeMode value) {
    final selected = mode == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onModeChanged(value),
      ),
    );
  }
}

// ── Übersicht: Summe + alle Buchungen (mit Typ-Filter) ─────────────────────────
class _OverviewTab extends ConsumerWidget {
  final List<Transaction> transactions;
  final String currency;
  final TransactionType? typeFilter;
  final ValueChanged<TransactionType?> onTypeFilterChanged;
  final String bookId;

  const _OverviewTab({
    required this.transactions,
    required this.currency,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = transactions.where((t) => t.type == TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final expense = transactions.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);
    final balance = income - expense;

    final filtered = typeFilter == null
        ? transactions
        : transactions.where((t) => t.type == typeFilter).toList();
    final sorted = List<Transaction>.from(filtered)..sort((a, b) => b.date.compareTo(a.date));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          Expanded(child: _StatBox(label: 'Einnahmen', value: income, currency: currency, color: Colors.green.shade600)),
          const SizedBox(width: 8),
          Expanded(child: _StatBox(label: 'Ausgaben', value: expense, currency: currency, color: Colors.red.shade600)),
          const SizedBox(width: 8),
          Expanded(child: _StatBox(
            label: 'Saldo', value: balance, currency: currency,
            color: balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
          )),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          ChoiceChip(label: const Text('Alle'), selected: typeFilter == null, onSelected: (_) => onTypeFilterChanged(null)),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Einnahmen'), selected: typeFilter == TransactionType.income, onSelected: (_) => onTypeFilterChanged(TransactionType.income)),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Ausgaben'), selected: typeFilter == TransactionType.expense, onSelected: (_) => onTypeFilterChanged(TransactionType.expense)),
          const Spacer(),
          Text('${sorted.length} Buchungen', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: sorted.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('Keine Buchungen in diesem Zeitraum'),
              ]))
            : ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (ctx, i) => TransactionListTile(
                  transaction: sorted[i],
                  currency: currency,
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => EntryDetailScreen(
                      transaction: sorted[i], currency: currency,
                      availableBooks: const [], onChanged: () {},
                    ),
                  )),
                ),
              ),
      ),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.currency, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(formatCurrency(value, currency: currency),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

