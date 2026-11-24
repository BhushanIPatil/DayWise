import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/backup.dart';
import '../data/backup_service.dart';
import '../data/report.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';
import 'accounts_page.dart';

/// Shared export action; its range and account match the visible report.
class ReportExport extends StatefulWidget {
  const ReportExport({
    super.key,
    required this.title,
    this.from,
    this.to,
    this.includeAccounts = false,
    this.entries,
  });
  final String title;
  final bool includeAccounts;
  final DateTime? from;
  final DateTime? to;
  final List<Txn>? entries;

  @override
  State<ReportExport> createState() => _ReportExportState();
}

class _ReportExportState extends State<ReportExport> {
  bool _busy = false;

  Future<void> _export(String action) async {
    if (action == 'accounts') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AccountsPage()));
      return;
    }
    final s = AppScope.read(context);
    final entries = widget.entries ?? s.recordsInRange(widget.from, widget.to);
    final title = widget.title;
    setState(() => _busy = true);
    try {
      final pdf = action.endsWith('pdf');
      final bytes = pdf
          ? await buildReportPdf(
              s,
              entries,
              title,
              from: widget.from,
              to: widget.to,
            )
          : Uint8List.fromList(
              utf8.encode(
                encodeCsv(
                  entries,
                  accountName: (id) => s.accountById(id).name,
                  balanceAfter: s.balanceAfter,
                ),
              ),
            );
      final name =
          'DayWise-${title.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '-')}-${fmtStamp(DateTime.now())}.${pdf ? 'pdf' : 'csv'}';
      final mime = pdf ? 'application/pdf' : 'text/csv';
      if (action.startsWith('save')) {
        final saved = await BackupService.saveBytes(name, bytes, mime);
        if (saved && mounted) showSnack(context, 'Export saved.');
      } else {
        await BackupService.shareBytes(name, bytes, mime);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not export. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    padding: const EdgeInsets.all(4),
    constraints: const BoxConstraints(minWidth: 36, maxWidth: 300),
    tooltip: _busy ? 'Exporting…' : 'More options',
    enabled: !_busy,
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.more_vert_rounded),
    onSelected: _export,
    itemBuilder: (_) => [
      if (widget.includeAccounts)
        const PopupMenuItem(value: 'accounts', child: Text('Manage accounts')),
      const PopupMenuItem(value: 'save-pdf', child: Text('Save PDF')),
      const PopupMenuItem(value: 'share-pdf', child: Text('Share PDF')),
      const PopupMenuItem(value: 'save-csv', child: Text('Save CSV')),
      const PopupMenuItem(value: 'share-csv', child: Text('Share CSV')),
    ],
  );
}
