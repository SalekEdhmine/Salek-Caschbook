import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Datenschutz & AGB'),
          bottom: const TabBar(tabs: [Tab(text: 'Datenschutz'), Tab(text: 'AGB')]),
        ),
        body: const TabBarView(
          children: [
            _PrivacyTab(),
            _TermsTab(),
          ],
        ),
      ),
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Section('Datenschutzerklärung', '''
Diese App ("CashBook") respektiert deine Privatsphäre und verarbeitet deine Daten nur im Rahmen der gesetzlichen Vorschriften.
'''),
        _Section('1. Verantwortlicher', '''
Verantwortlich für die Datenverarbeitung ist der Betreiber dieser App.

E-Mail: salek.edhmine@gmail.com
'''),
        _Section('2. Welche Daten wir speichern', '''
• Konto-Daten: E-Mail-Adresse, Name und verschlüsseltes Passwort
• Kassenbuch-Daten: Buchungen, Kategorien, Kassenbücher, Business-Profile
• Technische Daten: Anmeldezeit, IP-Adresse (serverseitig, temporär)

Wir speichern keine Zahlungsinformationen, keine Standortdaten und keine Gerätedaten.
'''),
        _Section('3. Datenspeicherung', '''
Alle Daten werden ausschließlich auf unserem Server (Oracle Cloud, Frankfurt/Deutschland) gespeichert. Es gibt keine Weitergabe an Dritte.

Die Daten werden verschlüsselt übertragen (HTTPS/TLS).
'''),
        _Section('4. Deine Rechte', '''
Du hast jederzeit das Recht auf:
• Auskunft über deine gespeicherten Daten
• Berichtigung unrichtiger Daten
• Löschung deiner Daten (Kontoanfrage per E-Mail)
• Einschränkung der Verarbeitung
• Datenübertragbarkeit
'''),
        _Section('5. Datenlöschung', '''
Du kannst die Löschung deines Kontos und aller damit verbundenen Daten jederzeit per E-Mail anfragen. Die Löschung erfolgt innerhalb von 30 Tagen.
'''),
        _Section('6. Cookies & lokaler Speicher', '''
Die App nutzt den lokalen Browser-Speicher (SharedPreferences) für Einstellungen wie Dark Mode und Sprachauswahl. Es werden keine Tracking-Cookies verwendet.
'''),
        _Section('7. Änderungen', '''
Diese Datenschutzerklärung kann gelegentlich aktualisiert werden. Wesentliche Änderungen werden in der App mitgeteilt.

Stand: Mai 2026
'''),
      ]),
    );
  }
}

class _TermsTab extends StatelessWidget {
  const _TermsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Section('Allgemeine Geschäftsbedingungen', '''
Durch die Nutzung von CashBook stimmst du diesen Nutzungsbedingungen zu.
'''),
        _Section('1. Nutzung der App', '''
CashBook ist ein digitales Kassenbuch für private und geschäftliche Buchführung. Die App darf nicht für illegale Zwecke genutzt werden.

Die Nutzung ist kostenlos. Wir behalten uns vor, zukünftig Premium-Funktionen einzuführen.
'''),
        _Section('2. Konto & Verantwortung', '''
Du bist für die Sicherheit deines Kontos verantwortlich. Teile dein Passwort nicht mit anderen.

Du bist verantwortlich für alle Daten, die du in die App eingibst. Wir übernehmen keine Haftung für fehlerhafte Buchungen oder Datenverlust.
'''),
        _Section('3. Verfügbarkeit', '''
Wir bemühen uns um eine hohe Verfügbarkeit des Dienstes, können jedoch keine 100% Uptime garantieren. Wartungsarbeiten oder technische Probleme können zu vorübergehenden Ausfällen führen.
'''),
        _Section('4. Haftungsausschluss', '''
CashBook wird "wie es ist" bereitgestellt. Wir übernehmen keine Haftung für:
• Datenverlust durch technische Fehler
• Falsche Buchungsberechnungen durch Benutzerfehler
• Schäden durch unbefugten Zugriff auf dein Konto
'''),
        _Section('5. Kündigung', '''
Du kannst dein Konto jederzeit durch Kontaktaufnahme per E-Mail löschen lassen. Wir behalten uns vor, Konten bei Verstößen gegen diese AGB zu sperren oder zu löschen.
'''),
        _Section('6. Geltendes Recht', '''
Es gilt deutsches Recht. Gerichtsstand ist Deutschland.

Stand: Mai 2026
'''),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(body.trim(), style: const TextStyle(height: 1.6)),
      ]),
    );
  }
}
