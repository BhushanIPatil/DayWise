import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_service.dart';

/// Offer the address if Android cannot open a browser.
Future<void> openExternalLink(BuildContext context, String address) async {
  var opened = false;
  try {
    opened = await AdService.instance.quiet(
      () => launchUrl(Uri.parse(address), mode: LaunchMode.externalApplication),
    );
  } catch (_) {
    // Keep the URL accessible even if no browser can handle the request.
  }
  if (opened || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Open this link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The link could not be opened. Copy it into your browser and check your connection.',
          ),
          const SizedBox(height: 12),
          SelectableText(address),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: address));
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Copy link'),
        ),
      ],
    ),
  );
}
