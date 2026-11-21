import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/theme.dart';
import 'package:frosthaven_assistant/Layout/widgets/menu_card.dart';
import 'package:frosthaven_assistant/Layout/widgets/scrollable_menu_card.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: card),
    ));
  }

  group('Swerski parchment menus', () {
    test('are on by default', () {
      expect(getIt<Settings>().parchmentMenus.value, isTrue);
    });

    test('theme gives parchment panels and the dark-red accent', () {
      final themed = withParchmentMenus(theme);
      expect(themed.cardTheme.color, kParchment);
      expect(themed.dialogTheme.backgroundColor, kParchment);
      expect(themed.drawerTheme.backgroundColor, kParchment);
      expect(themed.colorScheme.primary, kSwerskiAccent);
      expect(themed.colorScheme.secondary, kSwerskiAccent);
      // The game font is kept.
      expect(themed.textTheme.bodyMedium?.fontFamily,
          theme.textTheme.bodyMedium?.fontFamily);
    });

    testWidgets('menu cards get the brown edge', (tester) async {
      await pumpCard(tester, const MenuCard(child: SizedBox(height: 50)));
      expect(tester.widget<Card>(find.byType(Card)).shape,
          kParchmentPanelShape);
      await pumpCard(
          tester, const ScrollableMenuCard(child: SizedBox(height: 50)));
      expect(tester.widget<Card>(find.byType(Card)).shape,
          kParchmentPanelShape);
    });

    testWidgets('turned off, menu cards keep the official look',
        (tester) async {
      getIt<Settings>().parchmentMenus.value = false;
      addTearDown(() => getIt<Settings>().parchmentMenus.value = true);
      await pumpCard(tester, const MenuCard(child: SizedBox(height: 50)));
      expect(tester.widget<Card>(find.byType(Card)).shape, isNull);
      expect(getButtonTextStyle(1).color, Colors.blue);
    });

    test('text buttons use the accent instead of blue', () {
      expect(getButtonTextStyle(1).color, kSwerskiAccent);
    });
  });
}
