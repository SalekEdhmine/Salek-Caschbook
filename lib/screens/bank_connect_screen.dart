import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../models/bank_connection.dart';
import '../providers/app_providers.dart';
import '../services/bank_service.dart';
import '../widgets/bank_logo_avatar.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(AppStrings.tr('bank_connect'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _country,
              decoration: InputDecoration(
                labelText: AppStrings.tr('bank_country'),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: _countryCodes
                  .map((code) => DropdownMenuItem(value: code, child: Text(AppStrings.tr('country_$code'))))
                  .toList(),
              onChanged: (v) => setState(() => _country = v ?? 'DE'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: AppStrings.tr('bank_search_hint'),
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final b = filtered[i];
                  return Card(
                    elevation: 0,
                    color: scheme.surface,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: BankLogoAvatar(logoUrl: b.logo, bankName: b.name, radius: 20),
                      title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(AppStrings.tr('country_${b.country}')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _connecting ? null : () => _connect(b),
                    ),
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
      final url = await BankService.instance.startConnect(
        aspspName: bank.name,
        aspspCountry: bank.country,
        logo: bank.logo,
      );
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
