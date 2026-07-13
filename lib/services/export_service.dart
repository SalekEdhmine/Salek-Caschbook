import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../models/book.dart';
import '../models/business.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import 'pb_service.dart';


class ExportService {
  static final _dateFmt  = DateFormat('d MMM yyyy', 'en_US');
  static final _timeFmt  = DateFormat('h:mm a', 'en_US');
  static final _moneyFmt = NumberFormat('#,##0.##');

  // ── PDF Export (matches CashBook reference format) ────────────────────────
  static Future<void> exportPdf({
    required BuildContext context,
    required Book book,
    required Business business,
    String? exportedBy,
  }) async {
    final txs  = await PbService.instance.getAllTransactions(book.id!);
    final sorted = List<model.Transaction>.from(txs.reversed); // oldest first

    final summary = await PbService.instance.getSummary(book.id!);
    final totalIn  = summary['income']  ?? 0.0;
    final totalOut = summary['expense'] ?? 0.0;
    final finalBal = summary['balance'] ?? 0.0;
    final cur      = book.currency;

    // Duration string
    final String duration = _buildDuration(sorted);
    final String generatedOn = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());
    final String byName = exportedBy ?? business.name;

    final pdf = pw.Document();
    final blue     = PdfColor.fromHex('1565C0');
    final headerBg = PdfColor.fromHex('EEF2FF');
    final green    = PdfColor.fromHex('2E7D32');
    final red      = PdfColor.fromHex('C62828');
    final tableHdr = PdfColor.fromHex('37474F');

