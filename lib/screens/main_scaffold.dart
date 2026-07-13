import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../l10n/app_strings.dart';
import 'cashbooks_tab.dart';
import 'bank_accounts_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider); // rebuild when language changes

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CashbooksTab(),
          BankAccountsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppStrings.tr('tab_settings'),
          ),
        ],
      ),
    );
  }
}
