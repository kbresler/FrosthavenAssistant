// ignore_for_file: no-magic-number, avoid-late-keyword

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_controller.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_bless_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_curse_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

/// Bless and curse come from fixed supplies: ten bless for the whole game, and
/// two pools of ten curses (monster curses for the monster deck alone, star
/// curses for heroes and allies).
void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gs;
  late ModifierDeck monsterDeck;
  late ModifierDeck heroDeck;

  int left(String id, ModifierDeck deck) =>
      GameMethods.blessCurseLeft(id, deck, gameState: gs);

  setUp(() {
    gs = getIt<GameState>();
    gs.clearList();
    gs.action(AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1));
    monsterDeck = gs.modifierDeck;
    heroDeck = (gs.currentList.whereType<Character>().first).characterState
        .modifierDeck;
    // make sure every deck has its counters
    for (final d in [monsterDeck, heroDeck, gs.modifierDeckAllies]) {
      d.getRemovable('bless');
      d.getRemovable('curse');
    }
  });

  group('the shared helper', () {
    test('ten bless for all decks together', () {
      final base = left('bless', monsterDeck);
      gs.action(
          ChangeBlessCommand(3, 'Blinkblade', 'Blinkblade', gameState: gs));
      expect(left('bless', monsterDeck), base - 3);
      expect(left('bless', heroDeck), base - 3);
      gs.undo();
      expect(left('bless', monsterDeck), base);
    });

    test('monster curses and star curses are separate pools', () {
      final monsterBase = left('curse', monsterDeck);
      final heroBase = left('curse', heroDeck);
      gs.action(
          ChangeCurseCommand(4, 'Blinkblade', 'Blinkblade', gameState: gs));
      expect(left('curse', heroDeck), heroBase - 4);
      expect(left('curse', monsterDeck), monsterBase); // untouched
      gs.undo();
    });

    test('allies share the heroes\' star curses', () {
      final base = left('curse', heroDeck);
      expect(left('curse', gs.modifierDeckAllies), base);
      gs.action(
          ChangeCurseCommand(2, 'Blinkblade', 'Blinkblade', gameState: gs));
      expect(left('curse', gs.modifierDeckAllies), base - 2);
      gs.undo();
    });

    test('cards about to be added count too', () {
      final base = left('bless', monsterDeck);
      expect(
          GameMethods.blessCurseLeft('bless', monsterDeck,
              pending: {monsterDeck: 2}, gameState: gs),
          base - 2);
    });
  });

  group('attack mode uses the same pools', () {
    late AttackModeController attack;
    late int startIndex;

    setUp(() {
      startIndex = gs.commandIndex.value;
      gs.action(AddMonsterCommand('Zealot', 1, false, gameState: gs));
      for (int nr = 1; nr <= 3; nr++) {
        gs.action(AddStandeeCommand(nr, null, 'Zealot', MonsterType.normal, false,
            gameState: gs));
      }
      attack = AttackModeController(gameState: gs);
      attack.startSelecting();
      final zealot = gs.currentList.whereType<Monster>().first;
      for (final i in zealot.monsterInstances) {
        attack.togglePick(i, zealot.id);
      }
      attack.startAttack();
    });

    tearDown(() {
      attack.dispose();
      while (gs.commandIndex.value > startIndex) {
        gs.undo();
      }
    });

    test('a hero\'s bless cards are not there to give to monsters', () {
      final base = left('bless', monsterDeck);
      gs.action(
          ChangeBlessCommand(3, 'Blinkblade', 'Blinkblade', gameState: gs));
      final monsterBefore = monsterDeck.getRemovable('bless').value;

      for (int i = 0; i < 6; i++) {
        attack.changeBless(1); // one card per standee, three at a time
      }
      expect(left('bless', monsterDeck), 0);
      expect(monsterDeck.getRemovable('bless').value,
          monsterBefore + (base - 3));

      // all gone: pressing + again does nothing, not even an Undo step
      final index = gs.commandIndex.value;
      attack.changeBless(1);
      expect(gs.commandIndex.value, index);

      // the hero uses one, it goes back, and exactly one more can be given
      gs.action(
          ChangeBlessCommand(-1, 'Blinkblade', 'Blinkblade', gameState: gs));
      final now = monsterDeck.getRemovable('bless').value;
      attack.changeBless(1); // three standees, one card left
      expect(monsterDeck.getRemovable('bless').value, now + 1);
    });

    test('a monster immune to curse gets no curse card, but can be blessed',
        () {
      final zealot = gs.currentList.whereType<Monster>().first;
      final immunities =
          zealot.type.levels[zealot.level.value].normal!.immunities;
      immunities.add('%curse%');
      addTearDown(() => immunities.remove('%curse%'));

      final curses = monsterDeck.getRemovable('curse').value;
      final blessings = monsterDeck.getRemovable('bless').value;
      final index = gs.commandIndex.value;
      attack.changeCurse(1);
      expect(monsterDeck.getRemovable('curse').value, curses);
      expect(gs.commandIndex.value, index); // nothing happened at all

      attack.changeBless(1);
      expect(monsterDeck.getRemovable('bless').value, blessings + 3);
    });

    test('a hero\'s curses do not use up the monster curses', () {
      final base = left('curse', monsterDeck);
      gs.action(
          ChangeCurseCommand(4, 'Blinkblade', 'Blinkblade', gameState: gs));
      expect(left('curse', monsterDeck), base);
      while (left('curse', monsterDeck) > 0) {
        attack.changeCurse(1);
      }
      expect(left('curse', monsterDeck), 0);
    });
  });
}
