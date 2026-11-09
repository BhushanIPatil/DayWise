import 'package:daywise/core/app_info.dart';
import 'package:daywise/ui/external_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final browserAvailable in [true, false]) {
    testWidgets('terms link handles browser availability: $browserAvailable', (
      tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final addresses = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          addresses.add((call.arguments as Map)['url'] as String);
          return browserAvailable;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openExternalLink(context, AppInfo.termsUrl),
                child: const Text('Terms'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Terms'));
      await tester.pumpAndSettle();
      expect(addresses, [AppInfo.termsUrl]);
      if (browserAvailable) {
        expect(find.text('Open this link'), findsNothing);
      } else {
        expect(find.text('Open this link'), findsOneWidget);
        expect(find.text(AppInfo.termsUrl), findsOneWidget);
        expect(find.text('Copy link'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Open this link'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
