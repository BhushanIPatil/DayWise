import 'package:daywise/core/app_info.dart';
import 'package:daywise/core/theme.dart';
import 'package:daywise/data/db.dart';
import 'package:daywise/data/models.dart';
import 'package:daywise/data/recurrence.dart';
import 'package:daywise/state/app_state.dart';
import 'package:daywise/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDb extends AppDb {
  @override
  Future<List<MoneyAccount>> accounts() async => [kDefaultAccount];
  @override
  Future<List<Category>> categories() async => [];
  @override
  Future<List<Txn>> allTxns() async => [];
  @override
  Future<List<RecurringRule>> rules() async => [];
}

void main() {
  for (final link in {
    'Help': AppInfo.helpUrl,
    'Contact us': AppInfo.supportUrl,
  }.entries) {
    testWidgets('Settings opens ${link.key} in the browser', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        _MemoryDb(),
        await SharedPreferences.getInstance(),
      );
      await state.load();
      addTearDown(state.dispose);
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final addresses = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          addresses.add((call.arguments as Map)['url'] as String);
          return true;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light, Brand.accents.first),
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text(link.key), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text(link.key));
      await tester.pumpAndSettle();
      expect(addresses, [link.value]);
      expect(find.text('Open this link'), findsNothing);
      expect(find.byKey(const ValueKey('help-search')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
