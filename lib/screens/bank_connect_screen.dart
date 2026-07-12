import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bank_connection.dart';
import '../providers/app_providers.dart';
import '../services/bank_service.dart';

const _countries = {
  'DE': 'Deutschland',
  'AT': 'Österreich',
  'CH': 'Schweiz',
  'FR': 'Frankreich',
  'ES': 'Spanien',
  'IT': 'Italien',
  'NL': 'Niederlande',
  'GB': 'Großbritannien',
  'SE': 'Schweden',
  'FI': 'Finnland',
  'LT': 'Litauen',
};

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
      appBar: AppBar(title: const Text('Bank verbinden')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _country,
              decoration: const InputDecoration(labelText: 'Land', border: OutlineInputBorder()),
              items: _countries.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _country = v ?? 'DE'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Bank suchen (z.B. Santander, Revolut, Klarna)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
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
              if (filtered.isEmpty) return const Center(child: Text('Keine Bank gefunden'));
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
          const SnackBar(content: Text('Bank-Login konnte nicht geöffnet werden'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }
}
