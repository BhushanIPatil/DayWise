import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/backup.dart';
import '../data/backup_service.dart';
import '../data/report.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Shared export action; its range and account match the visible report.
class ReportExport extends StatefulWidget {
  const ReportExport({super.key, required this.title, this.from, this.to});
  final String title;
  final DateTime? from;
  final DateTime? to;

  @override
  State<ReportExport> createState() => _ReportExportState();
}

class _ReportExportState extends State<ReportExport> {
  bool _busy = false;

  Future<void> _export(String action) async {
    final s = AppScope.read(context);
    final entries = s.recordsInRange(widget.from, widget.to);
    final title = widget.title;
    setState(() => _busy = true);
    try {
      final pdf = action.endsWith('pdf');
      final bytes = pdf
          ? await buildReportPdf(s, entries, title)
          : Uint8List.fromList(
              utf8.encode(
                encodeCsv(
                  entries,
                  (id) => s.categoryById(id).name,
                  accountName: (id) => s.accountById(id).name,
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
    tooltip: _busy ? 'Exporting…' : 'Export PDF or CSV',
    enabled: !_busy,
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.file_download_outlined),
    onSelected: _export,
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'save-pdf', child: Text('Save PDF')),
      PopupMenuItem(value: 'share-pdf', child: Text('Share PDF')),
      PopupMenuItem(value: 'save-csv', child: Text('Save CSV')),
      PopupMenuItem(value: 'share-csv', child: Text('Share CSV')),
    ],
  );
}
