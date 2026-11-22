// ignore_for_file: no-magic-number, avoid-late-keyword

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/group_command.dart';
import 'package:frosthaven_assistant/Resource/commands/labeled_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_event.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/status_actions.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

/// The shared builders that turn "apply this to these standees" into one
/// undoable action, with the attack-mode wording and event behavior.
void main() {
  setUpAll(() async {
    await setUpGame();
  });

  const monsterName = 'Zealot';

  late GameState gs;
  late Settings settings;
  late int startIndex;

  Monster currentMonster() =>
      gs.currentList.whereType<Monster>().firstWhere((m) => !m.isAlly);

  MonsterInstance standee(int nr) =>
      currentMonster().monsterInstances.firstWhere((i) => i.standeeNr == nr);

  FigureRef ref(int nr) => (ownerId: monsterName, figureId: standee(nr).getId());

  List<FigureRef> refs(List<int> numbers) => numbers.map(ref).toList();

  String undoLabel() => gs.commandDescriptions[gs.commandIndex.value];

  Command addCmd(Condition c, int nr) =>
      StatusActions.buildAddCondition([ref(nr)], c,
          gameState: gs, settings: settings)!;

  List<String> zealotImmunities() => currentMonster()
      .type
      .levels[currentMonster().level.value]
      .normal!
      .immunities;

  setUp(() {
    gs = getIt<GameState>();
    settings = getIt<Settings>();
    gs.clearList();
    gs.action(AddMonsterCommand(monsterName, 1, false, gameState: gs));
    for (int nr = 1; nr <= 3; nr++) {
      gs.action(AddStandeeCommand(nr, null, monsterName, MonsterType.normal,
          false,
          gameState: gs));
    }
    gs.action(AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1));
    startIndex = gs.commandIndex.value;
  });

  tearDown(() {
    while (gs.commandIndex.value > startIndex) {
      gs.undo();
    }
  });

  group('LabeledCommand', () {
    test('forwards execute, onUndo and event; describes with its label', () {
      final inner = _StubCommand();
      final c = LabeledCommand(inner, '−1 health (1)');
      expect(c.describe(), '−1 health (1)');
      c.execute();
      c.onUndo();
      expect(inner.executed, 1);
      expect(inner.undone, 1);
      expect(c.event, isA<HealthChangedEvent>());
    });
  });

  group('health and kill', () {
    test('one standee: labeled, and it carries the health event', () {
      final c =
          StatusActions.buildHealthChange(refs([1]), -1, gameState: gs)!;
      expect(c, isA<LabeledCommand>());
      expect(c.describe(), '−1 health (1)');
      expect(c.event, isA<HealthChangedEvent>());

      final before = standee(1).health.value;
      gs.action(c);
      expect(standee(1).health.value, before - 1);
      expect(undoLabel(), '−1 health (1)');
      gs.undo();
      expect(standee(1).health.value, before);
    });

    test('several standees: one group, and the group carries no event', () {
      final c =
          StatusActions.buildHealthChange(refs([1, 2]), -1, gameState: gs)!;
      expect(c, isA<GroupCommand>());
      expect(c.describe(), '−1 health (2)');
      expect(c.event, isA<NoEvent>());

      gs.action(c);
      expect(undoLabel(), '−1 health (2)');
    });

    test('healing standees that are all at max health builds nothing', () {
      expect(
          StatusActions.buildHealthChange(refs([1, 2, 3]), 1, gameState: gs),
          isNull);
    });

    test('a heal the filter cuts to one standee still fires the event', () {
      gs.action(StatusActions.buildHealthChange(refs([1]), -2, gameState: gs)!);
      // standees 2 and 3 are still at max: only 1 survives the filter
      final c =
          StatusActions.buildHealthChange(refs([1, 2, 3]), 1, gameState: gs)!;
      expect(c, isA<LabeledCommand>());
      expect(c.describe(), '+1 health (1)');
      expect(c.event, isA<HealthChangedEvent>());
    });

    test('kill: one standee labeled with an event, several grouped without',
        () {
      final one = StatusActions.buildKill(refs([1]), gameState: gs)!;
      expect(one, isA<LabeledCommand>());
      expect(one.describe(), 'Kill (1)');
      expect(one.event, isA<HealthChangedEvent>());

      final many = StatusActions.buildKill(refs([2, 3]), gameState: gs)!;
      expect(many, isA<GroupCommand>());
      expect(many.describe(), 'Kill (2)');
      expect(many.event, isA<NoEvent>());

      gs.action(many);
      expect(undoLabel(), 'Kill (2)');
      expect(
          currentMonster().monsterInstances.map((i) => i.standeeNr), [1]);
      gs.undo();
      expect(currentMonster().monsterInstances.length, 3);
    });
  });

  group('conditions', () {
    test('one standee: labeled add, and no event (the command has none)', () {
      final c = addCmd(Condition.stun, 1);
      expect(c, isA<LabeledCommand>());
      expect(c.describe(), '+stun (1)');
      expect(c.event, isA<NoEvent>());

      gs.action(c);
      expect(standee(1).conditions.value, contains(Condition.stun));
    });

    test('standees that already have the condition are skipped', () {
      gs.action(addCmd(Condition.stun, 1));
      final c = StatusActions.buildAddCondition(refs([1, 2, 3]),
          Condition.stun,
          gameState: gs, settings: settings)!;
      expect(c, isA<GroupCommand>());
      expect(c.describe(), '+stun (2)'); // standee 1 has it already
    });

    test('an immune standee is skipped; alone it builds nothing', () {
      final immunities = zealotImmunities();
      immunities.add('%stun%');
      addTearDown(() => immunities.remove('%stun%'));

      expect(StatusActions.isImmune(ref(1), Condition.stun,
          gameState: gs, settings: settings),
          isTrue);
      expect(
          StatusActions.buildAddCondition(refs([1]), Condition.stun,
              gameState: gs, settings: settings),
          isNull);
    });

    test('remove: only those who carry it, with the minus label', () {
      gs.action(addCmd(Condition.stun, 1));
      gs.action(addCmd(Condition.stun, 2));
      final c = StatusActions.buildRemoveCondition(refs([1, 2, 3]),
          Condition.stun,
          gameState: gs, settings: settings)!;
      expect(c, isA<GroupCommand>());
      expect(c.describe(), '−stun (2)'); // standee 3 never had it
      gs.action(c);
      expect(standee(1).conditions.value, isEmpty);
    });

    test('curse immunity is the same rule the deck menus use', () {
      final immunities = zealotImmunities();
      immunities.add('%curse%');
      addTearDown(() => immunities.remove('%curse%'));

      expect(StatusActions.isImmuneToCurse(ref(1),
          gameState: gs, settings: settings),
          isTrue);
      expect(
          StatusActions.buildCurseChange(refs([1]), 1,
              gameState: gs, settings: settings),
          isNull);
    });
  });

  group('chill', () {
    test('labeled for one, grouped for several', () {
      final one =
          StatusActions.buildChillChange(refs([1]), 1, gameState: gs)!;
      expect(one, isA<LabeledCommand>());
      expect(one.describe(), '+1 chill (1)');
      gs.action(one);
      expect(standee(1).chill.value, 1);
      expect(undoLabel(), '+1 chill (1)');
    });

    test('caps at twelve; past the cap nothing is built', () {
      for (int i = 0; i < StatusActions.maxChill; i++) {
        gs.action(StatusActions.buildChillChange(refs([1]), 1,
            gameState: gs)!);
      }
      expect(standee(1).chill.value, 12);
      expect(
          StatusActions.buildChillChange(refs([1]), 1, gameState: gs),
          isNull);
    });

    test('taking chill stops at none', () {
      expect(
          StatusActions.buildChillChange(refs([1, 2]), -1, gameState: gs),
          isNull);
    });
  });

  group('bless and curse', () {
    late ModifierDeck deck;

    setUp(() {
      deck = StatusActions.deckOf(ref(1),
          gameState: gs, settings: settings)!;
    });

    test('monster standees use the monster deck', () {
      expect(deck, same(gs.modifierDeck));
    });

    test('one standee: labeled with the card total, and no event', () {
      final c = StatusActions.buildBlessChange(refs([1]), 1,
          gameState: gs, settings: settings)!;
      expect(c, isA<LabeledCommand>());
      expect(c.describe(), '+1 bless'); // no (1) — the count is the total
      expect(c.event, isA<NoEvent>());

      final before = deck.getRemovable('bless').value;
      gs.action(c);
      expect(deck.getRemovable('bless').value, before + 1);
      expect(undoLabel(), '+1 bless');
    });

    test('three standees: one group, label counts all the cards', () {
      final c = StatusActions.buildBlessChange(refs([1, 2, 3]), 1,
          gameState: gs, settings: settings)!;
      expect(c, isA<GroupCommand>());
      expect(c.describe(), '+3 bless');
      gs.action(c);
      expect(deck.getRemovable('bless').value, 3);
    });

    test('a pool with one card left still gives it, labeled, no event', () {
      while (GameMethods.blessCurseLeft('bless', deck, gameState: gs) > 1) {
        gs.action(StatusActions.buildBlessChange(refs([1]), 1,
            gameState: gs, settings: settings)!);
      }
      final c = StatusActions.buildBlessChange(refs([1, 2, 3]), 1,
          gameState: gs, settings: settings)!;
      expect(c, isA<LabeledCommand>()); // two standees are skipped
      expect(c.describe(), '+1 bless');
      expect(c.event, isA<NoEvent>());

      gs.action(c);
      expect(GameMethods.blessCurseLeft('bless', deck, gameState: gs), 0);
      expect(
          StatusActions.buildBlessChange(refs([1]), 1,
              gameState: gs, settings: settings),
          isNull); // none left: no action at all
    });

    test('removing never goes below the cards actually in the deck', () {
      gs.action(StatusActions.buildBlessChange(refs([1]), 1,
          gameState: gs, settings: settings)!); // one card in
      final c = StatusActions.buildBlessChange(refs([1, 2, 3]), -1,
          gameState: gs, settings: settings)!;
      expect(c, isA<LabeledCommand>()); // only standee 1's card can come back
      expect(c.describe(), '−1 bless');
      gs.action(c);
      expect(deck.getRemovable('bless').value, 0);
    });

    test('allies draw from the allies deck', () {
      gs.action(AddMonsterCommand('Black Sludge', 1, true, gameState: gs));
      final ally =
          gs.currentList.whereType<Monster>().firstWhere((m) => m.isAlly);
      final expected =
          GameMethods.isOgGloomEdition(gameState: gs) &&
                  !gs.allyDeckInOGGloom.value
              ? gs.modifierDeck
              : gs.modifierDeckAllies;
      expect(
          StatusActions.deckOf((ownerId: ally.id, figureId: 'any'),
              gameState: gs, settings: settings),
          same(expected));
    });
  });

  group('heroes', () {
    Character hero() => gs.currentList.whereType<Character>().first;
    FigureRef heroRef() => (ownerId: hero().id, figureId: hero().id);
    ModifierDeck heroDeck() => hero().characterState.modifierDeck;

    setUp(() {
      // blessCurseLeft walks every deck: make sure the counters exist.
      for (final d in [heroDeck(), gs.modifierDeckAllies]) {
        d.getRemovable('bless');
        d.getRemovable('curse');
      }
    });

    test("a hero's cards go into their own deck", () {
      expect(
          StatusActions.deckOf(heroRef(), gameState: gs, settings: settings),
          same(heroDeck()));
    });

    test('immunity checks on a hero answer without throwing', () {
      expect(
          StatusActions.isImmune(heroRef(), Condition.stun,
              gameState: gs, settings: settings),
          isFalse);
      expect(
          StatusActions.isImmuneToCurse(heroRef(),
              gameState: gs, settings: settings),
          isFalse);
    });

    test("a hero's summon answers too: no immunities, no deck", () {
      gs.action(AddStandeeCommand(
          1,
          SummonData(1, 'Test Summon', 10, 2, 2, 0, 'test_gfx'),
          hero().id,
          MonsterType.summon,
          true,
          gameState: gs));
      final summon = (
        ownerId: hero().id,
        figureId: hero().characterState.summonList.first.getId()
      );
      expect(
          StatusActions.isImmune(summon, Condition.stun,
              gameState: gs, settings: settings),
          isFalse);
      expect(
          StatusActions.isImmuneToCurse(summon,
              gameState: gs, settings: settings),
          isFalse);
      // summon picking is not wired; the module just stays safe on them
      expect(
          StatusActions.deckOf(summon, gameState: gs, settings: settings),
          isNull);
    });

    test('impair and infect are hero-only: monsters are immune', () {
      for (final c in [Condition.impair, Condition.infect]) {
        expect(
            StatusActions.isImmune(heroRef(), c,
                gameState: gs, settings: settings),
            isFalse);
        expect(
            StatusActions.isImmune(ref(1), c,
                gameState: gs, settings: settings),
            isTrue);
      }
      expect(
          StatusActions.buildAddCondition(refs([1, 2]), Condition.impair,
              gameState: gs, settings: settings),
          isNull);
    });

    test('impair over a mixed roster commands the hero only', () {
      final c = StatusActions.buildAddCondition([heroRef(), ...refs([1, 2])],
          Condition.impair,
          gameState: gs,
          settings: settings)!;
      expect(c, isA<LabeledCommand>());
      expect(c.describe(), '+impair (1)');
      gs.action(c);
      expect(
          hero().characterState.conditions.value, contains(Condition.impair));
      expect(standee(1).conditions.value, isEmpty);
    });

    test('health, chill and kill work on a hero like on a standee', () {
      final before = hero().characterState.health.value;
      final c = StatusActions.buildHealthChange([heroRef(), ref(1)], -1,
          gameState: gs)!;
      expect(c, isA<GroupCommand>());
      expect(c.describe(), '−1 health (2)');
      gs.action(c);
      expect(hero().characterState.health.value, before - 1);

      gs.action(StatusActions.buildChillChange([heroRef()], 1, gameState: gs)!);
      expect(hero().characterState.chill.value, 1);

      gs.action(StatusActions.buildKill([heroRef()], gameState: gs)!);
      expect(undoLabel(), 'Kill (1)');
      // the existing death flow: the hero stays on the board at zero
      expect(hero().characterState.health.value, 0);
      expect(gs.currentList.any((e) => e.id == heroRef().ownerId), isTrue);
      gs.undo();
      expect(hero().characterState.health.value, before - 1);
    });

    test(
        'curse follows the pools: a full monster deck does not stop the hero',
        () {
      while (GameMethods.blessCurseLeft('curse', gs.modifierDeck,
              gameState: gs) >
          0) {
        gs.action(StatusActions.buildCurseChange(refs([1]), 1,
            gameState: gs, settings: settings)!);
      }
      final c = StatusActions.buildCurseChange([heroRef(), ref(1)], 1,
          gameState: gs, settings: settings)!;
      expect(c, isA<LabeledCommand>()); // the standee's pool is full
      expect(c.describe(), '+1 curse');
      gs.action(c);
      expect(heroDeck().getRemovable('curse').value, 1);
      expect(gs.modifierDeck.getRemovable('curse').value, 10);
    });

    test('bless counts against the shared ten, whatever the deck', () {
      while (GameMethods.blessCurseLeft('bless', gs.modifierDeck,
              gameState: gs) >
          1) {
        gs.action(StatusActions.buildBlessChange(refs([1]), 1,
            gameState: gs, settings: settings)!);
      }
      final c = StatusActions.buildBlessChange([heroRef(), ref(1)], 1,
          gameState: gs, settings: settings)!;
      expect(c, isA<LabeledCommand>()); // one card left: the hero takes it
      expect(c.describe(), '+1 bless');
      gs.action(c);
      expect(heroDeck().getRemovable('bless').value, 1);
      expect(gs.modifierDeck.getRemovable('bless').value, 9);
    });
  });
}

class _StubCommand extends Command {
  int executed = 0;
  int undone = 0;

  @override
  void execute() => executed++;

  @override
  void onUndo() => undone++;

  @override
  GameEvent get event => const HealthChangedEvent('f', 'o', -1);

  @override
  String describe() => 'stub';
}
