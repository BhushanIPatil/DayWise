import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_sheet.dart';
import 'widgets.dart';

/// Search notes, category names and amounts across all time.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final List<Txn> results = s.search(_q);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctl,
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Search notes, categories, amounts',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _ctl.clear();
                      setState(() => _q = '');
                    },
                  ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          if (_q.trim().isEmpty)
            const Center(
              child: EmptyState(
                icon: Icons.manage_search_rounded,
                title: 'Find any entry',
                subtitle: 'Type a word from a note, a category name or an amount.',
              ),
            )
          else if (results.isEmpty)
            const Center(child: EmptyState(icon: Icons.search_off_rounded, title: 'No matches'))
          else
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: results.length,
              itemBuilder: (context, i) => EntryTile(
                txn: results[i],
                showDate: true,
                onTap: () => showEntrySheet(context, edit: results[i]),
              ),
            ),
        ],
      ),
    );
  }
}
