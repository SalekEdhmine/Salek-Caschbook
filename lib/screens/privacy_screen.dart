import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../providers/app_providers.dart';

typedef _Sec = (String title, String body);

const Map<String, List<_Sec>> _privacySections = {
  'de': [
    ('Datenschutzerklärung', 'Diese App ("CashBook") respektiert deine Privatsphäre und verarbeitet deine Daten nur im Rahmen der gesetzlichen Vorschriften.'),
    ('1. Verantwortlicher', 'Verantwortlich für die Datenverarbeitung ist der Betreiber dieser App.\n\nE-Mail: salek.edhmine@gmail.com'),
    ('2. Welche Daten wir speichern', '• Konto-Daten: E-Mail-Adresse, Name und verschlüsseltes Passwort\n• Kassenbuch-Daten: Buchungen, Kategorien, Kassenbücher, Business-Profile\n• Technische Daten: Anmeldezeit, IP-Adresse (serverseitig, temporär)\n\nWir speichern keine Zahlungsinformationen, keine Standortdaten und keine Gerätedaten.'),
    ('3. Datenspeicherung', 'Alle Daten werden ausschließlich auf unserem Server (Oracle Cloud, Frankfurt/Deutschland) gespeichert. Es gibt keine Weitergabe an Dritte.\n\nDie Daten werden verschlüsselt übertragen (HTTPS/TLS).'),
    ('4. Deine Rechte', 'Du hast jederzeit das Recht auf:\n• Auskunft über deine gespeicherten Daten\n• Berichtigung unrichtiger Daten\n• Löschung deiner Daten (Kontoanfrage per E-Mail)\n• Einschränkung der Verarbeitung\n• Datenübertragbarkeit'),
    ('5. Datenlöschung', 'Du kannst die Löschung deines Kontos und aller damit verbundenen Daten jederzeit per E-Mail anfragen. Die Löschung erfolgt innerhalb von 30 Tagen.'),
    ('6. Cookies & lokaler Speicher', 'Die App nutzt den lokalen Browser-Speicher (SharedPreferences) für Einstellungen wie Dark Mode und Sprachauswahl. Es werden keine Tracking-Cookies verwendet.'),
    ('7. Änderungen', 'Diese Datenschutzerklärung kann gelegentlich aktualisiert werden. Wesentliche Änderungen werden in der App mitgeteilt.\n\nStand: Mai 2026'),
  ],
  'en': [
    ('Privacy Policy', 'This app ("CashBook") respects your privacy and processes your data only within the scope of legal requirements.'),
    ('1. Controller', 'The operator of this app is responsible for data processing.\n\nEmail: salek.edhmine@gmail.com'),
    ('2. What data we store', '• Account data: email address, name and encrypted password\n• Cashbook data: entries, categories, cashbooks, business profiles\n• Technical data: login time, IP address (server-side, temporary)\n\nWe do not store payment information, location data or device data.'),
    ('3. Data storage', 'All data is stored exclusively on our server (Oracle Cloud, Frankfurt/Germany). There is no disclosure to third parties.\n\nData is transmitted encrypted (HTTPS/TLS).'),
    ('4. Your rights', 'You have the right at any time to:\n• Access your stored data\n• Correct inaccurate data\n• Delete your data (account request via email)\n• Restrict processing\n• Data portability'),
    ('5. Data deletion', 'You can request deletion of your account and all associated data at any time via email. Deletion will be carried out within 30 days.'),
    ('6. Cookies & local storage', 'The app uses local browser storage (SharedPreferences) for settings such as dark mode and language selection. No tracking cookies are used.'),
    ('7. Changes', 'This privacy policy may be updated occasionally. Material changes will be communicated in the app.\n\nAs of: May 2026'),
  ],
  'ar': [
    ('سياسة الخصوصية', 'يحترم هذا التطبيق ("CashBook") خصوصيتك ويعالج بياناتك فقط في إطار المتطلبات القانونية.'),
    ('1. الجهة المسؤولة', 'الجهة المسؤولة عن معالجة البيانات هي مشغل هذا التطبيق.\n\nالبريد الإلكتروني: salek.edhmine@gmail.com'),
    ('2. البيانات التي نخزنها', '• بيانات الحساب: البريد الإلكتروني والاسم وكلمة مرور مشفرة\n• بيانات دفتر النقدية: المعاملات والفئات والدفاتر والملفات التجارية\n• بيانات تقنية: وقت تسجيل الدخول وعنوان IP (على الخادم، مؤقتًا)\n\nلا نخزن أي معلومات دفع أو بيانات موقع أو بيانات جهاز.'),
    ('3. تخزين البيانات', 'يتم تخزين جميع البيانات حصريًا على خادمنا (Oracle Cloud، فرانكفورت/ألمانيا). لا يتم مشاركتها مع أي طرف ثالث.\n\nيتم نقل البيانات بشكل مشفر (HTTPS/TLS).'),
    ('4. حقوقك', 'لديك الحق في أي وقت في:\n• الاطلاع على بياناتك المخزنة\n• تصحيح البيانات غير الصحيحة\n• حذف بياناتك (طلب عبر البريد الإلكتروني)\n• تقييد المعالجة\n• نقل البيانات'),
    ('5. حذف البيانات', 'يمكنك طلب حذف حسابك وجميع البيانات المرتبطة به في أي وقت عبر البريد الإلكتروني. يتم الحذف خلال 30 يومًا.'),
    ('6. ملفات تعريف الارتباط والتخزين المحلي', 'يستخدم التطبيق التخزين المحلي للمتصفح (SharedPreferences) لإعدادات مثل الوضع الداكن واختيار اللغة. لا تُستخدم أي ملفات تعريف ارتباط للتتبع.'),
    ('7. التغييرات', 'قد يتم تحديث سياسة الخصوصية هذه من حين لآخر. سيتم إبلاغك بالتغييرات الجوهرية داخل التطبيق.\n\nآخر تحديث: مايو 2026'),
  ],
  'fr': [
    ('Politique de confidentialité', 'Cette application (« CashBook ») respecte votre vie privée et ne traite vos données que dans le cadre des exigences légales.'),
    ('1. Responsable du traitement', "L'exploitant de cette application est responsable du traitement des données.\n\nE-mail : salek.edhmine@gmail.com"),
    ('2. Quelles données nous stockons', "• Données de compte : adresse e-mail, nom et mot de passe chiffré\n• Données du registre de caisse : écritures, catégories, registres, profils d'entreprise\n• Données techniques : heure de connexion, adresse IP (côté serveur, temporaire)\n\nNous ne stockons aucune information de paiement, aucune donnée de localisation ni aucune donnée d'appareil."),
    ('3. Stockage des données', "Toutes les données sont stockées exclusivement sur notre serveur (Oracle Cloud, Francfort/Allemagne). Aucune transmission à des tiers.\n\nLes données sont transmises de manière chiffrée (HTTPS/TLS)."),
    ('4. Vos droits', "Vous avez à tout moment le droit :\n• D'accéder à vos données stockées\n• De faire rectifier des données inexactes\n• De faire supprimer vos données (demande par e-mail)\n• De limiter le traitement\n• À la portabilité des données"),
    ('5. Suppression des données', "Vous pouvez demander la suppression de votre compte et de toutes les données associées à tout moment par e-mail. La suppression sera effectuée dans un délai de 30 jours."),
    ('6. Cookies et stockage local', "L'application utilise le stockage local du navigateur (SharedPreferences) pour des paramètres tels que le mode sombre et le choix de la langue. Aucun cookie de suivi n'est utilisé."),
    ('7. Modifications', "Cette politique de confidentialité peut être mise à jour occasionnellement. Les changements significatifs seront communiqués dans l'application.\n\nDernière mise à jour : mai 2026"),
  ],
};

