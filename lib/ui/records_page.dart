import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_sheet.dart';
import 'report_export.dart';
import 'record_search.dart';
import 'widgets.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final entries = _query.trim().isEmpty
        ? s.recordsInRange(null, null)
        : s.search(_query, limit: s.all.length);
    final groups = <String, List<Txn>>{};
    for (final t in entries) {
      (groups[dateKey(t.date)] ??= []).add(t);
    }
    final dates = groups.keys.toList();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Records',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => setState(() => _searching = true),
                ),
                const ReportExport(title: 'All records'),
              ],
            ),
          ),
          if (_searching)
            InlineRecordSearch(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              onClose: () {
                FocusScope.of(context).unfocus();
                _searchController.clear();
                setState(() {
                  _searching = false;
                  _query = '';
                });
              },
            ),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No records found',
                    subtitle: 'Add a record or try another search.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      final day = dates[index];
                      final records = groups[day]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                              child: Text(
                                fmtDayLong(records.first.date),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: context.cs.primary,
                                ),
                              ),
                            ),
                            GlassCard(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                children: [
                                  for (final t in records)
                                    ListTile(
                                      onTap: () =>
                                          showEntrySheet(context, edit: t),
                                      title: Text(
                                        t.note.isEmpty
                                            ? s.categoryOf(t).name
                                            : t.note,
                                      ),
                                      subtitle: Text(
                                        [
                                          fmtTime(t.date),
                                          if (s.selectedAccountId == null)
                                            s.accountById(t.accountId).name,
                                          if (t.note.isNotEmpty)
                                            s.categoryOf(t).name,
                                        ].join(' | '),
                                      ),
                                      trailing: Text(
                                        s.money.signed(t.signed),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: t.isIncome
                                              ? Brand.income
                                              : Brand.expense,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
