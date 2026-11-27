import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/menus/SettingsMenu/settings_network_section.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/superfan/fans.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:frosthaven_assistant/services/translation_service.dart';

import '../../command/test_helpers.dart';
import 'super_fan_test_client.dart';

class TranslatedNames extends TranslationService {
  @override
  String t(String key) => key == 'Blinkblade' ? 'Kling' : super.t(key);
}

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late Settings settings;
  late Network network;
  late GameState gameState;
  late RecordingClient recordingClient;

  setUp(() {
    settings = getIt<Settings>();
    network = getIt<Network>();
    gameState = getIt<GameState>();
    gameState.clearList();
    settings.server.value = false;
    settings.client.value = ClientState.disconnected;
    network.hostGreeted.value = false;
    network.superFans.value = const [];
    settings.devicePlays.value = [];
    recordingClient = RecordingClient();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsNetworkSection(
              settings: settings,
              network: network,
              client: recordingClient,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('SuperNetwork rows', () {
    testWidgets('list every device while hosting', (tester) async {
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
      settings.server.value = true;
      network.superFans.value = const [
        SwerskiFan(id: 'host-1', name: 'Table laptop', plays: [], host: true),
        SwerskiFan(id: 'dev-1', name: 'Kitchen tablet', plays: ['Blinkblade']),
      ];

      await pumpSection(tester);

      expect(find.text('SuperNetwork'), findsOneWidget);
      expect(find.text('Table laptop'), findsOneWidget);
      expect(find.text('Kitchen tablet'), findsOneWidget);
      expect(find.text('host'), findsOneWidget);
      expect(find.text('The table'), findsOneWidget);
      expect(find.text('Blinkblade'), findsOneWidget);
    });

    testWidgets('hidden while neither hosting nor greeted', (tester) async {
      network.superFans.value = const [
        SwerskiFan(id: 'host-1', name: 'Table laptop', host: true),
      ];

      await pumpSection(tester);
      expect(find.text('SuperNetwork'), findsNothing);

      // Connected, but the host never greeted: still nothing to show.
      settings.client.value = ClientState.connected;
      await tester.pump();
      expect(find.text('SuperNetwork'), findsNothing);
    });

    testWidgets('shown as client of a greeted host', (tester) async {
      settings.client.value = ClientState.connected;
      network.hostGreeted.value = true;
      network.superFans.value = const [
        SwerskiFan(id: 'host-1', name: 'Table laptop', host: true),
        SwerskiFan(id: 'dev-1', name: 'Kitchen tablet'),
      ];

      await pumpSection(tester);
      expect(find.text('SuperNetwork'), findsOneWidget);
      expect(find.text('Kitchen tablet'), findsOneWidget);
    });

    testWidgets('a device without a name is the Unnamed device',
        (tester) async {
      settings.server.value = true;
      network.superFans.value = const [
        SwerskiFan(id: 'dev-1', name: ''),
      ];

      await pumpSection(tester);
      expect(find.text('Unnamed device'), findsOneWidget);
    });

    testWidgets('a character two devices play is flagged on both rows',
        (tester) async {
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
      settings.server.value = true;
      network.superFans.value = const [
        SwerskiFan(id: 'dev-1', name: 'Phone A', plays: ['Blinkblade']),
        SwerskiFan(id: 'dev-2', name: 'Phone B', plays: ['Blinkblade']),
      ];

      await pumpSection(tester);
      expect(find.text('Blinkblade (shared)'), findsNWidgets(2));
    });

    testWidgets('the greeted client sees its choice and can change it',
        (tester) async {
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
      AddCharacterCommand('Banner Spear', 'Frosthaven', null, 1).execute();
      settings.client.value = ClientState.connected;
      network.hostGreeted.value = true;
      settings.devicePlays.value = ['Blinkblade'];

      await pumpSection(tester);
      expect(find.text('You play'), findsOneWidget);
      expect(find.text('Blinkblade'), findsOneWidget);

      await tester.tap(find.text('Change'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Who do you play?'), findsOneWidget);

      // Switch to playing Banner Spear instead.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Blinkblade'));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Banner Spear'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(recordingClient.savedPlays, [
        ['Banner Spear'],
      ]);
    });

    testWidgets('change is disabled when the game has no characters',
        (tester) async {
      settings.client.value = ClientState.connected;
      network.hostGreeted.value = true;
      settings.devicePlays.value = ['Blinkblade'];

      await pumpSection(tester);
      expect(find.text('You play'), findsOneWidget);

      final button = tester.widget<TextButton>(find.ancestor(
        of: find.text('Change'),
        matching: find.byType(TextButton),
      ));
      expect(button.onPressed, isNull,
          reason: 'an empty picker whose OK wipes the stored choice must '
              'not be reachable');
    });

    testWidgets('character names go through the translation service',
        (tester) async {
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
      settings.server.value = true;
      network.superFans.value = const [
        SwerskiFan(id: 'host-1', name: 'Table laptop', host: true),
        SwerskiFan(id: 'dev-1', name: 'Kitchen tablet', plays: ['Blinkblade']),
      ];

      getIt<TranslationService>(); // materialize the lazy singleton
      getIt.unregister<TranslationService>();
      addTearDown(() {
        getIt.unregister<TranslationService>();
        getIt
            .registerLazySingleton<TranslationService>(() => TranslationService());
      });
      getIt.registerSingleton<TranslationService>(TranslatedNames());

      await pumpSection(tester);
      expect(find.text('Kling'), findsOneWidget);
      expect(find.text('Blinkblade'), findsNothing);
    });

    testWidgets('playing nothing shows the table as the choice',
        (tester) async {
      settings.client.value = ClientState.connected;
      network.hostGreeted.value = true;

      await pumpSection(tester);
      expect(find.text('You play'), findsOneWidget);
      expect(find.text('The table'), findsOneWidget);
    });

    testWidgets('the host is not offered the change row', (tester) async {
      settings.server.value = true;
      network.superFans.value = const [
        SwerskiFan(id: 'host-1', name: 'Table laptop', host: true),
      ];

      await pumpSection(tester);
      expect(find.text('You play'), findsNothing);
      expect(find.text('Change'), findsNothing);
    });
  });
}
