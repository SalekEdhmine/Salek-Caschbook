import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../services/admin_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _loggedIn = AdminService.instance.isLoggedIn;

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return _AdminLoginView(onLoggedIn: () => setState(() => _loggedIn = true));
    }
    return _AdminDashboard(onLogout: () {
      AdminService.instance.logout();
      setState(() => _loggedIn = false);
    });
  }
}

// ── Login ───────────────────────────────────────────────────────────────────
class _AdminLoginView extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const _AdminLoginView({required this.onLoggedIn});

  @override
  State<_AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<_AdminLoginView> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await AdminService.instance.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      widget.onLoggedIn();
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('admin_panel_title'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.admin_panel_settings_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(AppStrings.tr('admin_access'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(AppStrings.tr('admin_access_sub'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: AppStrings.tr('admin_email'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                decoration: InputDecoration(labelText: AppStrings.tr('admin_password'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outlined)),
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppStrings.tr('login_tab')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────
class _AdminDashboard extends StatefulWidget {
  final VoidCallback onLogout;
  const _AdminDashboard({required this.onLogout});

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _StatsTab(),
      _UsersTab(),
      _BackupsTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('admin_panel_title')),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: AppStrings.tr('admin_logout_tooltip'), onPressed: widget.onLogout),
        ],
      ),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: AppStrings.tr('nav_overview')),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: AppStrings.tr('nav_users')),
          NavigationDestination(icon: const Icon(Icons.backup_outlined), selectedIcon: const Icon(Icons.backup), label: AppStrings.tr('nav_backups')),
        ],
      ),
    );
  }
}

// ── Tab: Übersicht / Statistiken ──────────────────────────────────────────────
class _StatsTab extends StatefulWidget {
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Map<String, int>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await AdminService.instance.getStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _stats ?? {};
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _StatCard(label: AppStrings.tr('stat_users'), value: s['users'] ?? 0, icon: Icons.people, color: Colors.blue),
          _StatCard(label: AppStrings.tr('stat_businesses'), value: s['businesses'] ?? 0, icon: Icons.business, color: Colors.purple),
          _StatCard(label: AppStrings.tr('stat_books'), value: s['books'] ?? 0, icon: Icons.menu_book, color: Colors.teal),
          _StatCard(label: AppStrings.tr('stat_transactions'), value: s['transactions'] ?? 0, icon: Icons.receipt_long, color: Colors.orange),
          _StatCard(label: AppStrings.tr('stat_members'), value: s['members'] ?? 0, icon: Icons.group, color: Colors.green),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 26),
        const Spacer(),
        Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]),
    );
  }
}

// ── Tab: Nutzer ────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>>? _users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await AdminService.instance.getUsers();
    if (mounted) setState(() => _users = users);
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final ctrl = TextEditingController();
    final newPass = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('new_password_for').replaceAll('{email}', user['email'] as String? ?? '')),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: AppStrings.tr('new_password_min')), obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(AppStrings.tr('set'))),
        ],
      ),
    );
    if (newPass == null || newPass.length < 8) return;
    final ok = await AdminService.instance.setUserPassword(user['id'] as String, newPass);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? AppStrings.tr('password_set') : AppStrings.tr('failed')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _sendTestNotification(Map<String, dynamic> user) async {
    final devices = await AdminService.instance.sendTestNotification(user['id'] as String);
    if (!mounted) return;
    if (devices < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('failed')), backgroundColor: Colors.red),
      );
    } else if (devices == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('admin_test_notify_no_devices'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('admin_test_notify_sent').replaceAll('{count}', '$devices')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('delete_user_confirm').replaceAll('{email}', user['email'] as String? ?? '')),
        content: Text(AppStrings.tr('delete_user_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    final success = await AdminService.instance.deleteUser(user['id'] as String);
    if (success) _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? AppStrings.tr('user_deleted') : AppStrings.tr('failed')),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users == null) return const Center(child: CircularProgressIndicator());
    if (_users!.isEmpty) return Center(child: Text(AppStrings.tr('no_users')));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _users!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = _users![i];
          return ListTile(
            leading: CircleAvatar(child: Text((u['name'] as String? ?? u['email'] as String? ?? '?')[0].toUpperCase())),
            title: Text(u['name'] as String? ?? AppStrings.tr('no_name_paren')),
            subtitle: Text(u['email'] as String? ?? ''),
            trailing: PopupMenuButton<String>(
              itemBuilder: (_) => [
                PopupMenuItem(value: 'test_notify', child: ListTile(leading: const Icon(Icons.notifications_active_outlined), title: Text(AppStrings.tr('admin_test_notify_menu')))),
                PopupMenuItem(value: 'reset', child: ListTile(leading: const Icon(Icons.lock_reset), title: Text(AppStrings.tr('set_password_menu')))),
                PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: Text(AppStrings.tr('delete'), style: const TextStyle(color: Colors.red)))),
              ],
              onSelected: (v) {
                if (v == 'test_notify') _sendTestNotification(u);
                if (v == 'reset') _resetPassword(u);
                if (v == 'delete') _deleteUser(u);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Tab: Backups ───────────────────────────────────────────────────────────────
class _BackupsTab extends StatefulWidget {
  @override
  State<_BackupsTab> createState() => _BackupsTabState();
}

class _BackupsTabState extends State<_BackupsTab> {
  List<String>? _backups;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final backups = await AdminService.instance.listBackups();
    if (mounted) setState(() => _backups = backups);
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    final ok = await AdminService.instance.createBackup();
    if (mounted) {
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? AppStrings.tr('backup_created') : AppStrings.tr('failed')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) _load();
    }
  }

  Future<void> _delete(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('delete_backup_confirm').replaceAll('{key}', key)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await AdminService.instance.deleteBackup(key);
    _load();
  }

  void _download(String key) {
    final url = AdminService.instance.backupDownloadUrl(key);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(AppStrings.tr('download_backup_title')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppStrings.tr('download_backup_body'), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        SelectableText(url, style: const TextStyle(fontSize: 12)),
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.tr('close')))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _creating ? null : _create,
            icon: _creating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
            label: Text(_creating ? AppStrings.tr('creating_backup') : AppStrings.tr('create_new_backup')),
          ),
        ),
      ),
      Expanded(
        child: _backups == null
            ? const Center(child: CircularProgressIndicator())
            : _backups!.isEmpty
                ? Center(child: Text(AppStrings.tr('no_backups_yet')))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: _backups!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final key = _backups![i];
                        return ListTile(
                          leading: const Icon(Icons.archive_outlined),
                          title: Text(key, style: const TextStyle(fontSize: 13)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.download_outlined), onPressed: () => _download(key)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(key)),
                          ]),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}
