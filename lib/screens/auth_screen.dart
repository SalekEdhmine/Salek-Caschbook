import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = false;

  // Login
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl  = TextEditingController();
  bool _loginPassVisible = false;
  bool _rememberMe = true;

  // Register
  final _regNameCtrl  = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl  = TextEditingController();
  final _regPass2Ctrl = TextEditingController();
  bool _regPassVisible = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _prefillSavedCredentials();
  }

  Future<void> _prefillSavedCredentials() async {
    final remember = await AuthService.getRememberMe();
    final saved = await AuthService.getSavedCredentials();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (saved != null) {
        _loginEmailCtrl.text = saved.email;
        _loginPassCtrl.text = saved.password;
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regPass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final result = await AuthService.login(
      email: _loginEmailCtrl.text.trim(),
      password: _loginPassCtrl.text,
      rememberMe: _rememberMe,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _goHome();
    } else {
      _showError(result.error ?? AppStrings.tr('error'));
    }
  }

  Future<void> _register() async {
    if (_regPassCtrl.text != _regPass2Ctrl.text) {
      _showError(AppStrings.tr('passwords_mismatch'));
      return;
    }
    setState(() => _loading = true);
    final result = await AuthService.register(
      name: _regNameCtrl.text.trim(),
      email: _regEmailCtrl.text.trim(),
      password: _regPassCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _loginEmailCtrl.text = _regEmailCtrl.text.trim();
      _loginPassCtrl.text  = '';
      _regNameCtrl.clear();
      _regEmailCtrl.clear();
      _regPassCtrl.clear();
      _regPass2Ctrl.clear();
      _tabs.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('account_created')), backgroundColor: Colors.green),
      );
    } else {
      _showError(result.error ?? AppStrings.tr('error'));
    }
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _loginEmailCtrl.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('reset_password_title')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(AppStrings.tr('reset_password_body')),
          const SizedBox(height: 16),
          TextField(
            controller: emailCtrl,
            decoration: InputDecoration(labelText: AppStrings.tr('email_field'), prefixIcon: const Icon(Icons.email_outlined), border: const OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('send_link'))),
        ],
      ),
    );
    if (confirmed != true || emailCtrl.text.trim().isEmpty) return;
    try {
      await AuthService.resetPassword(emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.tr('reset_link_sent')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) _showError('${AppStrings.tr('error')}: $e');
    }
  }

  void _goHome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScaffold()));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(children: [
              const SizedBox(height: 32),
              Icon(Icons.account_balance_wallet_rounded, size: 64, color: scheme.primary),
              const SizedBox(height: 12),
              Text(AppStrings.tr('app_name'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(AppStrings.tr('app_tagline'), style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              Card(
                child: Column(children: [
                  TabBar(
                    controller: _tabs,
                    tabs: [Tab(text: AppStrings.tr('login_tab')), Tab(text: AppStrings.tr('register_tab'))],
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _tabs,
                      children: [_loginForm(), _registerForm()],
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(
          controller: _loginEmailCtrl,
          decoration: InputDecoration(labelText: AppStrings.tr('email_field'), prefixIcon: const Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPassCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.tr('password_field'),
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_loginPassVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _loginPassVisible = !_loginPassVisible),
            ),
          ),
          obscureText: !_loginPassVisible,
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Checkbox(
            value: _rememberMe,
            onChanged: _loading ? null : (v) => setState(() => _rememberMe = v ?? true),
          ),
          Expanded(child: Text(AppStrings.tr('remember_me'))),
          TextButton(
            onPressed: _loading ? null : _forgotPassword,
            child: Text(AppStrings.tr('forgot_password')),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(AppStrings.tr('login_tab')),
          ),
        ),
      ]),
    );
  }

  Widget _registerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(
          controller: _regNameCtrl,
          decoration: InputDecoration(labelText: AppStrings.tr('name'), prefixIcon: const Icon(Icons.person_outlined)),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regEmailCtrl,
          decoration: InputDecoration(labelText: AppStrings.tr('email_field'), prefixIcon: const Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regPassCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.tr('password_min_length'),
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_regPassVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _regPassVisible = !_regPassVisible),
            ),
          ),
          obscureText: !_regPassVisible,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regPass2Ctrl,
          decoration: InputDecoration(labelText: AppStrings.tr('password_repeat'), prefixIcon: const Icon(Icons.lock_outlined)),
          obscureText: !_regPassVisible,
          onSubmitted: (_) => _register(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _register,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(AppStrings.tr('create_account')),
          ),
        ),
      ]),
    );
  }
}
