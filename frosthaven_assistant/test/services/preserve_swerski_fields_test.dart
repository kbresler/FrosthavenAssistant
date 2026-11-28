// ignore_for_file: no-magic-number

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/services/network/superfan/preserve_swerski_fields.dart';

String _state(List<Map<String, dynamic>> currentList) =>
    jsonEncode({'currentList': currentList});

Map<String, dynamic> _hero(
  String id, [
  Map<String, dynamic> hearts = const {},
]) =>
    {'id': id, 'characterState': Map<String, dynamic>.from(hearts)};

Map<String, dynamic> _charState(String json, String id) =>
    ((jsonDecode(json) as Map<String, dynamic>)['currentList'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == id)['characterState']
        as Map<String, dynamic>;

void main() {
  const hearts = {
    'heartAttacks': 2,
    'heartAttacksBefore': 1,
    'littleHeartAttacks': 3,
    'littleHeartAttacksBefore': 4,
  };
  const id = 'blinkblade@1';

  test('absent keys are restored from the current state', () {
    final result = preserveSwerskiFields(
      incoming: _state([_hero(id)]),
      current: _state([_hero(id, hearts)]),
    );
    expect(_charState(result, id), hearts);
  });

  test('a key present in incoming — even as 0 — stays as sent', () {
    final result = preserveSwerskiFields(
      incoming: _state([
        _hero(id, const {'heartAttacks': 0}),
      ]),
      current: _state([_hero(id, hearts)]),
    );
    final state = _charState(result, id);
    expect(state['heartAttacks'], equals(0));
    expect(state['heartAttacksBefore'], equals(1));
    expect(state['littleHeartAttacks'], equals(3));
    expect(state['littleHeartAttacksBefore'], equals(4));
  });

  test('a character only in incoming is left alone', () {
    final result = preserveSwerskiFields(
      incoming: _state([_hero('newhero@1')]),
      current: _state([_hero(id, hearts)]),
    );
    expect(_charState(result, 'newhero@1'), isEmpty);
  });

  test('entries without a characterState are left alone', () {
    final monster = {'id': 'lurker@1', 'monsterState': {'count': 3}};
    final note = {'id': 'note@1', 'text': 'hello'};
    final incoming = _state([monster, note]);
    final result = preserveSwerskiFields(
      incoming: incoming,
      current: _state([_hero(id, hearts)]),
    );
    expect(result, same(incoming));
  });

  test('invalid JSON comes back exactly as it was', () {
    final good = _state([]);
    expect(
      preserveSwerskiFields(incoming: 'not json', current: good),
      same('not json'),
    );
    expect(
      preserveSwerskiFields(incoming: good, current: 'not json'),
      same(good),
    );
  });

  test('a current state that has no counts restores nothing', () {
    final incoming = _state([_hero(id)]);
    final result = preserveSwerskiFields(
      incoming: incoming,
      current: _state([_hero(id)]),
    );
    expect(result, same(incoming));
  });

  group('characterIdsWithoutHeartAttacks', () {
    test('characters whose snapshot lacks the key are listed', () {
      final ids = characterIdsWithoutHeartAttacks(_state([
        _hero('blinkblade@1'),
        _hero('geminate@2', const {'health': 3}),
        _hero('banner_spear@3', hearts),
      ]));
      expect(ids, equals({'blinkblade@1', 'geminate@2'}));
    });

    test('a key present even as 0 means a Swerski client', () {
      final ids = characterIdsWithoutHeartAttacks(_state([
        _hero(id, const {'heartAttacks': 0}),
      ]));
      expect(ids, isEmpty);
    });

    test('entries without a characterState or id are skipped', () {
      final monster = {'id': 'lurker@1', 'monsterState': {'count': 3}};
      final note = {'id': 'note@1', 'text': 'hello'};
      final noId = {'characterState': <String, dynamic>{}};
      final ids =
          characterIdsWithoutHeartAttacks(_state([monster, note, noId]));
      expect(ids, isEmpty);
    });

    test('invalid JSON gives an empty set', () {
      expect(characterIdsWithoutHeartAttacks('not json'), isEmpty);
      expect(characterIdsWithoutHeartAttacks('{}'), isEmpty);
    });
  });
}
