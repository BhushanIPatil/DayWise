import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../state/app_state.dart';
import 'backup.dart';
import 'models.dart';

// Table rows cannot split across PDF pages. Continue long notes in additional
// rows, preserving every character without repeating the financial values.
Iterable<String> _reportNoteParts(String note) sync* {
  if (note.isEmpty) {
    yield '';
    return;
  }
  final buffer = StringBuffer();
  var characters = 0;
  var lines = 0;
  for (final rune in note.runes) {
    buffer.writeCharCode(rune);
    characters++;
    if (rune == 10 || rune == 13) lines++;
    if (characters >= 600 || lines >= 8) {
      yield buffer.toString();
      buffer.clear();
      characters = 0;
      lines = 0;
    }
  }
  if (buffer.isNotEmpty) yield buffer.toString();
}

Future<Uint8List> buildReportPdf(
  AppState state,
  List<Txn> entries,
  String title, {
  DateTime? from,
  DateTime? to,
  DateTime? generatedAt,
}) async {
  final generated = generatedAt ?? DateTime.now();
  final earliest = entries.isEmpty
      ? null
      : entries.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
  final latest = entries.isEmpty
      ? null
      : entries.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
  final rangeStart = from ?? earliest ?? to ?? generated;
  final rangeEnd = to ?? latest ?? from ?? generated;
  final rangeLabel =
      'Data from ${fmtDayLong(rangeStart)} to ${fmtDayLong(rangeEnd)}';
  final generatedLabel =
      'PDF generated at ${fmtDayLong(generated)} ${fmtTime(generated)}';
  const incomeColor = PdfColor.fromInt(0xFF087F5B);
  const expenseColor = PdfColor.fromInt(0xFFC92A2A);
  PdfColor balanceColor(BigInt value) => value > BigInt.zero
      ? incomeColor
      : value < BigInt.zero
      ? expenseColor
      : PdfColors.grey800;
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans_400Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans_700Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: 'DayWise Calendar - $title',
    subject: '$rangeLabel | $generatedLabel',
  );
  final income = entries
      .where((t) => t.isIncome)
      .fold<BigInt>(BigInt.zero, (n, t) => n + t.amountMinor);
  final expense = entries
      .where((t) => !t.isIncome)
      .fold<BigInt>(BigInt.zero, (n, t) => n + t.amountMinor);
  final account = state.selectedAccountId == null
      ? 'All accounts'
      : state.accountById(state.selectedAccountId!).name;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages:
          10 +
          entries.fold<int>(
            0,
            (count, t) => count + _reportNoteParts(t.note).length,
          ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (_) => [
        pw.Center(
          child: pw.Text(
            'DayWise Calendar - $title',
            style: const pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text(rangeLabel)),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            generatedLabel,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('$account | ${state.currencyCode} | ${entries.length} records'),
        pw.SizedBox(height: 8),
        pw.Text(
          'Income: ${state.currencyCode} ${minorToPlain(income)}',
          style: const pw.TextStyle(
            color: incomeColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Expense: ${state.currencyCode} ${minorToPlain(expense)}',
          style: const pw.TextStyle(
            color: expenseColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Net: ${state.currencyCode} ${minorToPlain(income - expense)}',
          style: pw.TextStyle(
            color: balanceColor(income - expense),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        if (entries.isEmpty)
          pw.Text('No records for this period.')
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Time',
              'Note',
              'Account',
              'Type',
              'Amount (${state.currencyCode})',
              'Balance (${state.currencyCode})',
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(2.8),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(1.3),
              6: const pw.FlexColumnWidth(1.3),
            },
            cellAlignments: {
              5: pw.Alignment.topRight,
              6: pw.Alignment.topRight,
            },
            data: [
              for (final t in entries)
                for (final part in _reportNoteParts(t.note).indexed)
                  if (part.$1 > 0)
                    ['', '', part.$2, '', '', '', '']
                  else
                    [
                      fmtDayLong(t.date),
                      fmtTime(t.date),
                      part.$2,
                      state.accountById(t.accountId).name,
                      pw.Text(
                        t.isIncome ? 'Income' : 'Expense',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: t.isIncome ? incomeColor : expenseColor,
                        ),
                      ),
                      pw.Text(
                        minorToPlain(t.amountMinor),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: t.isIncome ? incomeColor : expenseColor,
                        ),
                      ),
                      pw.Text(
                        minorToPlain(state.balanceAfter(t)),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: balanceColor(state.balanceAfter(t)),
                        ),
                      ),
                    ],
            ],
          ),
      ],
    ),
  );
  return doc.save();
}
