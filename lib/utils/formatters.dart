import 'package:intl/intl.dart';

String formatCurrency(double amount, {String currency = 'EUR'}) {
  const symbols = {'EUR': '€', 'USD': '\$', 'GBP': '£', 'CHF': 'Fr. ', 'TRY': '₺', 'INR': '₹', 'MRU': 'UM '};
  final symbol = symbols[currency] ?? '$currency ';
  return NumberFormat.currency(locale: 'de_DE', symbol: symbol, decimalDigits: 2).format(amount);
}

String currencySymbol(String currency) {
  const symbols = {'EUR': '€', 'USD': '\$', 'GBP': '£', 'CHF': 'Fr.', 'TRY': '₺', 'INR': '₹', 'MRU': 'UM'};
  return symbols[currency] ?? currency;
}

String formatDate(DateTime date) => DateFormat('dd.MM.yyyy', 'de_DE').format(date);

String formatDateTime(DateTime date) => DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(date);

String formatTime(DateTime date) => DateFormat('HH:mm', 'de_DE').format(date);

String formatMonthYear(DateTime date) => DateFormat('MMMM yyyy', 'de_DE').format(date);

String formatShortDate(DateTime date) => DateFormat('dd. MMM', 'de_DE').format(date);

/// Parst eine Nutzereingabe wie "1.400" oder "1.400,50" oder "400,5" robust
/// als Zahl (deutsche Schreibweise: Punkt = Tausendertrennzeichen, Komma =
/// Dezimaltrennzeichen). Ohne diese Behandlung würde "1.400" (gemeint:
/// eintausendvierhundert) von double.tryParse fälschlich als 1,4 gelesen.
double? parseFlexibleNumber(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  if (s.contains(',')) {
    // Komma ist der Dezimaltrenner -> alle Punkte sind Tausendertrennzeichen.
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    // Nur Punkte, im klassischen Dreiergruppen-Muster (z.B. "1.400", "12.000.000)
    // -> Tausendertrennzeichen, kein Komma vorhanden also keine Nachkommastellen.
    s = s.replaceAll('.', '');
  }
  // Sonst: einzelner Punkt mit 1-2 Nachkommastellen bleibt ein Dezimalpunkt.
  return double.tryParse(s);
}
