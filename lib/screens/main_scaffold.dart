import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../l10n/app_strings.dart';
import '../services/pb_service.dart';
import 'cashbooks_tab.dart';
import 'bank_accounts_screen.dart';
import 'entry_detail_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;
  Timer? _notificationsPoll;

  @override
  void initState() {
    super.initState();
    // Aktualisiert den Ungelesen-Badge periodisch im Hintergrund, nicht nur
    // beim Öffnen des Benachrichtigungs-Tabs.
    _notificationsPoll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(notificationsProvider);
    });
    // Nach dem Enable-Banking-Redirect landet man hier mit ?bank=connected
    // bzw. ?bank=error (siehe enablebanking_service /enablebanking/callback).
    final bankResult = Uri.base.queryParameters['bank'];
    if (bankResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (bankResult == 'connected') {
          setState(() => _index = 1);
          ref.invalidate(bankConnectionsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.tr('bank_connected_snackbar')), backgroundColor: Colors.green),
          );
        } else if (bankResult == 'error') {
          setState(() => _index = 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.tr('bank_connect_failed_snackbar')), backgroundColor: Colors.red),
          );
        }
      });
    }

    // Klick auf eine Push-Benachrichtigung landet hier mit ?openTx=<id>
    // (siehe web/push_sw.js notificationclick) - öffnet direkt die Buchung.
    final openTx = Uri.base.queryParameters['openTx'];
    if (openTx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTransactionFromLink(openTx));
    }
  }

  Future<void> _openTransactionFromLink(String transactionId) async {
    final transaction = await PbService.instance.getTransactionById(transactionId);
    if (!mounted || transaction == null) return;
    final books = (await ref.read(allBooksWithBusinessProvider.future)).map((e) => e.$1).toList();
    final book = books.where((b) => b.id == transaction.bookId).toList();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => EntryDetailScreen(
        transaction: transaction,
        currency: book.isNotEmpty ? book.first.currency : 'EUR',
        availableBooks: books,
        onChanged: () {},
      ),
    ));
  }

  @override
  void dispose() {
    _notificationsPoll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider); // rebuild when language changes
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CashbooksTab(),
          BankAccountsScreen(),
          NotificationsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 2) ref.invalidate(notificationsProvider);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: AppStrings.tr('tab_cashbooks'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_outlined),
            selectedIcon: const Icon(Icons.account_balance),
            label: AppStrings.tr('tab_banks'),
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$unread'),
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              label: Text('$unread'),
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications),
            ),
            label: AppStrings.tr('tab_notifications'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppStrings.tr('tab_settings'),
          ),
        ],
      ),
    );
  }
}
