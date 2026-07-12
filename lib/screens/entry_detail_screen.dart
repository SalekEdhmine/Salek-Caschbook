import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/category.dart' show TransactionType;
import '../models/transaction.dart';
import '../models/book.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';
import 'add_transaction_screen.dart';

class EntryDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final String currency;
  final List<Book> availableBooks;
  final VoidCallback onChanged;

  const EntryDetailScreen({
    super.key,
    required this.transaction,
    required this.currency,
    required this.availableBooks,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final amtColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;
    final catColor = transaction.categoryColor != null
        ? Color(transaction.categoryColor!)
        : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buchungsdetails'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEdit(context),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'move',     child: ListTile(leading: Icon(Icons.drive_file_move_outlined), title: Text('Verschieben'),         dense: true)),
              const PopupMenuItem(value: 'copy',     child: ListTile(leading: Icon(Icons.copy_outlined),            title: Text('Kopieren'),             dense: true)),
              const PopupMenuItem(value: 'opposite', child: ListTile(leading: Icon(Icons.swap_vert),                title: Text('Gegenbuchung'),         dense: true)),
              const PopupMenuItem(value: 'delete',   child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Löschen', style: TextStyle(color: Colors.red)), dense: true)),
            ],
            onSelected: (v) => _handleAction(context, v),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Amount hero card
          Card(
            elevation: 0,
            color: amtColor.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: catColor.withValues(alpha: 0.15),
                  child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: catColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      transaction.title.isNotEmpty ? transaction.title : (transaction.categoryName ?? 'Unbekannt'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    if (transaction.categoryName != null)
                      Text(transaction.categoryName!, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text(
                      '${isIncome ? '+' : '-'}${formatCurrency(transaction.amount, currency: currency)}',
                      style: TextStyle(color: amtColor, fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Details
          _DetailCard(children: [
            _DetailRow(icon: Icons.calendar_today,   label: 'Datum',          value: formatDateTime(transaction.date)),
            _DetailRow(icon: Icons.swap_vert,        label: 'Typ',            value: isIncome ? 'Einnahme' : 'Ausgabe'),
            if (transaction.paymentMode != null && transaction.paymentMode!.isNotEmpty)
              _DetailRow(icon: Icons.payment,        label: 'Zahlungsart',    value: transaction.paymentMode!),
            if (transaction.contact != null && transaction.contact!.isNotEmpty)
              _DetailRow(icon: Icons.person_outline, label: 'Kontakt',        value: transaction.contact!),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              _DetailRow(icon: Icons.note_outlined,  label: 'Notiz',          value: transaction.note!),
            if (transaction.isRecurring)
              _DetailRow(icon: Icons.repeat,         label: 'Wiederkehrend',  value: 'Ja'),
            if (transaction.createdAt != null)
              _DetailRow(icon: Icons.schedule,       label: 'Erstellt am',    value: formatDateTime(transaction.createdAt!)),
          ]),

          // Attachments
          if (transaction.attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Anhänge (${transaction.attachments.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: transaction.attachments.map((raw) {
                final ext   = raw.split(':').first.toLowerCase();
                final isPdf = ext == 'pdf';
                final bytes = base64Decode(raw.substring(raw.indexOf(':') + 1));
                return GestureDetector(
                  onTap: () => _showAttachmentPreview(context, isPdf, bytes),
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
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.drive_file_move_outlined),
                label: const Text('Verschieben'),
                onPressed: () => _handleAction(context, 'move'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Kopieren'),
                onPressed: () => _handleAction(context, 'copy'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Löschen', style: TextStyle(color: Colors.red)),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.08)),
              onPressed: () => _handleAction(context, 'delete'),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => AddTransactionScreen(
        bookId: transaction.bookId,
        existing: transaction,
        currency: currency,
      ),
    )).then((_) => onChanged());
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Buchung löschen?'),
            content: const Text('Wandert in den Papierkorb & kann dort wiederhergestellt werden.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (ok == true && transaction.id != null) {
          await PbService.instance.deleteTransaction(transaction.id!, bookId: transaction.bookId);
          onChanged();
          if (context.mounted) Navigator.pop(context);
        }
        break;

      case 'move':
      case 'copy':
      case 'opposite':
        final otherBooks = availableBooks.where((b) => b.id != transaction.bookId).toList();
        if (otherBooks.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kein anderes Buch vorhanden.')),
            );
          }
          return;
        }
        final targetBook = await _pickBook(context, otherBooks,
            title: action == 'move' ? 'Wohin verschieben?' : action == 'copy' ? 'Wohin kopieren?' : 'Gegenbuchung wohin?');
        if (targetBook == null || !context.mounted) return;
        try {
          if (action == 'move') {
            await PbService.instance.moveTransaction(transaction, targetBook.id!);
          } else if (action == 'copy') {
            await PbService.instance.copyTransaction(transaction, targetBook.id!);
          } else {
            await PbService.instance.copyOppositeTransaction(transaction, targetBook.id!);
          }
          onChanged();
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(action == 'move' ? 'Verschoben nach ${targetBook.name}' : 'Kopiert nach ${targetBook.name}'),
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
          }
        }
        break;
    }
  }

  Future<Book?> _pickBook(BuildContext context, List<Book> books, {required String title}) {
    return showModalBottomSheet<Book>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          ...books.map((b) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(b.colorValue).withValues(alpha: 0.15),
              child: Icon(Icons.menu_book_outlined, color: Color(b.colorValue), size: 20),
            ),
            title: Text(b.name),
            onTap: () => Navigator.pop(context, b),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showAttachmentPreview(BuildContext context, bool isPdf, Uint8List bytes) {
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

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: children),
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        subtitle: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      );
}
