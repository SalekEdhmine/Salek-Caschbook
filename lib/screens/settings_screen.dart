import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../services/pb_service.dart';
import '../services/sync_service.dart';
import '../services/local_db.dart';
import '../services/web_reload.dart';
import '../services/exchange_rate_service.dart';
import '../utils/formatters.dart';
import '../l10n/app_strings.dart';
import '../models/business.dart';
import 'auth_screen.dart';
import 'category_management_screen.dart';
import 'members_screen.dart';
import 'privacy_screen.dart';
import 'business_settings_screen.dart';
import 'trash_screen.dart';
import 'admin_panel_screen.dart';
import 'cashbooks_tab.dart' show BookPickerSheet;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark            = ref.watch(themeModeProvider);
    final notifications     = ref.watch(notificationsProvider);
    final locale            = ref.watch(localeProvider);
    final selectedBusiness  = ref.watch(selectedBusinessProvider);
    final S = AppStrings.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(S('tab_settings')),
        centerTitle: false,
      ),
      body: ListView(children: [

        // ── Business Section ────────────────────────────────────────
        if (selectedBusiness != null) ...[
          _sectionLabel(context, S('sec_business')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Color(selectedBusiness.colorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.business_rounded,
                        color: Color(selectedBusiness.colorValue), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(selectedBusiness.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(selectedBusiness.currency,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ])),
          FilledButton.tonal(
            onPressed: () => _openBusinessSettings(context, ref),
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Text(S('tab_settings'), style: const TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 16),
        _ProfileProgress(business: selectedBusiness),
              ]),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: Text(S('business_settings_title')),
            subtitle: Text(S('business_settings_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openBusinessSettings(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text(S('business_team')),
            subtitle: Text(S('business_team_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openTeam(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(S('cat_manage')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const CategoryManagementScreen(),
            )),
          ),
          const SizedBox(height: 8),
        ],

        // ── Data & Security ─────────────────────────────────────────
        _sectionLabel(context, S('sec_security')),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(S('set_backup')),
          subtitle: Text(S('set_backup_sub')),
          trailing: Icon(Icons.cloud_done_outlined, color: Colors.green.shade600),
          onTap: () => _showInfo(context, S('set_backup'), S('set_backup_sub')),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(S('set_app_lock')),
          subtitle: Text(S('set_app_lock_sub')),
          trailing: Switch(
            value: false,
            onChanged: (_) => _showInfo(context, S('set_app_lock'),
                S('feature_coming_soon')),
          ),
        ),
        const SizedBox(height: 8),

        // ── Appearance ──────────────────────────────────────────────
        _sectionLabel(context, S('sec_appearance')),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(S('set_dark_mode')),
          trailing: Switch(
            value: isDark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).state = v,
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text(S('set_language')),
          subtitle: Text(S('set_language_sub')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(locale.languageCode.toUpperCase(),
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const Icon(Icons.chevron_right),
          ]),
          onTap: () => _showLanguagePicker(context, ref),
        ),
        const SizedBox(height: 8),

        // ── Notifications ────────────────────────────────────────────
        _sectionLabel(context, S('sec_notifications')),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(S('set_notifications')),
          subtitle: Text(S('set_notifications_sub')),
          trailing: Switch(
            value: notifications,
            onChanged: (v) {
              ref.read(notificationsProvider.notifier).state = v;
              if (v) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(S('notifications_enabled_snackbar')),
                  action: SnackBarAction(label: S('ok'), onPressed: () {}),
                ));
              }
            },
          ),
        ),
        const SizedBox(height: 8),

        // ── Profil ──────────────────────────────────────────────────
        _sectionLabel(context, S('sec_profile')),
        _ProfileTile(),
        const Divider(height: 1, indent: 16, endIndent: 16),
        _ChangePasswordTile(),
        const SizedBox(height: 8),

        // ── Synchronisierung ────────────────────────────────────────
        _sectionLabel(context, S('sec_sync')),
        const _SyncTile(),
        const SizedBox(height: 8),

        // ── Wechselkurse ─────────────────────────────────────────────
        _sectionLabel(context, S('sec_exchange_rates')),
        const _ExchangeRatesTile(),
        const SizedBox(height: 8),

        // ── Papierkorb ────────────────────────────────────────────────
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(S('trash')),
          subtitle: Text(S('trash_sub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: Text(S('admin_panel_title')),
          subtitle: Text(S('admin_panel_sub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
        ),
        const SizedBox(height: 8),

        // ── Info ────────────────────────────────────────────────────
        _sectionLabel(context, S('sec_info')),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text(S('app_name')),
          subtitle: Text(S('app_tagline')),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(S('set_version')),
          trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(S('set_privacy')),
          subtitle: Text(S('set_privacy_sub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(S('set_share_app')),
          subtitle: Text(S('set_share_sub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _shareApp(context),
        ),
        const SizedBox(height: 8),

        // ── Konto ───────────────────────────────────────────────────
        _sectionLabel(context, S('sec_account')),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(S('set_logout'), style: const TextStyle(color: Colors.red)),
          onTap: () => _logout(context),
        ),
        const SizedBox(height: 32),

        // Bewusst weit von "Abmelden" getrennt, damit man nicht versehentlich
        // an die falsche Stelle tippt.
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.warning_amber_outlined, color: Colors.grey),
          title: Text(S('advanced'), style: const TextStyle(color: Colors.grey)),
          children: [
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: Text(S('set_delete_account'), style: const TextStyle(color: Colors.red)),
              onTap: () => _showInfo(context, S('set_delete_account'),
                  S('delete_account_body')),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionLabel(BuildContext ctx, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(title,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(ctx).colorScheme.primary,
            letterSpacing: 1)),
  );

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppStrings.tr('set_language'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          ...kSupportedLanguages.map((lang) {
            final code     = lang['code']!;
            final name     = lang['name']!;
            final flag     = lang['flag']!;
            final current  = ref.read(localeProvider).languageCode;
            return ListTile(
              leading: Text(flag, style: const TextStyle(fontSize: 24)),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(code.toUpperCase()),
              trailing: current == code ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLanguage(code);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _shareApp(BuildContext context) {
    const url = 'https://cashbooksakel.chickenkiller.com';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('share_title')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(AppStrings.tr('share_body')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Expanded(child: Text(url, style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: url));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.tr('share_copied'))),
                  );
                },
              ),
            ]),
          ),
        ]),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.tr('close')),
          ),
        ],
      ),
    );
  }

  void _openBusinessSettings(BuildContext context, WidgetRef ref) {
    final business = ref.read(selectedBusinessProvider);
    if (business == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BusinessSettingsScreen(business: business),
    ));
  }

  Future<void> _openTeam(BuildContext context, WidgetRef ref) async {
    final business = ref.read(selectedBusinessProvider);
    if (business == null) return;
    final books = ref.read(booksProvider(business.id!)).valueOrNull
        ?? await PbService.instance.getBooks(business.id!);
    if (!context.mounted) return;
    if (books.isEmpty) {
      _showInfo(context, AppStrings.tr('no_book_title'),
          AppStrings.tr('no_book_body'));
      return;
    }
    if (books.length == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MembersScreen(book: books.first)));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => BookPickerSheet(
        books: books,
        title: AppStrings.tr('which_book_members'),
        onSelect: (book) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => MembersScreen(book: book)));
        },
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.tr('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final S = AppStrings.tr;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S('logout_title')),
        content: Text(S('logout_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(S('logout_btn'))),
        ],
      ),
    );
    if (ok == true) {
      AuthService.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
        );
      }
    }
  }
}

