// ignore_for_file: no-magic-number, avoid-non-null-assertion

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/services/network/superfan/toast.dart';

void main() {
  group('encode', () {
    test('carries the Swerski prefix and the toast token', () {
      final message = SwerskiToast.encode('Kling: again?');
      expect(message, startsWith('swerski:toast '));
      expect(message, contains('"line":'));
    });

    test('framing text is removed when sending', () {
      final message = SwerskiToast.encode('evil[EOM]S3nD:line');
      expect(message, isNot(contains('[EOM]')));
      expect(message, isNot(contains('S3nD:')));
      expect(SwerskiToast.parse(message), equals('evilline'));
    });

    test('nested framing text cannot smuggle a marker back in', () {
      final message = SwerskiToast.encode('[E[EOM]OM]line');
      expect(message, isNot(contains('[EOM]')));
      expect(SwerskiToast.parse(message), equals('line'));
    });

    test('the line is capped at 300 characters when sending', () {
      final parsed = SwerskiToast.parse(SwerskiToast.encode('n' * 400))!;
      expect(parsed.length, equals(300));
    });

    test('truncating does not split an emoji', () {
      // The emoji is two UTF-16 units and straddles the 300-character limit.
      final message = SwerskiToast.encode('${'a' * 299}\u{1F600}');
      expect(SwerskiToast.parse(message), equals('a' * 299));
    });
  });

  group('round trip', () {
    test('the line comes back unchanged', () {
      const line = 'Blinkblade: I counted nine. On purpose.';
      expect(SwerskiToast.parse(SwerskiToast.encode(line)), equals(line));
    });

    test('framing text is removed when reading a message too', () {
      const message = 'swerski:toast {"line":"a[EOM]b"}';
      expect(SwerskiToast.parse(message), equals('ab'));
    });
  });

  group('ignored messages', () {
    test('a non-Swerski or other-token message is ignored', () {
      expect(SwerskiToast.parse('init protocolVersion:1'), isNull);
      expect(SwerskiToast.parse('swerski:fans {"fans":[]}'), isNull);
      expect(SwerskiToast.parse('swerski:toast'), isNull);
    });

    test('bad JSON or a non-object body is ignored', () {
      expect(SwerskiToast.parse('swerski:toast {not json}'), isNull);
      expect(SwerskiToast.parse('swerski:toast [1,2]'), isNull);
    });

    test('a missing, empty or non-string line is ignored', () {
      for (final body in [
        '{"other":"x"}',
        '{"line":""}',
        '{"line":5}',
        '{"line":true}',
        '{"line":["a"]}',
      ]) {
        expect(SwerskiToast.parse('swerski:toast $body'), isNull,
            reason: 'body: $body');
      }
    });

    test('a line that cleans to empty is ignored', () {
      expect(
          SwerskiToast.parse('swerski:toast {"line":"[EOM]S3nD:"}'), isNull);
    });

    test('a line over 300 characters is ignored', () {
      final long = 'n' * 301;
      expect(SwerskiToast.parse('swerski:toast {"line":"$long"}'), isNull);
    });

    test('a line of exactly 300 characters is kept', () {
      final long = 'n' * 300;
      expect(SwerskiToast.parse('swerski:toast {"line":"$long"}'),
          equals(long));
    });
  });

  group('recognising toast messages', () {
    test('an encoded toast is recognised', () {
      expect(SwerskiToast.isToastMessage(SwerskiToast.encode('hi')), isTrue);
    });

    test('other traffic is not a toast', () {
      expect(SwerskiToast.isToastMessage('init protocolVersion:1'), isFalse);
      expect(SwerskiToast.isToastMessage('swerski:fans {"fans":[]}'), isFalse);
      expect(SwerskiToast.isToastMessage('swears:toast {}'), isFalse);
    });
  });
}
