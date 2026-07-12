import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import 'pb_service.dart';

class ImportResult {
  final List<model.Transaction> preview;
  final List<String> errors;
  ImportResult({required this.preview, required this.errors});
}

class ImportService {
  static final _dateParsers = [
    // New CashBook CSV format: "15 January 2023", "d MMMM yyyy" – immer
    // englische Monatsnamen, unabhängig von der Browser-/Geräte-Sprache.
    DateFormat('d MMMM yyyy', 'en_US'),
    DateFormat('d MMM yyyy', 'en_US'),
    // Legacy formats
    DateFormat('dd.MM.yyyy', 'de_DE'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('d/M/yyyy'),
  ];

  static DateTime? _parseDate(String raw) {
    final clean = raw.trim().replaceAll('"', '');
    for (final fmt in _dateParsers) {
      try { return fmt.parseStrict(clean); } catch (_) {}
    }
    return null;
  }

  static Future<ImportResult> parseExcel({
    required Uint8List bytes,
    required String bookId,
  }) async {
    final excel      = Excel.decodeBytes(bytes);
    final categories = await PbService.instance.getCategories();
    final catMap     = <String, Category>{};
    for (final c in categories) { catMap[c.name.toLowerCase()] = c; }

    Sheet? sheet;
    for (final name in excel.tables.keys) {
      final n = name.toLowerCase();
      if (n.contains('transaction') || n.contains('buchung') || sheet == null) {
        sheet = excel.tables[name];
      }
    }
    if (sheet == null) {
      return ImportResult(preview: [], errors: ['No transaction sheet found.']);
    }

    final rows = sheet.rows;
    if (rows.isEmpty) return ImportResult(preview: [], errors: ['Sheet is empty.']);

    final header = rows.first
        .map((c) => (c?.value?.toString() ?? '').toLowerCase().trim())
        .toList();

    // Detect column indices — support both new and legacy formats
    final idxDate    = _findCol(header, ['date', 'datum']);
    final idxRemark  = _findCol(header, ['remark', 'notiz', 'note', 'beschreibung', 'title']);
    final idxMode    = _findCol(header, ['mode', 'zahlungsart', 'payment']);
    final idxCashIn  = _findCol(header, ['cash in', 'einnahme', 'income', 'cashin']);
    final idxCashOut = _findCol(header, ['cash out', 'ausgabe', 'expense', 'cashout']);
    final idxAmt     = _findCol(header, ['betrag', 'amount', 'summe']);
    final idxType    = _findCol(header, ['art', 'type', 'typ']);
    final idxCat     = _findCol(header, ['kategorie', 'category', 'cat']);
    final idxEntryBy = _findCol(header, ['entry by', 'entered by']);

    final bool newFormat = idxCashIn != -1 || idxCashOut != -1;

    if (idxDate == -1) {
      return ImportResult(preview: [], errors: [
        'Date column not found. Headers: ${header.join(", ")}',
      ]);
    }

    final txs    = <model.Transaction>[];
    final errors = <String>[];
    final defaultCat = categories.isNotEmpty ? categories.first : null;

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c?.value == null)) continue;

      final rawDate    = _cellStr(row, idxDate);
      final rawRemark  = idxRemark  != -1 ? _cellStr(row, idxRemark)  : '';
      final rawMode    = idxMode    != -1 ? _cellStr(row, idxMode)    : '';
      final rawCat     = idxCat     != -1 ? _cellStr(row, idxCat)     : '';
      final rawEntryBy = idxEntryBy != -1 ? _cellStr(row, idxEntryBy) : '';

      final date = _parseDate(rawDate);
      if (date == null) {
        errors.add('Row ${r + 1}: Invalid date "$rawDate"');
        continue;
      }

      double? amt;
      TransactionType type;