// ── Profile Progress ──────────────────────────────────────────────────────────
class _ProfileProgress extends StatelessWidget {
  final Business business;
  const _ProfileProgress({required this.business});

  @override
  Widget build(BuildContext context) {
    final pct   = business.profileStrength;
    final label = business.profileStrengthLabel;
    final color = pct < 0.3 ? Colors.red : pct < 0.7 ? Colors.orange : Colors.green;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${(pct * 100).toInt()}%',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
      ]),
      const SizedBox(height: 4),
      Text(AppStrings.tr('profile_status').replaceAll('{label}', label),
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Sync Tile ───────────────────────────────────────────────────────────────
class _SyncTile extends StatefulWidget {
  const _SyncTile();

  @override
  State<_SyncTile> createState() => _SyncTileState();
}

class _SyncTileState extends State<_SyncTile> {
  bool _syncing = false;
  StreamSubscription<bool>? _sub;
  bool _isOnline = SyncService.instance.isOnline;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPending();
    _sub = SyncService.instance.isOnlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
      _loadPending();
    });
  }

  Future<void> _loadPending() async {
    final count = await SyncService.instance.getPendingOpsCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await SyncService.instance.syncNow();
    await _loadPending();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(SyncService.instance.isOnline
            ? AppStrings.tr('sync_status_synced')
            : AppStrings.tr('sync_status_no_connection')),
        backgroundColor: SyncService.instance.isOnline ? Colors.green : Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = LocalDb.instance.inMemoryFallbackActive;
    return ListTile(
      leading: Icon(
        fallback ? Icons.warning_amber_outlined : (_isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
        color: fallback ? Colors.red : (_isOnline ? Colors.green : Colors.orange),
      ),
      title: Text(fallback ? AppStrings.tr('restricted_mode') : (_isOnline ? AppStrings.tr('online_status') : AppStrings.tr('offline_status'))),
      subtitle: Text(fallback
          ? AppStrings.tr('restricted_mode_body')
          : (_pendingCount > 0
              ? AppStrings.tr('pending_changes').replaceAll('{count}', '$_pendingCount')
              : (_isOnline
                  ? AppStrings.tr('sync_auto_online')
                  : AppStrings.tr('sync_auto_offline')))),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_syncing)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(icon: const Icon(Icons.sync), tooltip: AppStrings.tr('sync_now_tooltip'), onPressed: _sync),
        IconButton(
          icon: const Icon(Icons.restart_alt, color: Colors.orange),
          tooltip: AppStrings.tr('reset_local_storage_tooltip'),
          onPressed: () => _confirmReset(context),
        ),
      ]),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('reset_local_storage_title')),
        content: Text(AppStrings.tr('reset_local_storage_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.tr('reset')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalDb.instance.reset();
    // Voller Seiten-Reload statt Weitermachen im selben Tab: zuverlässiger,
    // falls ein Hintergrund-Worker (Web-Speicher) ebenfalls hängen geblieben
    // war. Auf Mobile/Desktop-Apps ist das ein No-Op, dort reicht der Reset.
    reloadPage();
    if (!kIsWeb) {
      await SyncService.instance.syncNow();
      await _loadPending();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.tr('reset_done')),
          backgroundColor: Colors.green,
        ));
      }
    }
  }
}

