import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/book.dart';
import '../models/category.dart' show TransactionType;
import '../models/transaction.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

/// Papierkorb für gelöschte Buchungen innerhalb eines einzelnen Buchs.
class BookTrashScreen extends StatefulWidget {
  final Book book;
  const BookTrashScreen({super.key, required this.book});

  @override
  State<BookTrashScreen> createState() => _BookTrashScreenState();
}

class _BookTrashScreenState extends State<BookTrashScreen> {
  bool _loading = true;
  List<Transaction> _deleted = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deleted = await PbService.instance.getDeletedTransactions(widget.book.id!);
    if (mounted) setState(() { _deleted = deleted; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('book_trash_title').replaceAll('{book}', widget.book.name))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deleted.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(AppStrings.tr('no_deleted_transactions')),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _deleted.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final tx = _deleted[i];
                    final isIncome = tx.type == TransactionType.income;
                    return ListTile(
                      leading: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isIncome ? Colors.green : Colors.red),
                      title: Text(tx.title.isNotEmpty ? tx.title : (tx.categoryName ?? AppStrings.tr('unknown'))),
                      subtitle: Text(formatDateTime(tx.date)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '${isIncome ? '+' : '-'}${formatCurrency(tx.amount, currency: widget.book.currency)}',
                          style: TextStyle(color: isIncome ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          tooltip: AppStrings.tr('restore_tooltip'),
                          onPressed: () async {
                            await PbService.instance.restoreTransaction(tx.id!);
                            _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          tooltip: AppStrings.tr('permanent_delete_tooltip'),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(AppStrings.tr('permanent_delete_title')),
                                content: Text(AppStrings.tr('permanent_delete_body')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(AppStrings.tr('permanent_delete_tooltip')),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await PbService.instance.permanentlyDeleteTransaction(tx.id!);
                              _load();
                            }
                          },
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
