// ignore_for_file: no-magic-number

import 'dart:math';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/heart_attack.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  HeartAttackReply? pick(
    List<HeartAttackSpeaker> candidates, {
    String victim = 'Blinkblade',
    int count = 1,
    int seed = 0,
  }) {
    return pickHeartAttackReply(
      candidates: candidates,
      victimName: victim,
      victimCount: count,
      l10n: l10n,
      random: Random(seed),
    );
  }

  group('pickHeartAttackReply', () {
    test('nobody to speak means no reply', () {
      expect(pick([]), isNull);
    });

    test('the speaker is always one of the candidates', () {
      const candidates = [
        HeartAttackSpeaker('Hatchet', 0),
        HeartAttackSpeaker('Banner Spear', 2),
      ];
      for (int seed = 0; seed < 20; seed++) {
        expect(const {'Hatchet', 'Banner Spear'},
            contains(pick(candidates, seed: seed)!.speakerName));
      }
    });

    test('the same seed picks the same speaker', () {
      const candidates = [
        HeartAttackSpeaker('Hatchet', 0),
        HeartAttackSpeaker('Banner Spear', 2),
        HeartAttackSpeaker('Serpent', 1),
      ];
      for (int seed = 0; seed < 10; seed++) {
        expect(pick(candidates, seed: seed)!.speakerName,
            pick(candidates, seed: seed)!.speakerName);
      }
    });

    test('different seeds get different speakers', () {
      const candidates = [
        HeartAttackSpeaker('Hatchet', 0),
        HeartAttackSpeaker('Banner Spear', 0),
      ];
      final spoken = <String>{};
      for (int seed = 0; seed < 20; seed++) {
        spoken.add(pick(candidates, seed: seed)!.speakerName);
      }
      expect(spoken, {'Hatchet', 'Banner Spear'});
    });

    test('the first heart attack draws any first line', () {
      const candidates = [
        HeartAttackSpeaker('Hatchet', 0),
        HeartAttackSpeaker('Serpent', 3),
      ];
      final pool = {
        l10n.heartAttackFirstNoted('Blinkblade'),
        l10n.heartAttackFirstScenario('Blinkblade'),
        l10n.heartAttackFirstBoard('Blinkblade'),
      };
      final spoken = <String>{};
      for (int seed = 0; seed < 50; seed++) {
        final reply = pick(candidates, seed: seed)!;
        expect(pool, contains(reply.line));
        spoken.add(reply.line);
      }
      expect(spoken, pool);
    });

    test('a speaker with none draws any repeat line', () {
      const candidates = [HeartAttackSpeaker('Hatchet', 0)];
      final pool = {
        l10n.heartAttackRepeatAgain('Blinkblade', 3),
        l10n.heartAttackRepeatAnyway('Blinkblade', 3),
        l10n.heartAttackRepeatWriteDown('Blinkblade', 3),
        l10n.heartAttackRepeatRespectable('Blinkblade', 3),
        l10n.heartAttackRepeatCarryOn('Blinkblade', 3),
      };
      final spoken = <String>{};
      for (int seed = 0; seed < 50; seed++) {
        final reply = pick(candidates, count: 3, seed: seed)!;
        expect(pool, contains(reply.line));
        spoken.add(reply.line);
      }
      expect(spoken, pool);
    });

    test('equal counts get the tied line', () {
      final reply = pick(const [HeartAttackSpeaker('Hatchet', 2)], count: 2)!;
      expect(reply.line, l10n.heartAttackTied('Blinkblade', 2));
    });

    test('a victim leading the table draws a scorecard line', () {
      final lead = l10n.heartAttackLead('Blinkblade', 3);
      final pool = [
        lead,
        l10n.heartAttackOnlyOn('Blinkblade', 3, 1),
        l10n.heartAttackNotARace('Blinkblade', 3, 1),
        l10n.heartAttackNotWorried('Blinkblade', 3, 1),
      ];
      final spoken = <String>{};
      for (int seed = 0; seed < 50; seed++) {
        final reply =
            pick(const [HeartAttackSpeaker('Hatchet', 1)], count: 3, seed: seed)!;
        expect(pool, contains(reply.line));
        spoken.add(reply.line);
      }
      expect(spoken, contains(lead));
    });

    test('a speaker ahead never gets the lead or only-on line', () {
      final allowed = [
        l10n.heartAttackNotARace('Blinkblade', 2, 5),
        l10n.heartAttackNotWorried('Blinkblade', 2, 5),
        l10n.heartAttackJustSaying('Blinkblade', 2, 5),
        l10n.heartAttackComfortable('Blinkblade', 2, 5),
      ];
      for (int seed = 0; seed < 50; seed++) {
        final reply =
            pick(const [HeartAttackSpeaker('Hatchet', 5)], count: 2, seed: seed)!;
        expect(allowed, contains(reply.line));
      }
    });

    test('the lead line waits for a real lead over the whole table', () {
      final lead = l10n.heartAttackLead('Blinkblade', 3);
      const candidates = [
        HeartAttackSpeaker('Hatchet', 1),
        HeartAttackSpeaker('Serpent', 5),
      ];
      for (int seed = 0; seed < 50; seed++) {
        final reply = pick(candidates, count: 3, seed: seed)!;
        expect(reply.line, isNot(lead));
      }
    });
  });

  group('heartAttackRecoveringLine', () {
    test('one name is used as-is', () {
      expect(heartAttackRecoveringLine(['Hatchet'], l10n),
          l10n.heartAttackRecovering('Hatchet'));
    });

    test('two names are joined with and, in the plural', () {
      expect(heartAttackRecoveringLine(['Hatchet', 'Serpent'], l10n),
          l10n.heartAttackRecoveringPlural('Hatchet and Serpent'));
    });

    test('three names get a comma list, in the plural', () {
      expect(
          heartAttackRecoveringLine(['Hatchet', 'Serpent', 'Blinkblade'], l10n),
          l10n.heartAttackRecoveringPlural('Hatchet, Serpent and Blinkblade'));
    });
  });
}