const Map<String, List<_Sec>> _termsSections = {
  'de': [
    ('Allgemeine Geschäftsbedingungen', 'Durch die Nutzung von CashBook stimmst du diesen Nutzungsbedingungen zu.'),
    ('1. Nutzung der App', 'CashBook ist ein digitales Kassenbuch für private und geschäftliche Buchführung. Die App darf nicht für illegale Zwecke genutzt werden.\n\nDie Nutzung ist kostenlos. Wir behalten uns vor, zukünftig Premium-Funktionen einzuführen.'),
    ('2. Konto & Verantwortung', 'Du bist für die Sicherheit deines Kontos verantwortlich. Teile dein Passwort nicht mit anderen.\n\nDu bist verantwortlich für alle Daten, die du in die App eingibst. Wir übernehmen keine Haftung für fehlerhafte Buchungen oder Datenverlust.'),
    ('3. Verfügbarkeit', 'Wir bemühen uns um eine hohe Verfügbarkeit des Dienstes, können jedoch keine 100% Uptime garantieren. Wartungsarbeiten oder technische Probleme können zu vorübergehenden Ausfällen führen.'),
    ('4. Haftungsausschluss', 'CashBook wird "wie es ist" bereitgestellt. Wir übernehmen keine Haftung für:\n• Datenverlust durch technische Fehler\n• Falsche Buchungsberechnungen durch Benutzerfehler\n• Schäden durch unbefugten Zugriff auf dein Konto'),
    ('5. Kündigung', 'Du kannst dein Konto jederzeit durch Kontaktaufnahme per E-Mail löschen lassen. Wir behalten uns vor, Konten bei Verstößen gegen diese AGB zu sperren oder zu löschen.'),
    ('6. Geltendes Recht', 'Es gilt deutsches Recht. Gerichtsstand ist Deutschland.\n\nStand: Mai 2026'),
  ],
  'en': [
    ('Terms of Service', 'By using CashBook, you agree to these terms of use.'),
    ('1. Use of the app', 'CashBook is a digital cashbook for personal and business bookkeeping. The app may not be used for illegal purposes.\n\nUse is free of charge. We reserve the right to introduce premium features in the future.'),
    ('2. Account & responsibility', 'You are responsible for the security of your account. Do not share your password with others.\n\nYou are responsible for all data you enter into the app. We assume no liability for incorrect entries or data loss.'),
    ('3. Availability', 'We strive for high availability of the service but cannot guarantee 100% uptime. Maintenance or technical issues may cause temporary outages.'),
    ('4. Disclaimer', 'CashBook is provided "as is". We assume no liability for:\n• Data loss due to technical errors\n• Incorrect entry calculations due to user error\n• Damage from unauthorized access to your account'),
    ('5. Termination', 'You can have your account deleted at any time by contacting us via email. We reserve the right to suspend or delete accounts that violate these terms.'),
    ('6. Governing law', 'German law applies. Jurisdiction is Germany.\n\nAs of: May 2026'),
  ],
  'ar': [
    ('الشروط والأحكام العامة', 'باستخدامك لتطبيق CashBook، فإنك توافق على شروط الاستخدام هذه.'),
    ('1. استخدام التطبيق', 'CashBook هو دفتر نقدية رقمي للمحاسبة الشخصية والتجارية. لا يجوز استخدام التطبيق لأغراض غير قانونية.\n\nالاستخدام مجاني. نحتفظ بالحق في تقديم ميزات مدفوعة مستقبلاً.'),
    ('2. الحساب والمسؤولية', 'أنت مسؤول عن أمان حسابك. لا تشارك كلمة المرور الخاصة بك مع الآخرين.\n\nأنت مسؤول عن جميع البيانات التي تدخلها في التطبيق. لا نتحمل أي مسؤولية عن معاملات خاطئة أو فقدان البيانات.'),
    ('3. التوفر', 'نسعى لضمان توفر عالٍ للخدمة، لكن لا يمكننا ضمان توفرها بنسبة 100%. قد تؤدي أعمال الصيانة أو المشاكل التقنية إلى انقطاعات مؤقتة.'),
    ('4. إخلاء المسؤولية', 'يتم توفير CashBook "كما هو". لا نتحمل أي مسؤولية عن:\n• فقدان البيانات بسبب أخطاء تقنية\n• حسابات معاملات خاطئة بسبب خطأ المستخدم\n• أضرار ناتجة عن وصول غير مصرح به لحسابك'),
    ('5. الإنهاء', 'يمكنك طلب حذف حسابك في أي وقت عبر التواصل معنا بالبريد الإلكتروني. نحتفظ بالحق في تعليق أو حذف الحسابات التي تنتهك هذه الشروط.'),
    ('6. القانون المعمول به', 'يسري القانون الألماني. جهة الاختصاص القضائي هي ألمانيا.\n\nآخر تحديث: مايو 2026'),
  ],
  'fr': [
    ("Conditions générales d'utilisation", "En utilisant CashBook, vous acceptez ces conditions d'utilisation."),
    ("1. Utilisation de l'application", "CashBook est un registre de caisse numérique pour la comptabilité personnelle et professionnelle. L'application ne doit pas être utilisée à des fins illégales.\n\nL'utilisation est gratuite. Nous nous réservons le droit d'introduire des fonctionnalités premium à l'avenir."),
    ('2. Compte et responsabilité', "Vous êtes responsable de la sécurité de votre compte. Ne partagez votre mot de passe avec personne.\n\nVous êtes responsable de toutes les données que vous saisissez dans l'application. Nous déclinons toute responsabilité pour des écritures erronées ou une perte de données."),
    ('3. Disponibilité', "Nous nous efforçons d'assurer une haute disponibilité du service, mais ne pouvons garantir une disponibilité de 100 %. Des travaux de maintenance ou des problèmes techniques peuvent entraîner des interruptions temporaires."),
    ('4. Limitation de responsabilité', "CashBook est fourni « en l'état ». Nous déclinons toute responsabilité pour :\n• La perte de données due à des erreurs techniques\n• Des calculs d'écritures erronés dus à une erreur de l'utilisateur\n• Des dommages résultant d'un accès non autorisé à votre compte"),
    ('5. Résiliation', "Vous pouvez faire supprimer votre compte à tout moment en nous contactant par e-mail. Nous nous réservons le droit de suspendre ou de supprimer les comptes en cas de violation de ces conditions."),
    ('6. Droit applicable', "Le droit allemand s'applique. La juridiction compétente est l'Allemagne.\n\nDernière mise à jour : mai 2026"),
  ],
};

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.tr('set_privacy')),
          bottom: TabBar(tabs: [Tab(text: AppStrings.tr('privacy_tab')), Tab(text: AppStrings.tr('terms_tab'))]),
        ),
        body: TabBarView(
          children: [
            _SectionsList(sections: _privacySections[lang] ?? _privacySections['de']!),
            _SectionsList(sections: _termsSections[lang] ?? _termsSections['de']!),
          ],
        ),
      ),
    );
  }
}

class _SectionsList extends StatelessWidget {
  final List<_Sec> sections;
  const _SectionsList({required this.sections});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.map((s) => _Section(s.$1, s.$2)).toList(),
      ),
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
