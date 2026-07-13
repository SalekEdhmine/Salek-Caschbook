import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/app_notification.dart';
import '../providers/app_providers.dart';
import '../services/notify_service.dart';
import '../services/pb_service.dart';
import '../services/push_service.dart';
import '../utils/formatters.dart';
import 'entry_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(appNotificationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(AppStrings.tr('notifications_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: AppStrings.tr('notifications_mark_all_read'),
            onPressed: () async {
              await NotifyService.instance.markAllRead();
              ref.invalidate(appNotificationsProvider);
            },
          ),
        ],
      ),
      body: Column(children: [
        const _PushPermissionBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(appNotificationsProvider),
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
              data: (items) {
                if (items.isEmpty) return _EmptyView();
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                  itemBuilder: (_, i) => _NotificationTile(notification: items[i]),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.tr('notifications_empty'), style: Theme.of(context).textTheme.titleMedium),
        ]),
      ),
    );
  }
}

class _PushPermissionBanner extends StatefulWidget {
  const _PushPermissionBanner();

  @override
  State<_PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<_PushPermissionBanner> {
  bool _loading = false;
  // Solange wir keine erfolgreiche Serverbestätigung hatten, bleibt der
  // Button sichtbar - auch wenn der Browser die Berechtigung schon erteilt
  // hat (sonst gibt es keine Möglichkeit mehr, einen fehlgeschlagenen
  // Server-Speichervorgang erneut zu versuchen).
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final status = PushService.instance.permissionStatus;
    if (status == 'unsupported' || _confirmed) return const SizedBox.shrink();

    final denied = status == 'denied';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: denied ? Colors.orange.withValues(alpha: 0.12) : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppStrings.tr('notifications_push_enable_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          denied ? AppStrings.tr('notifications_push_denied_body') : AppStrings.tr('notifications_push_enable_body'),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (!denied)
          FilledButton(
            onPressed: _loading ? null : _enable,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(AppStrings.tr('notifications_push_enable_button')),
          ),
      ]),
    );
  }

  Future<void> _enable() async {
    setState(() => _loading = true);
    final result = await PushService.instance.subscribe();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == 'granted') {
      setState(() => _confirmed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('notifications_push_success')), backgroundColor: Colors.green),
      );
    } else {
      // Sprechender Fehlercode aus web/push_client.js (z.B. "sw-register-failed: ...")
      // - so laesst sich aus der Ferne nachvollziehen, wo genau es hakt.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.tr('notifications_push_failed')}: $result'), backgroundColor: Colors.red),
      );
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification.type) {
      case 'bank_transaction': return Icons.account_balance;
      case 'shared_transaction': return Icons.group;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: notification.read ? Colors.transparent : scheme.primary.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(_icon, color: scheme.primary, size: 20),
        ),
        title: Text(notification.title, style: TextStyle(fontWeight: notification.read ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          [notification.body, if (notification.created != null) formatDate(notification.created!)]
              .where((s) => s.isNotEmpty)
              .join(' · '),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: notification.read ? null : Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
        ),
        onTap: () => _open(context, ref),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!notification.read) {
      await NotifyService.instance.markRead(notification.id);
      ref.invalidate(appNotificationsProvider);
    }
    if (notification.transactionId == null) return;

    final transaction = await PbService.instance.getTransactionById(notification.transactionId!);
    if (!context.mounted) return;
    if (transaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('bank_syncing_hint'))),
      );
      return;
    }
    final books = (await ref.read(allBooksWithBusinessProvider.future)).map((e) => e.$1).toList();
    final book = books.where((b) => b.id == transaction.bookId).toList();
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => EntryDetailScreen(
        transaction: transaction,
        currency: book.isNotEmpty ? book.first.currency : 'EUR',
        availableBooks: books,
        onChanged: () => ref.invalidate(appNotificationsProvider),
      ),
    ));
  }
}