    // Build running-balance rows once
    final tableRows = _buildTableRows(sorted, book.initialBalance, green, red);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => _pdfHeader(headerBg, blue, book.name, generatedOn, byName),
      footer: (_) => _pdfFooter(blue),
      build: (_) => [
        pw.SizedBox(height: 14),
        // Book name
        pw.Text(book.name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        // Duration box
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(children: [
            pw.Text('Duration:  ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(duration, style: const pw.TextStyle(fontSize: 10)),
          ]),
        ),
        pw.SizedBox(height: 10),
        // Summary cards
        pw.Row(children: [
          _summaryCard('Total Cash in',  totalIn,  cur, green),
          pw.SizedBox(width: 6),
          _summaryCard('Total Cash out', totalOut, cur, red),
          pw.SizedBox(width: 6),
          _summaryCard('Final Balance',  finalBal, cur, PdfColors.black),
        ]),
        pw.SizedBox(height: 12),
        pw.Text('Total No. of entries: ${sorted.length}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 6),
        // Transactions table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          columnWidths: {
            0: const pw.FixedColumnWidth(58),
            1: const pw.FlexColumnWidth(2.8),
            2: const pw.FixedColumnWidth(52),
            3: const pw.FixedColumnWidth(64),
            4: const pw.FixedColumnWidth(64),
            5: const pw.FixedColumnWidth(68),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: tableHdr),
              children: ['Date', 'Remark', 'Mode', 'Cash in', 'Cash out', 'Balance']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9)),
                      ))
                  .toList(),
            ),
            ...tableRows,
          ],
        ),
        ..._buildReceiptsSection(sorted),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ── Beleg-Bilder (max. 2 pro Buchung), Spalten an die Haupttabelle angeglichen ──
  // Spaltenbreiten entsprechen 0:Date(58) 1:Remark(flex) 2+3:Belege(64+64=128),
  // damit die Bilder optisch in derselben Spalte wie die Buchung stehen.
  static List<pw.Widget> _buildReceiptsSection(List<model.Transaction> sorted) {
    final withImages = sorted.where((tx) => tx.attachments.any(_isImageAttachment)).toList();
    if (withImages.isEmpty) return [];

    return [
      pw.SizedBox(height: 18),
      pw.Text('Receipts', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: const {
          0: pw.FixedColumnWidth(58),
          1: pw.FlexColumnWidth(2.8),
          2: pw.FixedColumnWidth(128),
        },
        children: withImages.map((tx) {
          final images = tx.attachments.where(_isImageAttachment).take(2).toList();
          final remark = tx.note?.isNotEmpty == true ? tx.note! : tx.title;
          return pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_dateFmt.format(tx.date), style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(remark, style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Row(children: images
                  .map((a) => pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                          child: pw.Image(pw.MemoryImage(_decodeAttachment(a)), fit: pw.BoxFit.cover, height: 60),
                        ),
                      ))
                  .toList()),
            ),
          ]);
        }).toList(),
      ),
    ];
  }

  static bool _isImageAttachment(String a) {
    final ext = a.split(':').first.toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
  }

  static Uint8List _decodeAttachment(String a) {
    final base64Part = a.substring(a.indexOf(':') + 1);
    return base64Decode(base64Part);
  }

  static String _buildDuration(List<model.Transaction> sorted) {
    if (sorted.isEmpty) return '-';
    final min = sorted.first.date;
    final max = sorted.last.date;
    if (min.year == max.year && min.month == max.month && min.day == max.day) {
      return _dateFmt.format(min);
    }
    return '${_dateFmt.format(min)} – ${_dateFmt.format(max)}';
  }

  static List<pw.TableRow> _buildTableRows(
      List<model.Transaction> sorted, double initBalance, PdfColor green, PdfColor red) {
    double balance = initBalance;
    final rows = <pw.TableRow>[];

    for (var i = 0; i < sorted.length; i++) {
      final tx = sorted[i];
      final isIncome = tx.type == TransactionType.income;
      if (isIncome) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
      final bg = i.isEven ? PdfColors.grey50 : PdfColors.white;
      final remark = tx.note?.isNotEmpty == true ? tx.note! : tx.title;

      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          _cell(_dateFmt.format(tx.date)),
          _cell(remark),
          _cell(tx.paymentMode ?? 'Cash'),
          _cell(isIncome ? _moneyFmt.format(tx.amount) : '',
              color: isIncome ? green : null),
          _cell(!isIncome ? _moneyFmt.format(tx.amount) : '',
              color: !isIncome ? red : null),
          _cell(_moneyFmt.format(balance)),
        ],
      ));
    }

    // Final balance row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell(DateFormat('d MMM yy').format(DateTime.now()), bold: true),
        _cell('Final Balance', bold: true),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(_moneyFmt.format(balance), bold: true),
      ],
    ));
    return rows;
  }

  static pw.Widget _pdfHeader(PdfColor bg, PdfColor blue,
      String bookName, String generatedOn, String byName) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(children: [
        pw.Container(
          width: 34, height: 34,
          decoration: pw.BoxDecoration(
            color: blue,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Center(
            child: pw.Text('C',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20)),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('CashBook Report',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.Text('Generated On - $generatedOn.  Generated by - $byName',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
      ]),
    );
  }

  static pw.Widget _pdfFooter(PdfColor blue) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(children: [
        pw.Container(
          width: 20, height: 20,
          decoration: pw.BoxDecoration(
            color: blue,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Center(
            child: pw.Text('C',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text('Generated by CashBook App.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ]),
    );
  }

  static pw.Widget _summaryCard(
      String label, double value, String cur, PdfColor valueColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text('${_moneyFmt.format(value)} $cur',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: valueColor)),
            ]),
      ),
    );
  }

  static pw.Widget _cell(String text,
      {PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  // ── Excel Export (matches sample CSV columns) ─────────────────────────────
  static Future<Uint8List> exportExcel({
    required Book book,
    required Business business,
    String? exportedBy,
  }) async {
    final txs    = await PbService.instance.getAllTransactions(book.id!);
    final sorted = List<model.Transaction>.from(txs.reversed); // oldest first
    final cur    = book.currency;
    final byName = exportedBy ?? business.name;

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // ── Sheet 1: Transactions ─────────────────────────────────────────────
    final sheet = excel['Transactions'];
    final headers = ['Date', 'Time', 'Remark', 'Entry by', 'Mode',
        'Cash In ($cur)', 'Cash Out ($cur)', 'Balance ($cur)'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex:
              ExcelColor.fromHexString('#1565C0'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
    }

    double balance = book.initialBalance;
    for (var r = 0; r < sorted.length; r++) {
      final tx = sorted[r];
      final isIncome = tx.type == TransactionType.income;
      if (isIncome) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
      final remark = tx.note?.isNotEmpty == true ? tx.note! : tx.title;
      final rowData = [
        _dateFmt.format(tx.date),                      // Date
        _timeFmt.format(tx.date),                       // Time
        remark,                                          // Remark
        byName,                                          // Entry by
        tx.paymentMode ?? 'Cash',                       // Mode
        isIncome  ? tx.amount : null,                   // Cash In
        !isIncome ? tx.amount : null,                   // Cash Out
        balance,                                         // Balance
      ];
      for (var c = 0; c < rowData.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = rowData[c];
        if (v == null) {
          cell.value = TextCellValue('');
        } else if (v is double) {
          cell.value = DoubleCellValue(v);
          if (c == 6 /* Cash Out */) {
            cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#C62828'));
          } else if (c == 5 /* Cash In */) {
            cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#2E7D32'));
          }
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // ── Sheet 2: Summary ─────────────────────────────────────────────────
    final summary = await PbService.instance.getSummary(book.id!);
    final sheet2 = excel['Summary'];
    final summaryRows = [
      ['Book',           book.name],
      ['Business',       business.name],
      ['Currency',       cur],
      ['Generated On',   DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())],
      ['Generated by',   byName],
      ['', ''],
      ['Total Cash In',  summary['income']  ?? 0.0],
      ['Total Cash Out', summary['expense'] ?? 0.0],
      ['Final Balance',  summary['balance'] ?? 0.0],
      ['Total Entries',  sorted.length.toDouble()],
    ];
    for (var r = 0; r < summaryRows.length; r++) {
      for (var c = 0; c < 2; c++) {
        final cell = sheet2.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        final v = summaryRows[r][c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
        if (c == 0 && v != '') {
          cell.cellStyle = CellStyle(bold: true);
        }
      }
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes!);
  }

  // ── CSV Export (matches reference CashBook CSV format) ─────────────────────
  // Spalten: Date,Time,Remark,Party,Category,Mode,Entry By,Cash In,Cash Out,Balance
  static Future<Uint8List> exportCsv({
    required Book book,
    required Business business,
    String? exportedBy,
  }) async {
    final txs    = await PbService.instance.getAllTransactions(book.id!);
    final sorted = List<model.Transaction>.from(txs.reversed); // oldest first
    final byName = exportedBy ?? business.name;

    final rows = <List<dynamic>>[
      ['Date', 'Time', 'Remark', 'Party', 'Category', 'Mode', 'Entry By', 'Cash In', 'Cash Out', 'Balance'],
    ];

    double balance = book.initialBalance;
    for (final tx in sorted) {
      final isIncome = tx.type == TransactionType.income;
      balance += isIncome ? tx.amount : -tx.amount;
      final remark = tx.note?.isNotEmpty == true ? tx.note! : tx.title;
      rows.add([
        _dateFmt.format(tx.date),
        _timeFmt.format(tx.date),
        remark,
        tx.contact ?? '',
        tx.categoryName ?? '',
        tx.paymentMode ?? 'Cash',
        byName,
        isIncome  ? tx.amount.toStringAsFixed(0) : '',
        !isIncome ? tx.amount.toStringAsFixed(0) : '',
        balance.toStringAsFixed(0),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csv));
  }
}
