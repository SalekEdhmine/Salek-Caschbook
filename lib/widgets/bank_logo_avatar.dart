import 'package:flutter/material.dart';

/// Rundes Bank-Logo (von Enable Banking geliefert) mit sauberem Fallback auf
/// ein Initialen-Icon, falls kein Logo vorhanden ist oder das Laden
/// fehlschlägt (z.B. keine Internetverbindung, CORS, tote URL).
class BankLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final String bankName;
  final double radius;

  const BankLogoAvatar({super.key, required this.logoUrl, required this.bankName, this.radius = 24});

  // Stabile, sanfte Farbe je Bankname (nicht zufällig - dieselbe Bank sieht
  // beim erneuten Aufbauen immer gleich aus).
  Color _colorFor(String name, ColorScheme scheme) {
    final hues = <Color>[
      scheme.primary, Colors.indigo, Colors.teal, Colors.deepPurple,
      Colors.orange.shade700, Colors.blueGrey, Colors.pink.shade400, Colors.brown,
    ];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return hues[hash % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallbackColor = _colorFor(bankName, scheme);
    final initial = bankName.trim().isNotEmpty ? bankName.trim()[0].toUpperCase() : '?';

    Widget fallback() => CircleAvatar(
          radius: radius,
          backgroundColor: fallbackColor.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(color: fallbackColor, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
          ),
        );

    if (logoUrl == null || logoUrl!.isEmpty) return fallback();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.network(
          logoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}
