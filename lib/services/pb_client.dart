import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final PocketBase pb;

Future<void> initPocketBase() async {
  final prefs = await SharedPreferences.getInstance();
  final store = AsyncAuthStore(
    save: (data) async => prefs.setString('pb_auth', data),
    initial: prefs.getString('pb_auth'),
  );
  pb = PocketBase('https://cashbooksakel.chickenkiller.com', authStore: store);
}