// ── Exchange Rates Tile ─────────────────────────────────────────────────────
class _ExchangeRatesTile extends StatefulWidget {
  const _ExchangeRatesTile();

  @override
  State<_ExchangeRatesTile> createState() => _ExchangeRatesTileState();
}

class _ExchangeRatesTileState extends State<_ExchangeRatesTile> {
  Map<String, double> _rates = {};
  String _reference = 'EUR';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rates = await ExchangeRateService.getRates();
    final ref = await ExchangeRateService.getReferenceCurrency();
    if (mounted) setState(() { _rates = rates; _reference = ref; });
  }

  @override
  Widget build(BuildContext context) {
    final others = _rates.keys.where((c) => c != _reference).toList()..sort();
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.currency_exchange),
        title: Text(AppStrings.tr('exchange_rates_title')),
        subtitle: Text(others.isEmpty
            ? AppStrings.tr('reference_currency_none').replaceAll('{ref}', _reference)
            : AppStrings.tr('reference_currency_some').replaceAll('{ref}', _reference).replaceAll('{count}', '${others.length}')),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          tooltip: AppStrings.tr('add_rate_tooltip'),
          onPressed: () => _editRate(context, null),
        ),
      ),
      ...others.map((c) => ListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        title: Text('1 $_reference = ${_rates[c]!.toStringAsFixed(4)} $c'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editRate(context, c)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () async {
            await ExchangeRateService.removeRate(c);
            _load();
          }),
        ]),
      )),
    ]);
  }

  Future<void> _editRate(BuildContext context, String? currency) async {
    final currencyCtrl = TextEditingController(text: currency ?? '');
    final rateCtrl = TextEditingController(
        text: currency != null ? _rates[currency]!.toString() : '');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(currency == null ? AppStrings.tr('add_exchange_rate') : AppStrings.tr('edit_exchange_rate')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: currencyCtrl,
            enabled: currency == null,
            decoration: InputDecoration(labelText: AppStrings.tr('currency_code_hint')),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '1 $_reference = ? '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('save'))),
        ],
      ),
    );
    if (result != true) return;
    final code = currencyCtrl.text.trim().toUpperCase();
    final rate = parseFlexibleNumber(rateCtrl.text);
    if (code.isEmpty || code == _reference || rate == null || rate <= 0) return;
    await ExchangeRateService.setRate(code, rate);
    _load();
  }
}

// ── Profile Tile ──────────────────────────────────────────────────────────────
class _ProfileTile extends StatefulWidget {
  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  String _name = '', _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService.currentUser();
    if (mounted) setState(() { _name = user?.name ?? ''; _email = user?.email ?? ''; });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          _name.isNotEmpty ? _name[0].toUpperCase() : '?',
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(_name.isNotEmpty ? _name : AppStrings.tr('no_name')),
      subtitle: Text(_email),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _editName(context),
    );
  }

  Future<void> _editName(BuildContext ctx) async {
    final ctrl = TextEditingController(text: _name);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('change_name')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: AppStrings.tr('name')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.tr('save'))),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await AuthService.updateName(ctrl.text.trim());
      await _load();
    }
  }
}

// ── Change Password Tile ──────────────────────────────────────────────────────
class _ChangePasswordTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: Text(AppStrings.tr('change_password')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDialog(context),
    );
  }

  Future<void> _showDialog(BuildContext ctx) async {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          title: Text(AppStrings.tr('change_password')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: currentCtrl,
                decoration: InputDecoration(labelText: AppStrings.tr('current_password')),
                obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: newCtrl,
                decoration: InputDecoration(labelText: AppStrings.tr('new_password')),
                obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl,
                decoration: InputDecoration(labelText: AppStrings.tr('password_repeat')),
                obscureText: true),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(AppStrings.tr('cancel'))),
            FilledButton(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  setS(() => error = AppStrings.tr('passwords_mismatch'));
                  return;
                }
                final result = await AuthService.changePassword(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (result.success) {
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(AppStrings.tr('password_changed'))),
                    );
                  }
                } else {
                  setS(() => error = result.error);
                }
              },
              child: Text(AppStrings.tr('save')),
            ),
          ],
        ),
      ),
    );
  }
}
