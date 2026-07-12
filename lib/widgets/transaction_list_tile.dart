import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../utils/formatters.dart';
import '../utils/icon_helper.dart';

class TransactionListTile extends StatelessWidget {
  final Transaction transaction;
  final String currency;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final double? balance;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.currency = 'EUR',
    this.onDelete,
    this.onEdit,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome      = transaction.type == TransactionType.income;
    final amtColor      = isIncome ? Colors.green.shade600 : Colors.red.shade600;
    final catColor      = transaction.categoryColor != null ? Color(transaction.categoryColor!) : Colors.grey;
    final hasAttachments = transaction.attachments.isNotEmpty;

    return Dismissible(
      key: Key('tx_${transaction.id}'),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (_) async { onDelete?.call(); return false; },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        onTap: onTap ?? onEdit,
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: catColor.withValues(alpha: 0.15),
          child: Icon(categoryIcon(transaction.categoryIcon), color: catColor, size: 20),
        ),
        title: Row(children: [
          Expanded(
            child: Text(
              transaction.title.isNotEmpty ? transaction.title : (transaction.categoryName ?? 'Unbekannt'),
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (transaction.isRecurring) ...[
            const SizedBox(width: 4),
            Icon(Icons.repeat, size: 14, color: Colors.blue.shade400),
          ],
        ]),
        subtitle: _Subtitle(transaction: transaction, hasAttachments: hasAttachments, balance: balance, currency: currency),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${isIncome ? '+' : '-'}${formatCurrency(transaction.amount, currency: currency)}',
            style: TextStyle(color: amtColor, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          PopupMenuButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',        child: ListTile(leading: Icon(Icons.edit_outlined),                                                 title: Text('Bearbeiten'),      dense: true)),
              const PopupMenuItem(value: 'detail',      child: ListTile(leading: Icon(Icons.open_in_new_outlined),                                          title: Text('Details'),         dense: true)),
              if (hasAttachments)
                const PopupMenuItem(value: 'attachments', child: ListTile(leading: Icon(Icons.attach_file),                                                 title: Text('Anhänge'),         dense: true)),
              const PopupMenuItem(value: 'delete',      child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Löschen', style: TextStyle(color: Colors.red)), dense: true)),
            ],
            onSelected: (v) {
              if (v == 'edit')        onEdit?.call();
              if (v == 'detail')      (onTap ?? onEdit)?.call();
              if (v == 'delete')      onDelete?.call();
              if (v == 'attachments') _showAttachments(context);
            },
          ),
        ]),
      ),
    );
  }

  void _showAttachments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Anhänge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: transaction.attachments.map((raw) {
            final ext   = raw.split(':').first.toLowerCase();
            final isPdf = ext == 'pdf';
            final bytes = base64Decode(raw.substring(raw.indexOf(':') + 1));
            return GestureDetector(
              onTap: () => _showPreview(context, isPdf, bytes),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: isPdf ? Colors.red.shade50 : null,
                ),
                child: isPdf
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.picture_as_pdf, color: Colors.red),
                        Text('PDF', style: TextStyle(fontSize: 11)),
                      ])
                    : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(bytes, fit: BoxFit.cover)),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _showPreview(BuildContext context, bool isPdf, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: isPdf
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade400),
                  const SizedBox(height: 8),
                  Text('${(bytes.length / 1024).toStringAsFixed(1)} KB'),
                ]),
              )
            : InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final Transaction transaction;
  final bool hasAttachments;
  final double? balance;
  final String currency;

  const _Subtitle({required this.transaction, required this.hasAttachments, this.balance, this.currency = 'EUR'});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (transaction.categoryName != null && transaction.categoryName!.isNotEmpty)
        transaction.categoryName!,
      formatDateTime(transaction.date),
      if (transaction.note != null && transaction.note!.isNotEmpty)
        transaction.note!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              parts.join(' · '),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasAttachments) ...[
            const SizedBox(width: 4),
            Icon(Icons.attach_file, size: 12, color: Colors.grey.shade500),
            Text('${transaction.attachments.length}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ]),
        const SizedBox(height: 2),
        Row(children: [
          if (transaction.paymentMode != null && transaction.paymentMode!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                transaction.paymentMode!,
                style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
              ),
            ),
          const Spacer(),
          if (balance != null)
            Text(
              'Saldo: ${formatCurrency(balance!, currency: currency)}',
              style: TextStyle(fontSize: 11, color: balance! < 0 ? Colors.red.shade600 : Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
        ]),
      ],
    );
  }
}
