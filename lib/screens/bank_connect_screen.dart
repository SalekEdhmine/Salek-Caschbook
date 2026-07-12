import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../models/bank_connection.dart';
import '../providers/app_providers.dart';
import '../services/bank_service.dart';

const _countryCodes = ['DE', 'AT', 'CH', 'FR', 'ES', 'IT', 'NL', 'GB', 'SE', 'FI', 'LT'];

class BankConnectScreen extends ConsumerStatefulWidget {
  const BankConnectScreen({super.key});

  @override
  ConsumerState<BankConnectScreen> createState() => _BankConnectScreenState();
}

class _BankConnectScreenState extends ConsumerState<BankConnectScreen> {
  String _country = 'DE';
  String _search = '';
  bool _connecting = false;

  @override
  Widget build(BuildContext context) {
    final aspspsAsync = ref.watch(bankAspspsProvider(_country));

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('bank_connect'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _country,
              decoration: InputDecoration(labelText: AppStrings.tr('bank_country'), border: const OutlineInputBorder()),
              items: _countryCodes
                  .map((code) => DropdownMenuItem(value: code, child: Text(AppStrings.tr('country_$code'))))
                  .toList(),
              onChanged: (v) => setState(() => _country = v ?? 'DE'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: AppStrings.tr('bank_search_hint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ]),
        ),
        Expanded(
          child: aspspsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
            data: (banks) {
              final filtered = _search.isEmpty
                  ? banks
                  : banks.where((b) => b.name.toLowerCase().contains(_search.toLowerCase())).toList();
              if (filtered.isEmpty) return Center(child: Text(AppStrings.tr('bank_none_found')));
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final b = filtered[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.account_balance)),
                    title: Text(b.name),
                    subtitle: Text(b.country),
                    onTap: _connecting ? null : () => _connect(b),
                  );
                },
              );
            },
          ),
        ),
        if (_connecting) const LinearProgressIndicator(),
      ]),
    );
  }

  Future<void> _connect(BankAspsp bank) async {
    setState(() => _connecting = true);
    try {
      final url = await BankService.instance.startConnect(aspspName: bank.name, aspspCountry: bank.country);
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.tr('bank_login_open_failed')), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }
}
