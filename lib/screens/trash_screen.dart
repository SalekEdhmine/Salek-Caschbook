import 'package:flutter/material.dart';
import '../models/business.dart';
import '../models/book.dart';
import '../models/category.dart' show TransactionType;
import '../models/transaction.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

/// Globaler Papierkorb: gelöschte Businesses, Bücher und Buchungen (über alle
/// Bücher hinweg, mit Angabe zu welchem Buch sie gehören), mit der
/// Möglichkeit sie wiederherzustellen oder endgültig zu löschen.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _loading = true;
  List<Business> _deletedBusinesses = [];
  List<({Book book, Business business})> _deletedBooks = [];
  List<({Transaction tx, Book book})> _deletedTransactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deletedBusinesses = await PbService.instance.getDeletedBusinesses();
    final activeBusinesses = await PbService.instance.getBusinesses();
    final deletedBooks = <({Book book, Business business})>[];
    final deletedTransactions = <({Transaction tx, Book book})>[];
    for (final b in activeBusinesses) {
      final books = await PbService.instance.getDeletedBooks(b.id!);
      for (final book in books) {
        deletedBooks.add((book: book, business: b));
      }
      final activeBooks = await PbService.instance.getBooks(b.id!);
      for (final book in activeBooks) {
        final txs = await PbService.instance.getDeletedTransactions(book.id!);
        for (final tx in txs) {
          deletedTransactions.add((tx: tx, book: book));
        }
      }
    }
    if (mounted) {
      setState(() {
        _deletedBusinesses = deletedBusinesses;
        _deletedBooks = deletedBooks;
        _deletedTransactions = deletedTransactions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _deletedBusinesses.isEmpty && _deletedBooks.isEmpty && _deletedTransactions.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Papierkorb')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Papierkorb ist leer'),
                ]))
              : ListView(padding: const EdgeInsets.all(8), children: [
                  if (_deletedBusinesses.isNotEmpty) ...[
                    _sectionLabel('Businesses'),
                    ..._deletedBusinesses.map((b) => _TrashTile(
                      icon: Icons.business_rounded,
                      title: b.name,
                      subtitle: 'Business · ${b.currency}',
                      onRestore: () async {
                        await PbService.instance.restoreBusiness(b.id!);
                        _load();
                      },
                      onDeleteForever: () => _confirmForever(
                        title: '"${b.name}" endgültig löschen?',
                        content: 'Das Business und alle zugehörigen Bücher und Buchungen werden unwiderruflich gelöscht.',
                        onConfirm: () async {
                          await PbService.instance.permanentlyDeleteBusiness(b.id!);
                          _load();
                        },
                      ),
                    )),
                  ],
                  if (_deletedBooks.isNotEmpty) ...[
                    _sectionLabel('Bücher'),
                    ..._deletedBooks.map((e) => _TrashTile(
                      icon: Icons.menu_book_rounded,
                      title: e.book.name,
                      subtitle: 'Buch · ${e.business.name}',
                      onRestore: () async {
                        await PbService.instance.restoreBook(e.book.id!);
                        _load();
                      },
                      onDeleteForever: () => _confirmForever(
                        title: '"${e.book.name}" endgültig löschen?',
                        content: 'Das Buch und alle Buchungen darin werden unwiderruflich gelöscht.',
                        onConfirm: () async {
                          await PbService.instance.permanentlyDeleteBook(e.book.id!);
                          _load();
                        },
                      ),
                    )),
                  ],
                  if (_deletedTransactions.isNotEmpty) ...[
                    _sectionLabel('Buchungen'),
                    ..._deletedTransactions.map((e) => _TrashTile(
                      icon: e.tx.type == TransactionType.income ? Icons.arrow_upward : Icons.arrow_downward,
                      title: e.tx.title.isNotEmpty ? e.tx.title : (e.tx.categoryName ?? 'Buchung'),
                      subtitle: '${formatCurrency(e.tx.amount, currency: e.book.currency)} · Buch: ${e.book.name}',
                      onRestore: () async {
                        await PbService.instance.restoreTransaction(e.tx.id!);
                        _load();
                      },
                      onDeleteForever: () => _confirmForever(
                        title: '"${e.tx.title}" endgültig löschen?',
                        content: 'Diese Buchung wird unwiderruflich gelöscht.',
                        onConfirm: () async {
                          await PbService.instance.permanentlyDeleteTransaction(e.tx.id!);
                          _load();
                        },
                      ),
                    )),
                  ],
                ]),
    );
  }

  Widget _sectionLabel(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
    child: Text(title, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold,
        color: Colors.grey.shade600, letterSpacing: 1)),
  );

  Future<void> _confirmForever({
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
    if (ok == true) await onConfirm();
  }
}

class _TrashTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashTile({
    required this.icon, required this.title, required this.subtitle,
    required this.onRestore, required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade500),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.green),
            tooltip: 'Wiederherstellen',
            onPressed: onRestore,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Endgültig löschen',
            onPressed: onDeleteForever,
          ),
        ]),
      ),
    );
  }
}
