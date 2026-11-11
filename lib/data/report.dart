import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../state/app_state.dart';
import 'backup.dart';
import 'models.dart';

Future<Uint8List> buildReportPdf(
  AppState state,
  List<Txn> entries,
  String title,
) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans_400Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans_700Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final income = entries
      .where((t) => t.isIncome)
      .fold<int>(0, (n, t) => n + t.amountMinor);
  final expense = entries
      .where((t) => !t.isIncome)
      .fold<int>(0, (n, t) => n + t.amountMinor);
  final account = state.selectedAccountId == null
      ? 'All accounts'
      : state.accountById(state.selectedAccountId!).name;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 10 + entries.length,
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (_) => [
        pw.Text(
          'DayWise - $title',
          style: const pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('$account | ${state.currencyCode} | ${entries.length} records'),
        pw.Text(
          'Income: ${minorToPlain(income)}   Expenses: ${minorToPlain(expense)}   Net: ${minorToPlain(income - expense)}',
        ),
        pw.SizedBox(height: 12),
        if (entries.isEmpty)
          pw.Text('No records for this period.')
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Time',
              'Account',
              'Type',
              'Category',
              'Amount (${state.currencyCode})',
              'Note',
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            columnWidths: {6: const pw.FlexColumnWidth(2)},
            data: [
              for (final t in entries)
                [
                  dateKey(t.date),
                  '${two(t.date.hour)}:${two(t.date.minute)}',
                  state.accountById(t.accountId).name,
                  t.isIncome ? 'Income' : 'Expense',
                  state.categoryOf(t).name,
                  minorToPlain(t.amountMinor),
                  t.note,
                ],
            ],
          ),
      ],
    ),
  );
  return doc.save();
}
