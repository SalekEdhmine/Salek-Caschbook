import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Admin-Panel')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.admin_panel_settings_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text('Admin-Zugang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Separater Login mit deinen PocketBase-Admin-Zugangsdaten',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Admin-E-Mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Admin-Passwort', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outlined)),
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
                  child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Anmelden'),
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
        title: const Text('Admin-Panel'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Admin-Logout', onPressed: widget.onLogout),
        ],
      ),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Übersicht'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Nutzer'),
          NavigationDestination(icon: Icon(Icons.backup_outlined), selectedIcon: Icon(Icons.backup), label: 'Backups'),
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
          _StatCard(label: 'Nutzer', value: s['users'] ?? 0, icon: Icons.people, color: Colors.blue),
          _StatCard(label: 'Businesses', value: s['businesses'] ?? 0, icon: Icons.business, color: Colors.purple),
          _StatCard(label: 'Bücher', value: s['books'] ?? 0, icon: Icons.menu_book, color: Colors.teal),
          _StatCard(label: 'Buchungen', value: s['transactions'] ?? 0, icon: Icons.receipt_long, color: Colors.orange),
          _StatCard(label: 'Mitglieder', value: s['members'] ?? 0, icon: Icons.group, color: Colors.green),
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
        title: Text('Neues Passwort für ${user['email']}'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Neues Passwort (mind. 8 Zeichen)'), obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Setzen')),
        ],
      ),
    );
    if (newPass == null || newPass.length < 8) return;
    final ok = await AdminService.instance.setUserPassword(user['id'] as String, newPass);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Passwort gesetzt' : 'Fehlgeschlagen'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('"${user['email']}" löschen?'),
        content: const Text('Der Nutzer und alle zugehörigen Daten werden serverseitig gelöscht. Das kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    final success = await AdminService.instance.deleteUser(user['id'] as String);
    if (success) _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Nutzer gelöscht' : 'Fehlgeschlagen'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users == null) return const Center(child: CircularProgressIndicator());
    if (_users!.isEmpty) return const Center(child: Text('Keine Nutzer'));
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
            title: Text(u['name'] as String? ?? '(kein Name)'),
            subtitle: Text(u['email'] as String? ?? ''),
            trailing: PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reset', child: ListTile(leading: Icon(Icons.lock_reset), title: Text('Passwort setzen'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Löschen', style: TextStyle(color: Colors.red)))),
              ],
              onSelected: (v) => v == 'reset' ? _resetPassword(u) : _deleteUser(u),
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
        content: Text(ok ? 'Backup erstellt' : 'Fehlgeschlagen'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) _load();
    }
  }

  Future<void> _delete(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('"$key" löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
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
      title: const Text('Backup herunterladen'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Link kopieren und im Browser öffnen (lädt die Backup-Datei herunter):', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        SelectableText(url, style: const TextStyle(fontSize: 12)),
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
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
            label: Text(_creating ? 'Wird erstellt…' : 'Neues Backup erstellen'),
          ),
        ),
      ),
      Expanded(
        child: _backups == null
            ? const Center(child: CircularProgressIndicator())
            : _backups!.isEmpty
                ? const Center(child: Text('Noch keine Backups'))
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