      if (newFormat) {
        // New CashBook format: Cash In / Cash Out columns
        final rawIn  = idxCashIn  != -1 ? _cellStr(row, idxCashIn)  : '';
        final rawOut = idxCashOut != -1 ? _cellStr(row, idxCashOut) : '';
        final cleanIn  = rawIn .replaceAll(',', '').replaceAll('"', '').trim();
        final cleanOut = rawOut.replaceAll(',', '').replaceAll('"', '').trim();
        final amtIn  = double.tryParse(cleanIn);
        final amtOut = double.tryParse(cleanOut);

        if (amtIn != null && amtIn > 0) {
          amt  = amtIn;
          type = TransactionType.income;
        } else if (amtOut != null && amtOut > 0) {
          amt  = amtOut;
          type = TransactionType.expense;
        } else {
          errors.add('Row ${r + 1}: No amount found');
          continue;
        }
      } else {
        // Legacy format: single Amount + Type columns
        final rawAmt  = idxAmt  != -1 ? _cellStr(row, idxAmt)  : '';
        final rawType = idxType != -1 ? _cellStr(row, idxType) : '';
        final cleanAmt = rawAmt.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.\-]'), '');
        amt = double.tryParse(cleanAmt);
        if (amt == null) {
          errors.add('Row ${r + 1}: Invalid amount "$rawAmt"');
          continue;
        }
        if (amt < 0) {
          type = TransactionType.expense;
          amt  = amt.abs();
        } else if (rawType.toLowerCase().contains('ausgabe') ||
            rawType.toLowerCase().contains('expense')) {
          type = TransactionType.expense;
        } else {
          type = TransactionType.income;
        }
      }

      // Skip balance/summary rows (usually the last row in new format)
      if (rawRemark.toLowerCase() == 'final balance' ||
          rawRemark.toLowerCase() == 'balance') { continue; }

      final cat = catMap[rawCat.toLowerCase()] ?? defaultCat;
      if (cat == null) {
        errors.add('Row ${r + 1}: No category found');
        continue;
      }

      txs.add(model.Transaction(
        bookId:      bookId,
        categoryId:  cat.id!,
        title:       rawRemark.isNotEmpty ? rawRemark : cat.name,
        categoryName: cat.name,
        amount:      amt,
        type:        type,
        date:        date,
        note:        rawRemark.isNotEmpty ? rawRemark : null,
        paymentMode: rawMode.isNotEmpty  ? rawMode   : null,
        contact:     rawEntryBy.isNotEmpty ? rawEntryBy : null,
        attachments: [],
      ));
    }

    return ImportResult(preview: txs, errors: errors);
  }

  static final _timeFmt = DateFormat('h:mm a', 'en_US');

  /// CSV-Format wie vom CashBook-Export: Date,Time,Remark,Party,Category,Mode,
  /// Entry By,Cash In,Cash Out,Balance ("Balance" wird ignoriert, sie wird
  /// beim Import aus initialem Saldo + Buchungen neu berechnet).
  static Future<ImportResult> parseCsv({
    required Uint8List bytes,
    required String bookId,
  }) async {
    final text = utf8.decode(bytes);
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(text, fieldDelimiter: ',');
    if (rows.isEmpty) return ImportResult(preview: [], errors: ['Datei ist leer.']);

    final categories = await PbService.instance.getCategories();
    final catMap = <String, Category>{};
    for (final c in categories) { catMap[c.name.toLowerCase()] = c; }
    final defaultCat = categories.isNotEmpty ? categories.first : null;

    final header = rows.first.map((c) => c.toString().toLowerCase().trim()).toList();
    final idxDate    = _findCol(header, ['date', 'datum']);
    final idxTime    = _findCol(header, ['time', 'zeit']);
    final idxRemark  = _findCol(header, ['remark', 'notiz', 'note', 'beschreibung', 'title']);
    final idxParty   = _findCol(header, ['party', 'kontakt', 'contact']);
    final idxCat     = _findCol(header, ['category', 'kategorie']);
    final idxMode    = _findCol(header, ['mode', 'zahlungsart', 'payment']);
    final idxCashIn  = _findCol(header, ['cash in', 'einnahme', 'income']);
    final idxCashOut = _findCol(header, ['cash out', 'ausgabe', 'expense']);

    if (idxDate == -1) {
      return ImportResult(preview: [], errors: ['Spalte "Date" nicht gefunden. Header: ${header.join(", ")}']);
    }

    final txs = <model.Transaction>[];
    final errors = <String>[];

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c == null || c.toString().trim().isEmpty)) continue;

      String cell(int idx) => idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

      final rawDate = cell(idxDate);
      final rawTime = idxTime != -1 ? cell(idxTime) : '';
      final parsedDate = _parseDate(rawDate);
      if (parsedDate == null) {
        errors.add('Zeile ${r + 1}: Ungültiges Datum "$rawDate"');
        continue;
      }
      DateTime date = parsedDate;
      if (rawTime.isNotEmpty) {
        try {
          final t = _timeFmt.parseStrict(rawTime);
          date = DateTime(date.year, date.month, date.day, t.hour, t.minute);
        } catch (_) {}
      }

      final rawRemark = idxRemark != -1 ? cell(idxRemark) : '';
      if (rawRemark.toLowerCase() == 'final balance' || rawRemark.toLowerCase() == 'balance') continue;

      final rawIn  = idxCashIn  != -1 ? cell(idxCashIn)  : '';
      final rawOut = idxCashOut != -1 ? cell(idxCashOut) : '';
      final amtIn  = double.tryParse(rawIn.replaceAll(',', '').trim());
      final amtOut = double.tryParse(rawOut.replaceAll(',', '').trim());

      double amt;
      TransactionType type;
      if (amtIn != null && amtIn > 0) {
        amt = amtIn;
        type = TransactionType.income;
      } else if (amtOut != null && amtOut > 0) {
        amt = amtOut;
        type = TransactionType.expense;
      } else {
        errors.add('Zeile ${r + 1}: Kein Betrag gefunden');
        continue;
      }

      final rawCat = idxCat != -1 ? cell(idxCat) : '';
      final cat = catMap[rawCat.toLowerCase()] ?? defaultCat;
      if (cat == null) {
        errors.add('Zeile ${r + 1}: Keine Kategorie gefunden');
        continue;
      }

      final rawParty = idxParty != -1 ? cell(idxParty) : '';
      final rawMode  = idxMode  != -1 ? cell(idxMode)  : '';

      txs.add(model.Transaction(
        bookId: bookId,
        categoryId: cat.id!,
        title: rawRemark.isNotEmpty ? rawRemark : cat.name,
        categoryName: cat.name,
        amount: amt,
        type: type,
        date: date,
        note: rawRemark.isNotEmpty ? rawRemark : null,
        paymentMode: rawMode.isNotEmpty ? rawMode : null,
        contact: rawParty.isNotEmpty ? rawParty : null,
        attachments: [],
      ));
    }

    return ImportResult(preview: txs, errors: errors);
  }

  static Future<int> saveImport(List<model.Transaction> transactions) async {
    for (final tx in transactions) {
      await PbService.instance.insertTransaction(tx);
    }
    return transactions.length;
  }

  static int _findCol(List<String> header, List<String> names) {
    for (var i = 0; i < header.length; i++) {
      for (final n in names) {
        if (header[i].contains(n)) return i;
      }
    }
    return -1;
  }

  static String _cellStr(List<Data?> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx]?.value?.toString().trim() ?? '';
  }
}
