import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/bank_connection.dart';
import '../providers/app_providers.dart';
import '../services/bank_service.dart';
import '../utils/formatters.dart';
import '../widgets/bank_logo_avatar.dart';
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

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(AppStrings.tr('tab_banks'))),
      body: connectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e, onRetry: () => ref.invalidate(bankConnectionsProvider)),
        data: (connections) {
          if (connections.isEmpty) return _EmptyView(onConnect: () => _openConnect(context, ref));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bankConnectionsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _TotalBalanceHeader(connections: connections),
                const SizedBox(height: 16),
                for (final c in connections) _ConnectionCard(connection: c),
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

/// Gesamtsaldo über alle verbundenen Konten, gruppiert nach Währung (fast
/// immer nur eine Gruppe/EUR, aber korrekt falls doch gemischt).
class _TotalBalanceHeader extends StatelessWidget {
  final List<BankConnection> connections;
  const _TotalBalanceHeader({required this.connections});

  @override
  Widget build(BuildContext context) {
    final byCurrency = <String, double>{};
    var accountCount = 0;
    for (final c in connections) {
      for (final acc in c.accounts) {
        accountCount++;
        if (acc.balance == null) continue;
        final cur = acc.currency ?? 'EUR';
        byCurrency[cur] = (byCurrency[cur] ?? 0) + acc.balance!;
      }
    }
    if (byCurrency.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          AppStrings.tr('bank_total_balance'),
          style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        for (final entry in byCurrency.entries)
          Text(
            formatCurrency(entry.value, currency: entry.key),
            style: TextStyle(color: scheme.onPrimary, fontSize: 30, fontWeight: FontWeight.bold, height: 1.1),
          ),
        const SizedBox(height: 8),
        Text(
          AppStrings.tr('bank_accounts_count').replaceAll('{count}', '$accountCount').replaceAll('{banks}', '${connections.length}'),
          style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8), fontSize: 12),
        ),
      ]),
    );
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.account_balance_outlined, size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.tr('bank_empty_title'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            AppStrings.tr('bank_empty_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.add_link),
            label: Text(AppStrings.tr('bank_connect')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
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

class _AccountTile extends StatelessWidget {
  final BankAccount acc;
  const _AccountTile({required this.acc});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negative = (acc.balance ?? 0) < 0;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BankTransactionsReviewScreen(account: acc)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.credit_card, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  acc.name?.isNotEmpty == true ? acc.name! : (acc.iban ?? acc.uid),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                if (acc.iban != null)
                  Text(acc.iban!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
              ]),
            ),
            const SizedBox(width: 8),
            if (acc.balance != null)
              Text(
                formatCurrency(acc.balance!, currency: acc.currency ?? 'EUR'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: negative ? Colors.red.shade700 : Colors.green.shade700),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ]),
        ),
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

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            BankLogoAvatar(logoUrl: connection.aspspLogo, bankName: connection.aspspName, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(connection.aspspName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(AppStrings.tr('country_${connection.aspspCountry}'), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('  ·  ', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  _TargetBookLabel(connection: connection),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
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
          if (expiringSoon)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
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
            ),
          const SizedBox(height: 12),
          for (final acc in connection.accounts) ...[
            _AccountTile(acc: acc),
            if (acc != connection.accounts.last) const SizedBox(height: 8),
          ],
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
