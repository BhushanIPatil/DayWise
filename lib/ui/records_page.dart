import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'report_export.dart';
import 'record_search.dart';
import 'transaction_list.dart';
import 'accounts_page.dart';
import 'report_period.dart';
import 'record_view_options.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';
  final _period = ReportPeriod();
  final _view = RecordViewOptions();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final range = _period.range(s.weekStart);
    final matches = _query.trim().isEmpty
        ? null
        : s.search(_query, limit: s.all.length).toSet();
    final entries = _view.apply(
      s
          .recordsInRange(range?.start, range?.end)
          .where((t) => matches == null || matches.contains(t)),
    );
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          AccountSwitcher(
            viewToggle: IconButton(
              tooltip: 'Search',
              onPressed: () => setState(() => _searching = true),
              icon: const Icon(Icons.search_rounded),
            ),
            actions: ReportExport(
              entries: entries,
              title: 'List',
              from: range?.start,
              to: range?.end,
              includeAccounts: true,
            ),
          ),
          ReportPeriodBar(
            period: _period,
            onChanged: () => setState(() {}),
            trailing: RecordSortButton(
              options: _view,
              onChanged: () => setState(() {}),
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
          Expanded(child: TransactionList(entries: entries)),
        ],
      ),
    );
  }
}
