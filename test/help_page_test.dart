import 'package:daywise/ui/help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('help search opens backup instructions and can be cleared', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));
    final search = find.byKey(const ValueKey('help-search'));
    await tester.enterText(search, 'How do I back up my data?');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ExpansionTile, 'How do I back up my data?'),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Keep a recent copy outside this phone'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('How do I start using DayWise?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help has a usable empty-search state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));
    await tester.enterText(
      find.byKey(const ValueKey('help-search')),
      'no-such-topic-xyz',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching answers.'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
