import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/theme.dart';
import 'privacy_text.dart';
import 'widgets.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  '${AppInfo.name} · last updated ${AppInfo.policyDate}',
                  style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5),
                ),
              ),
              for (final sec in kPolicy)
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      const SizedBox(height: 6),
                      SelectableText(sec.body, style: const TextStyle(height: 1.45, fontSize: 14)),
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
