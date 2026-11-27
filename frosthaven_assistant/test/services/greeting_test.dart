// ignore_for_file: no-magic-number, avoid-non-null-assertion

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/services/network/superfan/greeting.dart';

void main() {
  group('encode', () {
    test('carries the Swerski prefix, token and version', () {
      final message = SwerskiGreeting.encode(id: 'dev-1');
      expect(message, startsWith('swerski:Da Bears! superfan:1 '));
    });

    test('ack is the bare prefix, token and version', () {
      expect(SwerskiGreeting.encodeAck(), equals('swerski:Da Bears! superfan:1'));
    });

    test('asking only appears when set', () {
      expect(
        SwerskiGreeting.encode(id: 'dev-1', asking: true),
        contains('"asking":true'),
      );
      expect(SwerskiGreeting.encode(id: 'dev-1'), isNot(contains('asking')));
    });
  });

  group('round trip', () {
    test('id, name and plays come back unchanged', () {
      final message = SwerskiGreeting.encode(
        id: 'dev-1',
        name: 'Kitchen tablet',
        plays: const ['blinkblade@1', 'geminate@2'],
      );
      final parsed = SwerskiGreeting.parse(message)!;
      expect(parsed.id, equals('dev-1'));
      expect(parsed.name, equals('Kitchen tablet'));
      expect(parsed.plays, equals(['blinkblade@1', 'geminate@2']));
    });

    test('empty name and empty plays survive', () {
      final parsed = SwerskiGreeting.parse(
        SwerskiGreeting.encode(id: 'dev-2'),
      )!;
      expect(parsed.id, equals('dev-2'));
      expect(parsed.name, isEmpty);
      expect(parsed.plays, isEmpty);
    });

    test('asking comes back, and absence means false', () {
      final asking = SwerskiGreeting.parse(
        SwerskiGreeting.encode(id: 'dev-1', asking: true),
      )!;
      expect(asking.asking, isTrue);
      final plain = SwerskiGreeting.parse(
        SwerskiGreeting.encode(id: 'dev-1'),
      )!;
      expect(plain.asking, isFalse);
    });
  });

  group('framing text', () {
    test('is removed from the name when sending', () {
      final message = SwerskiGreeting.encode(
        id: 'dev-1',
        name: 'evil[EOM]S3nD:name',
      );
      expect(message, isNot(contains('[EOM]S3nD:')));
      expect(SwerskiGreeting.parse(message)!.name, equals('evilname'));
    });

    test('is removed from a play id when sending', () {
      final message = SwerskiGreeting.encode(
        id: 'dev-1',
        plays: const ['S3nD:blinkblade@1[EOM]'],
      );
      expect(SwerskiGreeting.parse(message)!.plays, equals(['blinkblade@1']));
    });

    test('is removed when reading a message from another device', () {
      const message =
          'swerski:Da Bears! superfan:1 {"id":"dev-1","name":"a[EOM]b",'
          '"plays":["S3nD:c"]}';
      final parsed = SwerskiGreeting.parse(message)!;
      expect(parsed.name, equals('ab'));
      expect(parsed.plays, equals(['c']));
    });

    test('nested framing text cannot smuggle a marker back in', () {
      // Removing the inner marker must not leave a whole marker behind.
      final message = SwerskiGreeting.encode(id: 'dev-1', name: '[E[EOM]OM]');
      expect(message, isNot(contains('[EOM]')));
      expect(message, isNot(contains('S3nD:')));
      expect(SwerskiGreeting.parse(message)!.name, isEmpty);

      final smuggled = SwerskiGreeting.encode(id: 'dev-1', name: 'S3n[EOM]D:');
      expect(smuggled, isNot(contains('S3nD:')));
      expect(SwerskiGreeting.parse(smuggled)!.name, isEmpty);
    });

    test('nested framing text is removed when reading too', () {
      const message = 'swerski:Da Bears! superfan:1 '
          '{"id":"dev-1","name":"[E[EOM]OM]","plays":["S3n[EOM]D:x"]}';
      final parsed = SwerskiGreeting.parse(message)!;
      expect(parsed.name, isEmpty);
      expect(parsed.plays, equals(['x']));
    });
  });

  group('limits', () {
    test('truncating does not split an emoji', () {
      // The emoji is two UTF-16 units and straddles the 30-character limit.
      final message =
          SwerskiGreeting.encode(id: 'dev-1', name: '${'a' * 29}\u{1F600}');
      expect(SwerskiGreeting.parse(message)!.name, equals('a' * 29));
    });

    test('name is truncated to 30 characters when sending', () {
      final parsed = SwerskiGreeting.parse(
        SwerskiGreeting.encode(id: 'dev-1', name: 'n' * 40),
      )!;
      expect(parsed.name.length, equals(30));
    });

    test('play ids are truncated to 40 characters when sending', () {
      final parsed = SwerskiGreeting.parse(
        SwerskiGreeting.encode(id: 'dev-1', plays: ['p' * 50]),
      )!;
      expect(parsed.plays.single.length, equals(40));
    });

    test('only the first 4 plays are kept when sending', () {
      final parsed = SwerskiGreeting.parse(
        SwerskiGreeting.encode(
          id: 'dev-1',
          plays: List.generate(6, (i) => 'hero$i'),
        ),
      )!;
      expect(parsed.plays.length, equals(4));
      expect(parsed.plays.first, equals('hero0'));
    });

    test('the id is cleaned and capped like the other fields', () {
      final message = SwerskiGreeting.encode(id: 'dev[EOM]-1');
      expect(message, isNot(contains('[EOM]')));
      expect(SwerskiGreeting.parse(message)!.id, equals('dev-1'));

      final long = SwerskiGreeting.parse(
        SwerskiGreeting.encode(id: 'i' * 70),
      )!;
      expect(long.id.length, equals(64));
    });

    test('a message over the limits is ignored', () {
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"dev-1","name":"${'n' * 31}",'
          '"plays":[]}',
        ),
        isNull,
      );
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"dev-1","name":"",'
          '"plays":["a","b","c","d","e"]}',
        ),
        isNull,
      );
    });
  });

  group('ignored messages', () {
    test('the ack is not a greeting', () {
      expect(SwerskiGreeting.parse(SwerskiGreeting.encodeAck()), isNull);
    });

    test('another version is ignored', () {
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:2 {"id":"dev-1","name":"","plays":[]}',
        ),
        isNull,
      );
    });

    test('another token is ignored', () {
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bulls! superfan:1 {"id":"dev-1"}',
        ),
        isNull,
      );
    });

    test('a non-Swerski message is ignored', () {
      expect(SwerskiGreeting.parse('init protocolVersion:1'), isNull);
      expect(SwerskiGreeting.parse('swerski:Da Bears! superfan:1 {}'), isNull);
    });

    test('bad JSON is ignored', () {
      expect(
        SwerskiGreeting.parse('swerski:Da Bears! superfan:1 {not json}'),
        isNull,
      );
      expect(SwerskiGreeting.parse('swerski:Da Bears! superfan:1'), isNull);
      expect(SwerskiGreeting.parse('swerski:Da Bears! superfan:1 [1,2]'), isNull);
    });

    test('a missing, empty or non-string id is ignored', () {
      for (final body in [
        '{"name":"","plays":[]}',
        '{"id":"","name":"","plays":[]}',
        '{"id":5,"name":"","plays":[]}',
      ]) {
        expect(
          SwerskiGreeting.parse('swerski:Da Bears! superfan:1 $body'),
          isNull,
          reason: 'body: $body',
        );
      }
    });

    test('an id that cleans to empty, or is too long, is ignored', () {
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"[EOM]","name":"","plays":[]}',
        ),
        isNull,
      );
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"${'i' * 65}",'
          '"name":"","plays":[]}',
        ),
        isNull,
      );
    });

    test('a non-bool asking is ignored', () {
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"d","asking":"yes"}',
        ),
        isNull,
      );
    });

    test('a non-string name or a non-list plays is ignored', () {
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"d","name":5,"plays":[]}',
        ),
        isNull,
      );
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"d","name":"","plays":"x"}',
        ),
        isNull,
      );
      expect(
        SwerskiGreeting.parse(
          'swerski:Da Bears! superfan:1 {"id":"d","name":"","plays":[5]}',
        ),
        isNull,
      );
    });
  });

  group('recognising Swerski traffic', () {
    test('both the greeting and the ack are Swerski messages', () {
      expect(SwerskiGreeting.isSwerskiMessage(SwerskiGreeting.encode(id: 'd')),
          isTrue);
      expect(SwerskiGreeting.isSwerskiMessage(SwerskiGreeting.encodeAck()),
          isTrue);
    });

    test('game traffic is not a Swerski message', () {
      expect(SwerskiGreeting.isSwerskiMessage('init protocolVersion:1'), isFalse);
      expect(SwerskiGreeting.isSwerskiMessage('{"i":0}'), isFalse);
      expect(SwerskiGreeting.isSwerskiMessage('swears:hello'), isFalse);
    });

    test('only the ack is an ack', () {
      expect(SwerskiGreeting.isAck(SwerskiGreeting.encodeAck()), isTrue);
      expect(SwerskiGreeting.isAck(SwerskiGreeting.encode(id: 'd')), isFalse);
      expect(SwerskiGreeting.isAck('swears:hello'), isFalse);
    });
  });
}
