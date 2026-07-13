import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import 'auth_screen.dart';

// PocketBase sends password reset emails automatically via the built-in UI.
// This screen is shown as a fallback if the user navigates here manually.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(AppStrings.tr('reset_password_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              AppStrings.tr('reset_password_email_body'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false),
              child: Text(AppStrings.tr('go_to_login')),
            ),
          ]),
        ),
      ),
    );
  }
}
