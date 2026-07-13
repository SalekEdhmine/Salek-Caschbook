import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/bank_connection.dart';
import '../providers/app_providers.dart';
import '../services/bank_service.dart';
import '../utils/formatters.dart';
import 'bank_connect_screen.dart';
import 'bank_transactions_review_screen.dart';

class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    // Zeigt alle 10s die zuletzt gespeicherten Daten neu an (rein lokal aus
    // PocketBase-Cache, keine Bank-Abfrage - die läuft separat per
    // Hintergrund-Sync/Timer alle 6h bzw. manuellem "Aktualisieren").
    _autoRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(bankConnectionsProvider);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(bankConnectionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('tab_banks'))),
      body: connectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e, onRetry: () => ref.invalidate(bankConnectionsProvider)),
        data: (connections) {
          if (connections.isEmpty) return _EmptyView(onConnect: () => _openConnect(context, ref));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bankConnectionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in connections) _ConnectionCard(connection: c),
                const SizedBox(height: 72),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openConnect(context, ref),
        icon: const Icon(Icons.add),
        label: Text(AppStrings.tr('bank_connect')),
      ),
    );
  }

  void _openConnect(BuildContext context, WidgetRef ref) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BankConnectScreen()));
    ref.invalidate(bankConnectionsProvider);
  }
}

/// Öffnet den Ziel-Buch-Picker für genau eine Bankverbindung (jede Bank kann
/// in ein anderes Buch importieren, siehe PUT .../connections/{id}/target-book).
Future<void> _openTargetBookPickerFor(BuildContext context, WidgetRef ref, BankConnection connection) async {
  final booksWithBusiness = await ref.read(allBooksWithBusinessProvider.future);
  // Radio-Werte dürfen kein `null` sein (sonst nicht von "Dialog abgebrochen"
  // unterscheidbar) - '' steht stellvertretend für "Automatisch".
  const autoValue = '';
  final currentGroupValue = connection.targetBook ?? autoValue;

  if (!context.mounted) return;
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(AppStrings.tr('bank_target_book_title')),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppStrings.tr('bank_target_book_body_per_bank').replaceAll('{name}', connection.aspspName),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        RadioListTile<String>(
          title: Text(AppStrings.tr('bank_target_book_auto')),
          value: autoValue,
          groupValue: currentGroupValue,
          onChanged: (v) => Navigator.pop(ctx, v),
        ),
        for (final (book, bizName) in booksWithBusiness)
          RadioListTile<String>(
            title: Text(book.name),
            subtitle: Text(bizName),
            value: book.id!,
            groupValue: currentGroupValue,
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
      ],
    ),
  );

  // Dialog per Tippen außerhalb abgebrochen -> nichts ändern.
  if (selected == null || selected == currentGroupValue) return;
  final newTarget = selected == autoValue ? null : selected;
  try {
    await BankService.instance.setConnectionTargetBook(connection.id, newTarget);
    ref.invalidate(bankConnectionsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('bank_target_book_saved'))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('bank_target_book_save_failed')), backgroundColor: Colors.red),
      );
    }
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onConnect;
  const _EmptyView({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(AppStrings.tr('bank_empty_title'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            AppStrings.tr('bank_empty_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.add_link),
            label: Text(AppStrings.tr('bank_connect')),
          ),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(AppStrings.tr('bank_retry'))),
        ]),
      ),
    );
  }
}

/// Zeigt an, in welches Buch diese Bankverbindung importiert (oder
/// "Automatisch", falls kein eigenes Ziel-Buch gewählt wurde).
class _TargetBookLabel extends ConsumerWidget {
  final BankConnection connection;
  const _TargetBookLabel({required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = TextStyle(fontSize: 12, color: Colors.grey.shade600);
    if (connection.targetBook == null) {
      return Text('→ ${AppStrings.tr('bank_target_book_auto')}', style: style);
    }
    final booksAsync = ref.watch(allBooksWithBusinessProvider);
    return booksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        final match = books.where((e) => e.$1.id == connection.targetBook).toList();
        if (match.isEmpty) return const SizedBox.shrink();
        return Text('→ ${match.first.$1.name}', style: style);
      },
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  final BankConnection connection;
  const _ConnectionCard({required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringSoon = connection.validUntil != null &&
        connection.validUntil!.difference(DateTime.now()).inDays < 14;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.account_balance),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(connection.aspspName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(connection.aspspCountry, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                PopupMenuItem(value: 'target_book', child: Text(AppStrings.tr('bank_target_book_tooltip'))),
                PopupMenuItem(value: 'disconnect', child: Text(AppStrings.tr('bank_disconnect'))),
              ],
              onSelected: (v) {
                if (v == 'target_book') _openTargetBookPickerFor(context, ref, connection);
                if (v == 'disconnect') _confirmDisconnect(context, ref);
              },
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 52),
            child: _TargetBookLabel(connection: connection),
          ),
          if (expiringSoon)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppStrings.tr('bank_expiring_soon')
                        .replaceAll('{date}', formatDate(connection.validUntil!)),
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ]),
            ),
          const Divider(height: 24),
          for (final acc in connection.accounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.credit_card),
              title: Text(acc.name?.isNotEmpty == true ? acc.name! : (acc.iban ?? acc.uid)),
              subtitle: acc.iban != null ? Text(acc.iban!) : null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (acc.balance != null)
                  Text(
                    formatCurrency(acc.balance!, currency: acc.currency ?? 'EUR'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: acc.balance! < 0 ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BankTransactionsReviewScreen(account: acc)),
              ),
            ),
        ]),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('bank_disconnect_title')),
        content: Text(
          AppStrings.tr('bank_disconnect_body').replaceAll('{name}', connection.aspspName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('bank_disconnect'))),
        ],
      ),
    );
    if (ok != true) return;
    final success = await BankService.instance.deleteConnection(connection.id);
    ref.invalidate(bankConnectionsProvider);
    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('bank_disconnect_failed')), backgroundColor: Colors.red),
      );
    }
  }
}
