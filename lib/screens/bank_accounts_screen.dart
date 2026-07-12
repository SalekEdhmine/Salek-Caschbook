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
                PopupMenuItem(value: 'disconnect', child: Text(AppStrings.tr('bank_disconnect'))),
              ],
              onSelected: (v) {
                if (v == 'disconnect') _confirmDisconnect(context, ref);
              },
            ),
          ]),
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
              trailing: const Icon(Icons.chevron_right),
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
