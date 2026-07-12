import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocketbase/pocketbase.dart';
import 'providers/app_providers.dart';
import 'screens/auth_screen.dart';
import 'screens/main_scaffold.dart';
import 'services/pb_client.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPocketBase();
  await initializeDateFormatting('de_DE', null);
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('ar_SA', null);
  await initializeDateFormatting('fr_FR', null);

  // Offline-first: Connectivity überwachen und bei jedem Login/Reconnect
  // die lokale SQLite-DB mit PocketBase abgleichen. Darf den App-Start nie
  // blockieren – schlägt das (z.B. fehlende SQLite-Web-Unterstützung) fehl,
  // soll die App trotzdem starten statt auf einem weißen Bildschirm zu hängen.
  unawaited(SyncService.instance.start());
  pb.authStore.onChange.listen((_) {
    if (pb.authStore.isValid) SyncService.instance.syncNow();
  });

  runApp(const ProviderScope(child: CashBookApp()));
}

class CashBookApp extends ConsumerWidget {
  const CashBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark  = ref.watch(themeModeProvider);
    final locale  = ref.watch(localeProvider);

    final lightScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2), brightness: Brightness.light);
    final darkScheme  = ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2), brightness: Brightness.dark);

    ThemeData buildTheme(ColorScheme scheme) => ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true),
    );

    return MaterialApp(
      title: 'CashBook',
      debugShowCheckedModeBanner: false,
      theme:     buildTheme(lightScheme),
      darkTheme: buildTheme(darkScheme),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StreamBuilder<AuthStoreEvent>(
        stream: pb.authStore.onChange,
        builder: (context, _) {
          if (pb.authStore.isValid) return const MainScaffold();
          return const AuthScreen();
        },
      ),
    );
  }
}
