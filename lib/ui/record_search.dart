import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'entry_sheet.dart';
import 'widgets.dart';
import 'record_view_options.dart';

class InlineRecordSearch extends StatelessWidget {
  const InlineRecordSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: TextField(
      key: const ValueKey('record-search'),
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Search records',
        hintText: 'Search records',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Close search',
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ),
    ),
  );
}

class RecordSearchResults extends StatelessWidget {
  const RecordSearchResults({
    super.key,
    required this.query,
    this.from,
    this.to,
    this.options,
  });
  final String query;
  final DateTime? from;
  final DateTime? to;
  final RecordViewOptions? options;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final inRange = s.recordsInRange(from, to).toSet();
    final results = (options ?? RecordViewOptions()).apply(
      s.search(query, limit: s.all.length).where((t) => inRange.contains(t)),
    );
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: results.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matches',
              ),
            )
          : ListView.builder(
              key: const PageStorageKey('record-search-results'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: results.length,
              itemBuilder: (context, i) => EntryTile(
                txn: results[i],
                showDate: true,
                onTap: () => showEntrySheet(context, edit: results[i]),
              ),
            ),
    );
  }
}
