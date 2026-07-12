import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Wechselkurse, fest hinterlegt von dir in den Einstellungen – nicht live
/// vom Markt geholt. Alle Kurse sind relativ zu [referenceCurrency] (=1.0).
/// Beispiel: referenceCurrency = 'EUR', rates = {'EUR': 1.0, 'MRU': 400.0}
/// bedeutet 1 EUR = 400 MRU.
class ExchangeRateService {
  static const _key = 'exchange_rates_v1';
  static const _keyRef = 'exchange_rates_reference';
  static const String defaultReference = 'EUR';

  static Future<String> getReferenceCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRef) ?? defaultReference;
  }

  static Future<void> setReferenceCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRef, currency);
  }

  static Future<Map<String, double>> getRates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final ref = await getReferenceCurrency();
    if (raw == null) return {ref: 1.0};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      final rates = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
      rates[ref] = 1.0;
      return rates;
    } catch (_) {
      return {ref: 1.0};
    }
  }

  static Future<void> setRate(String currency, double rateToReference) async {
    final rates = await getRates();
    rates[currency] = rateToReference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rates));
  }

  static Future<void> removeRate(String currency) async {
    final rates = await getRates();
    rates.remove(currency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rates));
  }

  /// Rechnet [amount] von [from] nach [to] um. [rates] ordnet jeder Währung
  /// zu, wie viele Einheiten dieser Währung 1 Referenzwährung entsprechen
  /// (z.B. {'EUR': 1.0, 'MRU': 400.0} bei Referenz EUR). Fehlt ein Kurs,
  /// wird 1:1 angenommen (besser eine grobe Zahl zeigen als abstürzen).
  static double convert(double amount, String from, String to, Map<String, double> rates) {
    if (from == to) return amount;
    final fromRate = rates[from] ?? 1.0; // Einheiten von `from` pro Referenz
    final toRate = rates[to] ?? 1.0;     // Einheiten von `to` pro Referenz
    if (fromRate == 0) return amount;
    return amount * toRate / fromRate;
  }
}
