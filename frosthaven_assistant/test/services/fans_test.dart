// ignore_for_file: no-magic-number, avoid-non-null-assertion

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/services/network/superfan/fans.dart';
import 'package:frosthaven_assistant/services/network/superfan/greeting.dart';

// The Swerski wire prefix, taken from the greeting rather than retyped, so the
// spelling can never drift from what the host actually sends.
final prefix = SwerskiGreeting.encode(id: 'x').substring(0, 8);

void main() {
  group('encode', () {
    test('the fans list carries the Swerski prefix and token', () {
      final message = SwerskiFan.encodeFans([
        const SwerskiFan(id: 'dev-1', host: true),
      ]);
      expect(
        message,
        startsWith('${prefix}fans {"fans":[{"id":"dev-1"'),
      );
    });

    test('joined carries its own token', () {
      final message =
          SwerskiFan.encodeJoined(const SwerskiFan(id: 'dev-1', name: 'Phone'));
      expect(message, startsWith('${prefix}joined {"id":"dev-1"'));
    });
  });

  group('round trip', () {
    test('id, name, plays and host come back unchanged', () {
      final message = SwerskiFan.encodeFans(const [
        SwerskiFan(
          id: 'dev-1',
          name: 'Kitchen tablet',
          plays: ['blinkblade@1', 'geminate@2'],
          host: true,
        ),
        SwerskiFan(id: 'dev-2'),
      ]);
      final parsed = SwerskiFan.parseFans(message)!;
      expect(parsed.length, equals(2));
      expect(parsed.first.id, equals('dev-1'));
      expect(parsed.first.name, equals('Kitchen tablet'));
      expect(parsed.first.plays, equals(['blinkblade@1', 'geminate@2']));
      expect(parsed.first.host, isTrue);
      expect(parsed.last.host, isFalse);
    });

    test('an empty list survives', () {
      expect(SwerskiFan.parseFans(SwerskiFan.encodeFans(const [])), isEmpty);
    });

    test('joined round trips id, name and plays', () {
      const fan = SwerskiFan(
        id: 'dev-9',
        name: 'Hatchet',
        plays: ['blinkblade@1'],
        host: true,
      );
      final parsed = SwerskiFan.parseJoined(SwerskiFan.encodeJoined(fan))!;
      expect(parsed.id, equals('dev-9'));
      expect(parsed.name, equals('Hatchet'));
      expect(parsed.plays, equals(['blinkblade@1']));
      expect(parsed.host, isFalse);
    });
  });

  group('framing text', () {
    test('is removed from a name when sending', () {
      final message = SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'dev-1', name: 'evil[EOM]S3nD:name'),
      ]);
      expect(message, isNot(contains('[EOM]S3nD:')));
      expect(SwerskiFan.parseFans(message)!.single.name, equals('evilname'));
    });

    test('nested framing text cannot smuggle a marker back in', () {
      final message = SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'dev-1', name: '[E[EOM]OM]'),
      ]);
      expect(message, isNot(contains('[EOM]')));
      expect(message, isNot(contains('S3nD:')));
      expect(SwerskiFan.parseFans(message)!.single.name, isEmpty);
    });

    test('is removed when reading a message from another device', () {
      final parsed = SwerskiFan.parseJoined(
        '${prefix}joined {"id":"dev-1","name":"a[EOM]b","plays":["S3nD:c"]}',
      )!;
      expect(parsed.name, equals('ab'));
      expect(parsed.plays, equals(['c']));
    });
  });

  group('limits', () {
    test('name is truncated to 30 characters when sending', () {
      final message = SwerskiFan.encodeFans([
        SwerskiFan(id: 'dev-1', name: 'n' * 40),
      ]);
      expect(SwerskiFan.parseFans(message)!.single.name.length, equals(30));
    });

    test('truncating does not split an emoji', () {
      final message = SwerskiFan.encodeJoined(
        SwerskiFan(id: 'dev-1', name: '${'a' * 29}😀'),
      );
      expect(SwerskiFan.parseJoined(message)!.name, equals('a' * 29));
    });

    test('play ids are truncated to 40 characters when sending', () {
      final message = SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'dev-1', plays: ['p!']),
      ]);
      final long = SwerskiFan.encodeFans([
        SwerskiFan(id: 'dev-1', plays: ['p' * 50]),
      ]);
      expect(
        SwerskiFan.parseFans(long)!.single.plays.single.length,
        equals(40),
      );
      expect(
        SwerskiFan.parseFans(message)!.single.plays.single,
        equals('p!'),
      );
    });

    test('only the first 4 plays of a fan are kept when sending', () {
      final message = SwerskiFan.encodeJoined(
        SwerskiFan(id: 'dev-1', plays: List.generate(6, (i) => 'hero$i')),
      );
      final parsed = SwerskiFan.parseJoined(message)!;
      expect(parsed.plays.length, equals(4));
      expect(parsed.plays.first, equals('hero0'));
    });

    test('only the first 16 fans are kept when sending', () {
      final message = SwerskiFan.encodeFans(List.generate(
        20,
        (i) => SwerskiFan(id: 'dev-$i'),
      ));
      final parsed = SwerskiFan.parseFans(message)!;
      expect(parsed.length, equals(16));
      expect(parsed.first.id, equals('dev-0'));
    });

    test('a message over the limits is ignored', () {
      expect(
        SwerskiFan.parseFans(
          '${prefix}fans {"fans":[{"id":"dev-1","name":"${'n' * 31}"}]}',
        ),
        isNull,
      );
      final tooMany = List.generate(17, (i) => '{"id":"dev-$i"}').join(',');
      expect(
        SwerskiFan.parseFans('${prefix}fans {"fans":[$tooMany]}'),
        isNull,
      );
      expect(
        SwerskiFan.parseJoined(
          '${prefix}joined {"id":"${'i' * 65}","name":"","plays":[]}',
        ),
        isNull,
      );
    });
  });

  group('ignored messages', () {
    test('bad JSON, no body and a list body are ignored', () {
      expect(SwerskiFan.parseFans('${prefix}fans {not json}'), isNull);
      expect(SwerskiFan.parseFans('${prefix}fans'), isNull);
      expect(SwerskiFan.parseFans('${prefix}fans [1,2]'), isNull);
      expect(SwerskiFan.parseJoined('${prefix}joined {}'), isNull);
    });

    test('the other token is ignored', () {
      final fans = SwerskiFan.encodeFans(const [SwerskiFan(id: 'a')]);
      final joined = SwerskiFan.encodeJoined(const SwerskiFan(id: 'a'));
      expect(SwerskiFan.parseJoined(fans), isNull);
      expect(SwerskiFan.parseFans(joined), isNull);
    });

    test('greetings, the ack and game traffic are ignored', () {
      for (final message in [
        SwerskiGreeting.encode(id: 'dev-1'),
        SwerskiGreeting.encodeAck(),
        'init protocolVersion:1',
      ]) {
        expect(
          SwerskiFan.parseFans(message),
          isNull,
          reason: 'message: $message',
        );
        expect(
          SwerskiFan.parseJoined(message),
          isNull,
          reason: 'message: $message',
        );
      }
    });

    test('a missing or wrong-typed fans entry list is ignored', () {
      expect(SwerskiFan.parseFans('${prefix}fans {}'), isNull);
      expect(SwerskiFan.parseFans('${prefix}fans {"fans":"x"}'), isNull);
      expect(SwerskiFan.parseFans('${prefix}fans {"fans":[5]}'), isNull);
    });

    test('a missing, empty or non-string id is ignored', () {
      for (final entry in ['{}', '{"id":""}', '{"id":5}']) {
        expect(
          SwerskiFan.parseFans('${prefix}fans {"fans":[$entry]}'),
          isNull,
          reason: 'entry: $entry',
        );
      }
    });

    test('a wrong-typed field is ignored', () {
      expect(
        SwerskiFan.parseFans(
          '${prefix}fans {"fans":[{"id":"d","host":"y"}]}',
        ),
        isNull,
      );
      expect(
        SwerskiFan.parseFans('${prefix}fans {"fans":[{"id":"d","name":5}]}'),
        isNull,
      );
      expect(
        SwerskiFan.parseJoined(
          '${prefix}joined {"id":"d","name":"","plays":[5]}',
        ),
        isNull,
      );
    });
  });

  group('recognising the messages', () {
    test('fans and joined are Swerski messages, and not each other', () {
      final fans = SwerskiFan.encodeFans(const [SwerskiFan(id: 'a')]);
      final joined = SwerskiFan.encodeJoined(const SwerskiFan(id: 'a'));
      expect(SwerskiFan.isFansMessage(fans), isTrue);
      expect(SwerskiFan.isJoinedMessage(joined), isTrue);
      expect(SwerskiFan.isFansMessage(joined), isFalse);
      expect(SwerskiFan.isJoinedMessage(fans), isFalse);
      expect(
        SwerskiFan.isFansMessage(SwerskiGreeting.encode(id: 'a')),
        isFalse,
      );
      expect(
        SwerskiFan.isJoinedMessage(SwerskiGreeting.encodeAck()),
        isFalse,
      );
    });
  });
}
