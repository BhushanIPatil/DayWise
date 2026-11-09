import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/theme.dart';
import 'external_link.dart';
import 'help_content.dart';
import 'widgets.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final questions = kHelpQuestions
        .where(
          (item) =>
              ('${item.question} ${item.answer}').toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const Text(
                'How can we help?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Read these answers offline. External links need internet.',
                style: TextStyle(color: context.cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('help-search'),
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search help',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (questions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No matching answers. Try another word or contact support below.',
                  ),
                ),
              for (final item in questions)
                GlassCard(
                  key: ValueKey(item.question),
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    key: PageStorageKey(item.question),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      item.question,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.answer,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded),
                      title: const Text('Contact support'),
                      subtitle: const Text(
                        'Open App support on our Google Play listing.',
                      ),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () =>
                          openExternalLink(context, AppInfo.playStoreUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: const Text('Terms of Use'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => openExternalLink(context, AppInfo.termsUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
