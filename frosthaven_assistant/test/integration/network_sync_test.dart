// ignore_for_file: no-magic-number, avoid-late-keyword, avoid-top-level-members-in-tests, prefer-match-file-name, avoid-non-null-assertion

import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/adjust_heart_attacks_command.dart';
import 'package:frosthaven_assistant/Resource/commands/next_round_command.dart';
import 'package:frosthaven_assistant/Resource/commands/remove_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_level_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/heart_attack_lines.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/communication.dart';
import 'package:frosthaven_assistant/services/network/connection.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/server.dart';
import 'package:frosthaven_assistant/services/network/superfan/fans.dart';
import 'package:frosthaven_assistant/services/network/superfan/greeting.dart';
import 'package:frosthaven_assistant/services/network/superfan/toast.dart';
import 'package:frosthaven_assistant/services/translation_service.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Wire-level client ────────────────────────────────────────────────────────

/// Minimal TCP client that parses S3nD:…[EOM] framed messages.
///
/// It does NOT use any app classes — it's a raw socket + framing helper used
/// to drive and observe the server protocol from the outside.
class WireClient {
  final Socket _socket;
  final _buffered = <String>[];
  final _pending = <Completer<String>>[];
  String _leftOver = '';

  WireClient._(this._socket) {
    _socket.cast<List<int>>().transform(utf8.decoder).listen(
      _onChunk,
      onDone: () {
        for (final c in _pending) {
          c.completeError(StateError('WireClient socket closed unexpectedly'));
        }
        _pending.clear();
      },
    );
  }

  static Future<WireClient> connect(String address, int port) async {
    final socket = await Socket.connect(address, port);
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.encoding = utf8;
    return WireClient._(socket);
  }

  void _onChunk(String chunk) {
    _leftOver += chunk;
    while (true) {
      const prefix = 'S3nD:';
      const suffix = '[EOM]';
      final start = _leftOver.indexOf(prefix);
      if (start == -1) break;
      final contentStart = start + prefix.length;
      final end = _leftOver.indexOf(suffix, contentStart);
      if (end == -1) break;
      final content = _leftOver.substring(contentStart, end);
      _leftOver = _leftOver.substring(end + suffix.length);
      _deliver(content);
    }
  }

  void _deliver(String content) {
    if (_pending.isNotEmpty) {
      _pending.removeAt(0).complete(content);
    } else {
      _buffered.add(content);
    }
  }

  /// Returns the raw content of the next framed message (S3nD:/[EOM] stripped).
  Future<String> receive({Duration timeout = const Duration(seconds: 5)}) {
    if (_buffered.isNotEmpty) return Future.value(_buffered.removeAt(0));
    final c = Completer<String>();
    _pending.add(c);
    return c.future.timeout(timeout, onTimeout: () {
      _pending.remove(c);
      throw TimeoutException('WireClient.receive timed out after $timeout');
    });
  }

  void send(String data) => _socket.write('S3nD:$data[EOM]');

  /// Sends the init handshake and returns the decoded init-response envelope.
  Future<StateEnvelope> doInit() async {
    send('init protocolVersion:1');
    final raw = await receive();
    final envelope = StateEnvelope.tryDecode(raw);
    assert(
        envelope != null, 'Init response was not a valid StateEnvelope: $raw');
    return envelope!;
  }

  Future<void> close() async {
    await _socket.close();
  }
}

// ─── Test globals ─────────────────────────────────────────────────────────────

late int _serverPort;
late GameState _serverGameState;
late Server _testServer;

// The server's clock: re-announce tests move this instead of waiting.
DateTime _fakeNow = DateTime.utc(2026);

Future<void> _setUpServer() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final serverSettings = Settings();
  serverSettings.server.value = true;

  final serverConnection = Connection();
  final serverComm = Communication(connection: serverConnection);

  // Create GameState with injected Settings.
  // Network is resolved lazily via getIt<Network>() inside ActionHandler,
  // so we register it in GetIt after creating all objects (breaks the circular
  // GameState ↔ Network ↔ Server dependency).
  _serverGameState = GameState(
    communication: serverComm,
    settings: serverSettings,
  );

  _testServer = Server(
    gameState: _serverGameState,
    communication: serverComm,
    connection: serverConnection,
    settings: serverSettings,
    clock: () => _fakeNow,
  );

  // Register everything so internal getIt<T>() calls resolve correctly.
  // This test file runs in its own isolate so GetIt is always fresh here.
  getIt.registerSingleton<Settings>(serverSettings);
  getIt.registerSingleton<GameState>(_serverGameState);
  getIt.registerSingleton<Communication>(serverComm);
  getIt.registerSingleton<Connection>(serverConnection);
  getIt.registerSingleton<Network>(Network(server: _testServer));
  getIt.registerLazySingleton<GameData>(() => GameData());

  _serverGameState.init();
  await getIt<GameData>().loadData('assets/testData/');
  _serverGameState.load();

  // Start server on loopback, port 0 (OS assigns a free port).
  // startServerInternal loops forever — do NOT await it.
  // ignore: discarded_futures
  _testServer.startServerInternal('127.0.0.1', 0);

  for (var i = 0; i < 100; i++) {
    if (_testServer.serverSocket != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(_testServer.serverSocket, isNotNull,
      reason: 'Server failed to bind within 1 s');
  _serverPort = _testServer.serverSocket!.port;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(_setUpServer);

  tearDownAll(() => _testServer.stopServer(null));

  // Reset the server's command history before each test so indices start at -1.
  setUp(() => _testServer.resetState());

  // ── Protocol basics ──────────────────────────────────────────────────────────

  group('init handshake', () {
    test('response is a valid JSON envelope with the current server index',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);

      final envelope = await client.doInit();

      expect(envelope.index, equals(_serverGameState.commandIndex.value));
      expect(envelope.state, isNotEmpty);
    });

    test('version mismatch returns Error response', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);

      client.send('init protocolVersion:99'); // wrong protocol version
      final raw = await client.receive();

      expect(raw, startsWith('Error:'));
    });

    test('old client using legacy version: key returns user-friendly Error '
        'and has its connection closed', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      // No addTearDown — server closes the connection; client.close() would
      // throw on an already-destroyed socket.

      client.send('init version:1302'); // pre-protocolVersion old format
      final raw = await client.receive();

      expect(raw, startsWith('Error:'),
          reason: 'Old clients must get a clear rejection');
      expect(raw.toLowerCase(), isNot(contains('malformed')),
          reason: '"malformed init message" is confusing to end-users; '
              'the message must tell them to update instead');

      // Server must close the connection after rejecting.
      // WireClient.onDone completes pending futures with StateError.
      await expectLater(
        client.receive(timeout: const Duration(milliseconds: 500)),
        throwsA(isA<StateError>()),
        reason: 'Server must close the socket after sending the rejection',
      );
    });
  });

  // ── State propagation ─────────────────────────────────────────────────────────

  group('state propagation', () {
    test('server-side action is pushed to connected clients', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit(); // consume init response

      // Execute a command on the server while server-mode is active.
      _serverGameState.action(SetLevelCommand(3, null));

      // The server pushes the new state to all connected clients.
      final pushed = StateEnvelope.tryDecode(await client.receive());

      expect(pushed, isNotNull);
      expect(pushed!.index, equals(_serverGameState.commandIndex.value));
      expect(pushed.state, contains('"level":3'));
    });

    test('client action is forwarded to other connected clients', () async {
      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      final clientB = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientA.close);
      addTearDown(clientB.close);

      final initA = await clientA.doInit();
      await clientB.doInit(); // consume B's init

      // Client A submits an action at index 0 (first action).
      clientA.send(StateEnvelope(
        index: initA.index + 1,
        description: 'ActionFromA',
        eventJson: '{"type":"none"}',
        state: initA.state,
      ).encode());

      // Client B should receive the forwarded state.
      final forwarded = StateEnvelope.tryDecode(await clientB.receive());

      expect(forwarded, isNotNull);
      expect(forwarded!.index, equals(initA.index + 1));
    });

    test('sender does not receive its own action back', () async {
      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientA.close);

      final initA = await clientA.doInit();

      clientA.send(StateEnvelope(
        index: initA.index + 1,
        description: 'ActionFromA',
        eventJson: '{"type":"none"}',
        state: initA.state,
      ).encode());

      // A should NOT receive its own action forwarded back.
      await expectLater(
        clientA.receive(timeout: const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  // ── Swerski field preservation (SuperNetwork phase 0) ────────────────────────

  group('Swerski field preservation', () {
    test('client state without heart-attack keys keeps the server counts',
        () async {
      // Server-side history before any client connects: a hero with all
      // four heart-attack counts raised.
      _serverGameState
          .action(AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1));
      final heroId =
          _serverGameState.currentList.whereType<Character>().first.id;
      addTearDown(() {
        final left = _serverGameState.currentList
            .whereType<Character>()
            .where((c) => c.id == heroId)
            .toList();
        if (left.isNotEmpty) {
          _serverGameState.action(
              RemoveCharacterCommand(left, gameState: _serverGameState));
        }
      });

      void tap(HeartAttackKind kind, HeartAttackPeriod period, int times) {
        for (var i = 0; i < times; i++) {
          _serverGameState.action(AdjustHeartAttacksCommand(
            characterId: heroId,
            kind: kind,
            period: period,
            change: 1,
            gameState: _serverGameState,
          ));
        }
      }

      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, 2);
      tap(HeartAttackKind.major, HeartAttackPeriod.earlier, 1);
      tap(HeartAttackKind.little, HeartAttackPeriod.thisScenario, 3);
      tap(HeartAttackKind.little, HeartAttackPeriod.earlier, 4);

      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      final clientB = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientA.close);
      addTearDown(clientB.close);

      final initA = await clientA.doInit();
      await clientB.doInit();
      expect(initA.state, contains('"heartAttacks":2'),
          reason: 'The synced state should carry the server counts');

      // Client A is the official app: its state carries no Swerski keys.
      final official = jsonDecode(initA.state) as Map<String, dynamic>;
      for (final entry in official['currentList'] as List<dynamic>) {
        if (entry is Map<String, dynamic> &&
            entry['characterState'] is Map<String, dynamic>) {
          (entry['characterState'] as Map<String, dynamic>)
            ..remove('heartAttacks')
            ..remove('heartAttacksBefore')
            ..remove('littleHeartAttacks')
            ..remove('littleHeartAttacksBefore');
        }
      }

      clientA.send(StateEnvelope(
        index: initA.index + 1,
        description: 'OfficialAppAction',
        eventJson: '{"type":"none"}',
        state: jsonEncode(official),
      ).encode());

      final forwarded = StateEnvelope.tryDecode(await clientB.receive());
      expect(forwarded, isNotNull);

      // The server must still hold all four counts.
      final kept = _serverGameState.currentList
          .whereType<Character>()
          .firstWhere((c) => c.id == heroId)
          .characterState;
      expect(kept.heartAttacks.value, equals(2));
      expect(kept.heartAttacksBefore.value, equals(1));
      expect(kept.littleHeartAttacks.value, equals(3));
      expect(kept.littleHeartAttacksBefore.value, equals(4));

      // The state forwarded to B must carry them too.
      final bJson = jsonDecode(forwarded!.state) as Map<String, dynamic>;
      final bHero = (bJson['currentList'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == heroId);
      final bState = bHero['characterState'] as Map<String, dynamic>;
      expect(bState['heartAttacks'], equals(2));
      expect(bState['heartAttacksBefore'], equals(1));
      expect(bState['littleHeartAttacks'], equals(3));
      expect(bState['littleHeartAttacksBefore'], equals(4));
    });
  });

  // ── Swerski greeting (SuperNetwork phase 1) ─────────────────────────────────

  group('Swerski greeting', () {
    /// Waits for a server-side condition (roster updates happen on the
    /// server's event loop, after the client-side future completes).
    Future<void> waitUntilRoster(bool Function(List<dynamic>) done) async {
      for (var i = 0; i < 200; i++) {
        if (done(_testServer.swerskiClients)) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('roster never reached the expected state: '
          '${_testServer.swerskiClients.map((c) => c.id).toList()}');
    }

    setUp(() => waitUntilRoster((r) => r.isEmpty));

    test('a greeting is answered and listed', () async {
      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientA.close);
      final initA = await clientA.doInit();

      clientA.send(SwerskiGreeting.encode(
        id: 'dev-1',
        name: 'Kitchen tablet',
        plays: const ['blinkblade@1'],
      ));

      final raw = await clientA.receive();
      expect(raw, equals(SwerskiGreeting.encodeAck()));

      final listed = _testServer.swerskiClients;
      expect(listed.length, equals(1));
      expect(listed.single.id, equals('dev-1'));
      expect(listed.single.name, equals('Kitchen tablet'));
      expect(listed.single.plays, equals(['blinkblade@1']));

      // The greeting must not touch the game.
      expect(_serverGameState.commandIndex.value, equals(initA.index));
    });

    test('a greeting is not forwarded and answers nobody else', () async {
      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      final clientB = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientA.close);
      addTearDown(clientB.close);
      await clientA.doInit();
      await clientB.doInit();

      clientA.send(SwerskiGreeting.encode(id: 'dev-1'));
      expect(await clientA.receive(), equals(SwerskiGreeting.encodeAck()));

      // B greeted nothing and must receive nothing.
      await expectLater(
        clientB.receive(timeout: const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
      // Only A is listed.
      expect(_testServer.swerskiClients.map((c) => c.id).toList(),
          equals(['dev-1']));
    });

    test('a client that does not greet is not listed and hears no swerski',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();

      expect(_testServer.swerskiClients, isEmpty);
      await expectLater(
        client.receive(timeout: const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('a malformed greeting is ignored without an error', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();

      client.send('swerski:Da Bears! superfan:1 {not json}');
      client.send('swerski:wrong token');
      client.send('swerski:Da Bears! superfan:9 {"id":"x"}');

      // No ack, no error, no listing — and the connection stays usable.
      await expectLater(
        client.receive(timeout: const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
      expect(_testServer.swerskiClients, isEmpty);

      client.send(SwerskiGreeting.encode(id: 'dev-after-malformed'));
      expect(await client.receive(), equals(SwerskiGreeting.encodeAck()));
    });

    test('disconnect removes the entry', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      await client.doInit();
      client.send(SwerskiGreeting.encode(id: 'dev-1'));
      await client.receive(); // ack
      await waitUntilRoster((r) => r.isNotEmpty);

      await client.close();
      await waitUntilRoster((r) => r.isEmpty);
    });

    test('the same id on a new connection replaces the old entry', () async {
      final oldClient = await WireClient.connect('127.0.0.1', _serverPort);
      final newClient = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(newClient.close);
      await oldClient.doInit();
      await newClient.doInit();

      oldClient.send(SwerskiGreeting.encode(id: 'dev-1', name: 'First'));
      await oldClient.receive(); // ack
      newClient.send(SwerskiGreeting.encode(id: 'dev-1', name: 'Second'));
      await newClient.receive(); // ack

      await waitUntilRoster((r) => r.length == 1 && r.single.name == 'Second');

      // The old connection going away must not take the entry with it.
      await oldClient.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final listed = _testServer.swerskiClients;
      expect(listed.length, equals(1));
      expect(listed.single.name, equals('Second'));
    });

    test('one connection is listed once, as it last greeted', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      client.send(SwerskiGreeting.encode(id: 'dev-1'));
      await client.receive(); // ack
      client.send(SwerskiGreeting.encode(id: 'dev-2'));
      // Not `receive()` for the ack: the fans list from the first greeting
      // can sit in front of it, and the next message is not the second
      // greeting having been processed.
      await waitUntilRoster((r) => r.length == 1 && r.single.id == 'dev-2');

      expect(_testServer.swerskiClients.map((c) => c.id).toList(),
          equals(['dev-2']));
    });

    test('a socket dropped from the connection elsewhere leaves the roster',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      client.send(SwerskiGreeting.encode(id: 'dev-1'));
      await client.receive(); // ack
      await waitUntilRoster((r) => r.isNotEmpty);

      // Communication drops a write-failing socket directly, without the
      // server's removeClientConnection ever firing.
      getIt<Connection>().remove(_testServer.swerskiClients.single.socket);
      await waitUntilRoster((r) => r.isEmpty);
    });

    test('stopping the server empties the roster', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      await client.doInit();
      client.send(SwerskiGreeting.encode(id: 'dev-1'));
      await client.receive(); // ack
      await waitUntilRoster((r) => r.isNotEmpty);

      final stoppedSocket = _testServer.serverSocket;
      _testServer.stopServer(null);
      expect(_testServer.swerskiClients, isEmpty);

      try {
        await client.close();
      } catch (_) {
        // stopServer already destroyed the connection.
      }

      // Bring the shared server back up for the rest of this file.
      // ignore: discarded_futures
      _testServer.startServerInternal('127.0.0.1', 0);
      for (var i = 0; i < 100; i++) {
        if (_testServer.serverSocket != null &&
            !identical(_testServer.serverSocket, stoppedSocket)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      _serverPort = _testServer.serverSocket!.port;
      final probe = await Socket.connect('127.0.0.1', _serverPort,
          timeout: const Duration(seconds: 2));
      await probe.close();
    });
  });

  // ── Swerski fans list (SuperNetwork phase 2) ──────────────────────────────────

  group('Swerski fans list', () {
    Future<void> waitUntilFans(bool Function(List<SwerskiFan>) done) async {
      for (var i = 0; i < 200; i++) {
        if (done(getIt<Network>().superFans.value)) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('fans list never reached the expected state: '
          '${getIt<Network>().superFans.value.map((f) => f.id).toList()}');
    }

    /// The next `fans` message on [client], skipping anything else.
    Future<List<SwerskiFan>> receiveFans(WireClient client) async {
      for (var i = 0; i < 5; i++) {
        final parsed = SwerskiFan.parseFans(await client.receive());
        if (parsed != null) return parsed;
      }
      throw StateError('no fans message in the last 5 messages');
    }

    Future<void> greet(WireClient client, String id) async {
      client.send(SwerskiGreeting.encode(id: id));
      expect(await client.receive(), equals(SwerskiGreeting.encodeAck()));
    }

    setUp(() async {
      for (var i = 0; i < 200; i++) {
        if (_testServer.swerskiClients.isEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // The host lists itself from its own settings, so the tests decide
      // what that entry says. The stored devicePlays are deliberately
      // non-empty: the host must ignore them and play the table.
      final settings = getIt<Settings>();
      settings.deviceId = 'host-1';
      settings.deviceName.value = 'Table host';
      settings.devicePlays.value = ['blinkblade@1', 'geminate@2'];
      addTearDown(() {
        settings.deviceId = '';
        settings.deviceName.value = '';
        settings.devicePlays.value = [];
      });
    });

    test('the list holds the host first, then every greeted device',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'dev-1');

      await waitUntilFans((fans) => fans.length == 2);
      final listed = getIt<Network>().superFans.value;
      expect(listed.first.id, equals('host-1'));
      expect(listed.first.name, equals('Table host'));
      expect(listed.first.plays, isEmpty,
          reason: 'the host plays the table, whatever its stored devicePlays '
              'say');
      expect(listed.first.host, isTrue);
      expect(listed.last.id, equals('dev-1'));
      expect(listed.last.host, isFalse);
    });

    test('the greeted device is sent the list', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'dev-1');

      final fans = await receiveFans(client);
      expect(fans.map((f) => f.id).toList(), equals(['host-1', 'dev-1']));
      expect(fans.first.host, isTrue);
      expect(fans.last.host, isFalse);
    });

    test('a device that never greeted hears no list', () async {
      final swerski = await WireClient.connect('127.0.0.1', _serverPort);
      final plain = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(swerski.close);
      addTearDown(plain.close);
      await swerski.doInit();
      await plain.doInit();
      await greet(swerski, 'dev-1');
      await receiveFans(swerski);

      await expectLater(
        plain.receive(timeout: const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('the list is re-sent when a device leaves', () async {
      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      final clientB = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientB.close);
      await clientA.doInit();
      await clientB.doInit();
      await greet(clientA, 'dev-a');
      await greet(clientB, 'dev-b');
      await waitUntilFans((fans) => fans.length == 3);

      // B got exactly one list: the one from its own greeting.
      expect((await receiveFans(clientB)).length, equals(3));

      await clientA.close();
      await waitUntilFans((fans) => fans.length == 2);
      final after = await receiveFans(clientB);
      expect(after.map((f) => f.id).toList(), equals(['host-1', 'dev-b']));
    });

    test('the socket that just greeted always gets the list', () async {
      final first = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(first.close);
      await first.doInit();
      await greet(first, 'dev-1');
      await receiveFans(first);

      // The same device reconnects before the host noticed the old socket
      // died: the roster already holds its id, so the list is unchanged and
      // the diff would skip the send. The greeting socket must get the list
      // either way, or it shows a SuperNetwork that does not exist.
      final second = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(second.close);
      await second.doInit();
      await greet(second, 'dev-1');

      final fans = await receiveFans(second);
      expect(fans.map((f) => f.id).toList(), equals(['host-1', 'dev-1']));
    });

    test('the host renaming itself refreshes the list, without a banner',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'dev-1');
      await receiveFans(client);
      await waitUntilFans((fans) => fans.length == 2);

      getIt<Settings>().deviceName.value = 'Kitchen host';
      getIt<Network>().superFanJoined.value = null;
      _testServer.refreshHostIdentity();

      await waitUntilFans((fans) => fans.first.name == 'Kitchen host');
      final fans = await receiveFans(client);
      expect(fans.first.name, equals('Kitchen host'),
          reason: 'the greeted device gets the updated list');
      expect(getIt<Network>().superFanJoined.value, isNull,
          reason: 'a rename is not a join');
    });

    test('stopping the server empties the list', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      await client.doInit();
      await greet(client, 'dev-1');
      await waitUntilFans((fans) => fans.length == 2);

      final stoppedSocket = _testServer.serverSocket;
      _testServer.stopServer(null);
      expect(getIt<Network>().superFans.value, isEmpty);

      try {
        await client.close();
      } catch (_) {
        // stopServer already destroyed the connection.
      }

      // Bring the shared server back up for the rest of this file.
      // ignore: discarded_futures
      _testServer.startServerInternal('127.0.0.1', 0);
      for (var i = 0; i < 100; i++) {
        if (_testServer.serverSocket != null &&
            !identical(_testServer.serverSocket, stoppedSocket)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      _serverPort = _testServer.serverSocket!.port;
      final probe = await Socket.connect('127.0.0.1', _serverPort,
          timeout: const Duration(seconds: 2));
      await probe.close();
    });

    test('a running server lists the host before anyone joins', () async {
      // Restart the shared server and touch nothing else: Settings shows the
      // SuperNetwork block as soon as the server runs, so the list must hold
      // the host's own entry from the start, not only after a greeting.
      final stoppedSocket = _testServer.serverSocket;
      _testServer.stopServer(null);
      // ignore: discarded_futures
      _testServer.startServerInternal('127.0.0.1', 0);
      for (var i = 0; i < 100; i++) {
        if (_testServer.serverSocket != null &&
            !identical(_testServer.serverSocket, stoppedSocket)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      _serverPort = _testServer.serverSocket!.port;
      final probe = await Socket.connect('127.0.0.1', _serverPort,
          timeout: const Duration(seconds: 2));
      await probe.close();

      final listed = getIt<Network>().superFans.value;
      expect(listed.map((f) => f.id).toList(), equals(['host-1']));
      expect(listed.single.name, equals('Table host'));
      expect(listed.single.host, isTrue);
    });
  });

  // ── Swerski joined announcement (SuperNetwork phase 2, rule 5) ────────────────

  group('Swerski joined announcement', () {
    /// Reads up to [messages] framed messages (waiting at most [timeout] for
    /// the next one) and returns the first `joined` among them, null if none.
    Future<SwerskiFan?> receiveJoined(
      WireClient client, {
      int messages = 5,
      Duration timeout = const Duration(milliseconds: 300),
    }) async {
      for (var i = 0; i < messages; i++) {
        String raw;
        try {
          raw = await client.receive(timeout: timeout);
        } on TimeoutException {
          return null;
        }
        final parsed = SwerskiFan.parseJoined(raw);
        if (parsed != null) return parsed;
      }
      return null;
    }

    Future<void> greet(
      WireClient client,
      String id, {
      String name = '',
      List<String> plays = const [],
      bool asking = false,
    }) async {
      client.send(SwerskiGreeting.encode(
          id: id, name: name, plays: plays, asking: asking));
      expect(await client.receive(), equals(SwerskiGreeting.encodeAck()));
    }

    Future<void> waitUntilRosterEmpty() async {
      for (var i = 0; i < 200; i++) {
        if (_testServer.swerskiClients.isEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('roster never emptied between tests');
    }

    setUp(() async {
      await waitUntilRosterEmpty();
      _fakeNow = DateTime.utc(2026);
      final settings = getIt<Settings>();
      settings.deviceId = 'host-1';
      settings.deviceName.value = 'Table host';
      addTearDown(() {
        settings.deviceId = '';
        settings.deviceName.value = '';
      });
    });

    test('a greeting announces the joiner to the greeted devices and to the host',
        () async {
      final first = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(first.close);
      await first.doInit();
      await greet(first, 'ann-a', name: 'First phone');

      final joinedA = await receiveJoined(first);
      expect(joinedA?.id, equals('ann-a'));

      final second = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(second.close);
      await second.doInit();
      await greet(second, 'ann-b', name: 'Second phone');

      final joinedBForSelf = await receiveJoined(second);
      expect(joinedBForSelf?.id, equals('ann-b'));
      final joinedBForFirst = await receiveJoined(first);
      expect(joinedBForFirst?.id, equals('ann-b'));
      expect(joinedBForFirst?.name, equals('Second phone'));
      expect(getIt<Network>().superFanJoined.value?.name,
          equals('Second phone'));
    });

    test('a greeting that is still asking is not announced, '
        'the greeting after the choice is', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'ann-ask', name: 'Choosing phone', asking: true);

      expect(await receiveJoined(client), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);

      await greet(client, 'ann-ask', name: 'Choosing phone',
          plays: ['blinkblade@1']);
      final joined = await receiveJoined(client);
      expect(joined?.id, equals('ann-ask'));
      expect(getIt<Network>().superFanJoined.value?.name,
          equals('Choosing phone'));
      expect(getIt<Network>().superFanJoined.value?.plays,
          equals(['blinkblade@1']));
    });

    test('reconnecting with the same choice is not announced again', () async {
      final first = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(first.close);
      await first.doInit();
      await greet(first, 'ann-re', name: 'Kitchen tablet',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(first), isNotNull);

      await first.close();
      await waitUntilRosterEmpty();
      getIt<Network>().superFanJoined.value = null;

      final again = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(again.close);
      await again.doInit();
      await greet(again, 'ann-re', name: 'Kitchen tablet',
          plays: ['blinkblade@1']);

      expect(await receiveJoined(again), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);
    });

    test('the same plays in another order are not announced again',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'ann-order', name: 'Phone',
          plays: ['blinkblade@1', 'geminate@2']);
      expect(await receiveJoined(client), isNotNull);
      getIt<Network>().superFanJoined.value = null;

      // Initiative reordered the characters; the device re-sends its greeting
      // with the same plays in the new order. Same set, so no new join.
      await greet(client, 'ann-order', name: 'Phone',
          plays: ['geminate@2', 'blinkblade@1']);
      expect(await receiveJoined(client), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);
    });

    test('a rename is not announced, a changed choice is', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'ann-ch', name: 'Old name',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(client), isNotNull);
      // The banner widget would have consumed the announcement by now; the
      // server itself never clears it.
      getIt<Network>().superFanJoined.value = null;

      await greet(client, 'ann-ch', name: 'New name',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(client), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);

      await greet(client, 'ann-ch', name: 'New name',
          plays: ['geminate@2']);
      final joined = await receiveJoined(client);
      expect(joined?.id, equals('ann-ch'));
      expect(getIt<Network>().superFanJoined.value?.name, equals('New name'));
      expect(getIt<Network>().superFanJoined.value?.plays,
          equals(['geminate@2']));
    });

    test('back after 6 minutes away, the same plays announce once again',
        () async {
      final first = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(first.close);
      await first.doInit();
      await greet(first, 'ann-away', name: 'Patio phone',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(first), isNotNull);

      await first.close();
      await waitUntilRosterEmpty();
      getIt<Network>().superFanJoined.value = null;
      _fakeNow = _fakeNow.add(const Duration(minutes: 6));

      final again = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(again.close);
      await again.doInit();
      await greet(again, 'ann-away', name: 'Patio phone',
          plays: ['blinkblade@1']);

      final joined = await receiveJoined(again);
      expect(joined?.id, equals('ann-away'));
      expect(getIt<Network>().superFanJoined.value?.name,
          equals('Patio phone'));

      // Once only: the greeting right after is not another 6-minute gap.
      getIt<Network>().superFanJoined.value = null;
      await greet(again, 'ann-away', name: 'Patio phone',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(again), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);
    });

    test('back after only 2 minutes quiet is not announced again', () async {
      final first = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(first.close);
      await first.doInit();
      await greet(first, 'ann-2m', name: 'Kitchen tablet',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(first), isNotNull);

      await first.close();
      await waitUntilRosterEmpty();
      getIt<Network>().superFanJoined.value = null;
      _fakeNow = _fakeNow.add(const Duration(minutes: 2));

      final again = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(again.close);
      await again.doInit();
      await greet(again, 'ann-2m', name: 'Kitchen tablet',
          plays: ['blinkblade@1']);

      expect(await receiveJoined(again), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);
    });

    test('asking, then the choice after 6 minutes quiet announces', () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'ann-ask6', name: 'Cell phone',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(client), isNotNull);
      getIt<Network>().superFanJoined.value = null;

      // A new app run on the same device: it asks first, and the picker's
      // greeting only lands after the 6-minute quiet.
      _fakeNow = _fakeNow.add(const Duration(minutes: 6));
      await greet(client, 'ann-ask6', name: 'Cell phone', asking: true);
      expect(await receiveJoined(client), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);

      await greet(client, 'ann-ask6', name: 'Cell phone',
          plays: ['blinkblade@1']);
      final joined = await receiveJoined(client);
      expect(joined?.id, equals('ann-ask6'));
      expect(getIt<Network>().superFanJoined.value?.plays,
          equals(['blinkblade@1']));
    });

    test('a connected device that keeps answering pings re-greets quietly',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      await client.doInit();
      await greet(client, 'ann-ping', name: 'Tablet',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(client), isNotNull);
      getIt<Network>().superFanJoined.value = null;

      // 6 minutes of fake quiet would announce again — but the host heard a
      // message from this socket every minute.
      for (var minute = 0; minute < 6; minute++) {
        _fakeNow = _fakeNow.add(const Duration(minutes: 1));
        client.send('ping');
        // The host's pong confirms it took the message; not a joined one.
        final pong = await client.receive(
            timeout: const Duration(milliseconds: 300));
        expect(pong, isNot(contains('joined')));
      }

      await greet(client, 'ann-ping', name: 'Tablet',
          plays: ['blinkblade@1']);
      expect(await receiveJoined(client), isNull);
      expect(getIt<Network>().superFanJoined.value, isNull);
    });
  });

  // ── Heart-attack toast relay ───────────────────────────────────────────────

  group('Swerski heart-attack toast', () {
    Future<void> waitUntilRosterEmpty() async {
      for (var i = 0; i < 200; i++) {
        if (_testServer.swerskiClients.isEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('roster never emptied between tests');
    }

    Future<void> greet(WireClient client, String id) async {
      client.send(SwerskiGreeting.encode(id: id, name: 'Kitchen phone'));
      expect(await client.receive(), equals(SwerskiGreeting.encodeAck()));
    }

    /// The next `toast` line on [client] among up to [messages] messages
    /// (ack/fans chatter skipped), null if none arrives in time.
    Future<String?> receiveToast(
      WireClient client, {
      int messages = 5,
      Duration timeout = const Duration(milliseconds: 300),
    }) async {
      for (var i = 0; i < messages; i++) {
        String raw;
        try {
          raw = await client.receive(timeout: timeout);
        } on TimeoutException {
          return null;
        }
        final parsed = SwerskiToast.parse(raw);
        if (parsed != null) return parsed;
      }
      return null;
    }

    setUp(() async {
      await waitUntilRosterEmpty();
      _serverGameState.heartAttackToast.value = '';
      // A loaded update can leave the host playing turns; the little-attack
      // detection needs a fresh choosing-initiative baseline.
      if (_serverGameState.roundState.value != RoundState.chooseInitiative) {
        _serverGameState.action(NextRoundCommand(
          gameState: _serverGameState,
          gameData: getIt<GameData>(),
          settings: getIt<Settings>(),
        ));
      }
      if (!getIt.isRegistered<TranslationService>()) {
        getIt.registerSingleton<TranslationService>(TranslationService());
        addTearDown(() => getIt.unregister<TranslationService>());
      }
    });

    /// A hero on the host's table, removed again when the test ends.
    String addHero(String className) {
      final was = _serverGameState.currentList
          .whereType<Character>()
          .map((c) => c.id)
          .toSet();
      _serverGameState
          .action(AddCharacterCommand(className, 'Frosthaven', null, 1));
      final id = _serverGameState.currentList
          .whereType<Character>()
          .map((c) => c.id)
          .firstWhere((i) => !was.contains(i));
      addTearDown(() {
        final left = _serverGameState.currentList
            .whereType<Character>()
            .where((c) => c.id == id)
            .toList();
        if (left.isNotEmpty) {
          _serverGameState.action(
              RemoveCharacterCommand(left, gameState: _serverGameState));
        }
      });
      return id;
    }

    /// A copy of [init.state] as a phone would send it: character fields
    /// changed, the whole snapshot moved to a round state, heroes duplicated,
    /// or — for [official] — the Swerski keys stripped like an official app
    /// sends them.
    String phoneState(
      StateEnvelope init, {
      Map<String, Map<String, Object?>> heroes = const {},
      int? round,
      Map<String, String> duplicate = const {},
      Map<String, Object?> copyAs = const {},
      bool official = false,
    }) {
      final json = jsonDecode(init.state) as Map<String, dynamic>;
      final list = (json['currentList'] as List).cast<Map<String, dynamic>>();
      for (final dup in duplicate.entries) {
        final src = list.firstWhere((e) => e['id'] == dup.key);
        final copy = jsonDecode(jsonEncode(src)) as Map<String, dynamic>;
        copy['id'] = dup.value;
        copy.addAll(copyAs);
        list.add(copy);
      }
      for (final entry in list) {
        final state = entry['characterState'];
        if (state is! Map<String, dynamic>) continue;
        final changes = heroes[entry['id']];
        if (changes != null) state.addAll(changes);
        if (official) {
          state.remove('heartAttacks');
          state.remove('heartAttacksBefore');
          state.remove('littleHeartAttacks');
          state.remove('littleHeartAttacksBefore');
        }
      }
      if (round != null) json['roundState'] = round;
      return jsonEncode(json);
    }

    /// A client's update at the next index, as the app sends it.
    void sendPhoneUpdate(
        WireClient phone, StateEnvelope init, String state) {
      phone.send(StateEnvelope(
        index: init.index + 1,
        description: 'phone action',
        eventJson: '{"type":"none"}',
        state: state,
      ).encode());
    }

    test('a published line reaches every greeted device and shows here',
        () async {
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      await phone.doInit();
      await greet(phone, 'toast-1');

      publishHeartAttackLine('Kling: write it down.', _serverGameState);

      expect(await receiveToast(phone), equals('Kling: write it down.'));
      expect(_serverGameState.heartAttackToast.value,
          equals('Kling: write it down.'));
    });

    test('a device that never greeted hears no toast', () async {
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      await official.doInit();
      await phone.doInit();
      await greet(phone, 'toast-2');

      publishHeartAttackLine('only for the SuperNetwork', _serverGameState);

      expect(await receiveToast(official), isNull);
      expect(await receiveToast(phone), equals('only for the SuperNetwork'));
    });

    test('a null or empty line is neither shown nor sent', () async {
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      await phone.doInit();
      await greet(phone, 'toast-3');

      publishHeartAttackLine(null, _serverGameState);
      publishHeartAttackLine('', _serverGameState);

      expect(_serverGameState.heartAttackToast.value, isEmpty);
      expect(await receiveToast(phone), isNull);
    });

    test('a server that never started sends nothing', () {
      // Fresh Server instance, never started: no socket, so a silent no-op
      // rather than a crash.
      expect(() => Server().sendSuperFanToast('line'), returnsNormally);
    });

    test('a phone on a greeted host does not write its own line', () {
      final oldClient = getIt<Settings>().client.value;
      final network = getIt<Network>();
      final oldGreeted = network.hostGreeted.value;
      addTearDown(() {
        getIt<Settings>().client.value = oldClient;
        network.hostGreeted.value = oldGreeted;
      });
      getIt<Settings>().client.value = ClientState.connected;
      network.hostGreeted.value = true;

      publishHeartAttackLine('the host writes this one', _serverGameState);

      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });

    test('a phone on an official host still writes its own line', () {
      final oldClient = getIt<Settings>().client.value;
      final network = getIt<Network>();
      final oldGreeted = network.hostGreeted.value;
      addTearDown(() {
        getIt<Settings>().client.value = oldClient;
        network.hostGreeted.value = oldGreeted;
      });
      getIt<Settings>().client.value = ClientState.connected;
      network.hostGreeted.value = false;

      publishHeartAttackLine('my own line, official host', _serverGameState);

      expect(_serverGameState.heartAttackToast.value,
          equals('my own line, official host'));
    });

    test('a phone dropping a hero to 0 earns a major line for everyone',
        () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-major-1');

      sendPhoneUpdate(phone, init,
          phoneState(init, heroes: {victim: {'health': 0, 'heartAttacks': 1}}));

      final toast = await receiveToast(phone);
      expect(toast, isNotNull);
      expect(toast, contains('Blinkblade'));
      expect(_serverGameState.heartAttackToast.value, equals(toast));
    });

    test('two heroes down in one update get one line, about the last',
        () async {
      // New heroes go on top, so the list ends: Banner Spear, Blinkblade.
      final addedFirst = addHero('Blinkblade');
      final addedSecond = addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-major-2');

      sendPhoneUpdate(
          phone,
          init,
          phoneState(init, heroes: {
            addedFirst: {'health': 0, 'heartAttacks': 1},
            addedSecond: {'health': 0, 'heartAttacks': 1},
          }));

      final toast = await receiveToast(phone);
      // Exactly two heroes: the speaker is the other one, so the line prefix
      // tells who the victim was — the Blinkblade, last in list order.
      expect(toast, isNotNull);
      expect(toast, startsWith('Banner Spear: '));
      expect(toast, contains('Blinkblade'));
      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, equals(toast));
    });

    test('a hero resting on the phone earns the recovering line', () async {
      final hero = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-little-1');

      sendPhoneUpdate(
          phone,
          init,
          phoneState(init,
              heroes: {hero: {'littleHeartAttacks': 1}},
              round: RoundState.playTurns.index));

      final toast = await receiveToast(phone);
      expect(toast, contains('Blinkblade'));
      expect(toast, endsWith('(long rest).'));
      expect(_serverGameState.heartAttackToast.value, equals(toast));
    });

    test('two heroes resting at once get one combined line', () async {
      final first = addHero('Blinkblade');
      final second = addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-little-2');

      sendPhoneUpdate(
          phone,
          init,
          phoneState(init,
              heroes: {
                first: {'littleHeartAttacks': 1},
                second: {'littleHeartAttacks': 1},
              },
              round: RoundState.playTurns.index));

      final toast = await receiveToast(phone);
      expect(toast, contains('Blinkblade'));
      expect(toast, contains('Banner Spear'));
      expect(toast, contains('each had a little heart attack'));
      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, equals(toast));
    });

    test('a little heart attack without the round change stays silent',
        () async {
      final hero = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-little-3');

      // The Draw did not happen: the host is still choosing initiative.
      sendPhoneUpdate(phone, init,
          phoneState(init, heroes: {hero: {'littleHeartAttacks': 1}}));

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });

    test('a little heart attack beats a major in the same update', () async {
      final down = addHero('Blinkblade');
      final resting = addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-little-4');

      sendPhoneUpdate(
          phone,
          init,
          phoneState(init,
              heroes: {
                down: {'health': 0, 'heartAttacks': 1},
                resting: {'littleHeartAttacks': 1},
              },
              round: RoundState.playTurns.index));

      // One line only, and it is the recovering one, not a reply.
      final toast = await receiveToast(phone);
      expect(toast, contains('Banner Spear'));
      expect(toast, endsWith('(long rest).'));
      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, equals(toast));
    });

    test('an update with no heart event stays silent', () async {
      addHero('Blinkblade');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-silent-1');

      sendPhoneUpdate(phone, init, init.state);

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });

    test('a tally edit on the phone stays silent', () async {
      final hero = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-silent-2');

      sendPhoneUpdate(phone, init,
          phoneState(init, heroes: {hero: {'heartAttacks': 1}}));

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });

    // Superseded by host-side counting: an official-app hero dropped to 0
    // now earns a counted major and a line (see the group below).
    test('an official app state with a hero at 0 is counted by the host',
        () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await official.doInit();
      await phone.doInit();
      await greet(phone, 'ha-silent-3');

      sendPhoneUpdate(official, init,
          phoneState(init, heroes: {victim: {'health': 0}}, official: true));

      expect(await receiveToast(phone), contains('Blinkblade'));
      expect(_serverGameState.heartAttackToast.value, contains('Blinkblade'));
      expect(
          _serverGameState.currentList
              .whereType<Character>()
              .firstWhere((c) => c.id == victim)
              .characterState
              .heartAttacks
              .value,
          equals(1));
    });

    test('a hero added dead on arrival stays silent', () async {
      // The new hero is a class the host has never seen: a Character gets
      // the class id, so copying a table hero's row would BE that hero.
      final src = addHero('Blinkblade');
      addHero('Banner Spear');
      addTearDown(() {
        final ghosts = _serverGameState.currentList
            .whereType<Character>()
            .where((c) => c.id == 'Hail')
            .toList();
        if (ghosts.isNotEmpty) {
          _serverGameState.action(
              RemoveCharacterCommand(ghosts, gameState: _serverGameState));
        }
      });
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-silent-4');

      sendPhoneUpdate(
          phone,
          init,
          phoneState(init,
              duplicate: {src: 'ghost-1'},
              copyAs: {
                'characterClass': 'Hail',
                'edition': 'Mercenary Packs',
              },
              heroes: {
                'ghost-1': {'health': 0, 'heartAttacks': 1}
              }));

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });

    test('a stale-index update stays silent', () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-silent-5');

      // Same index as the host: rejected, its state is never loaded.
      phone.send(StateEnvelope(
        index: init.index,
        description: 'stale',
        eventJson: '{"type":"none"}',
        state: phoneState(init,
            heroes: {victim: {'health': 0, 'heartAttacks': 1}}),
      ).encode());

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });

    test('an ungreeted device receives no line', () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await official.doInit();
      await greet(phone, 'ha-greeted-1');

      sendPhoneUpdate(phone, init,
          phoneState(init, heroes: {victim: {'health': 0, 'heartAttacks': 1}}));

      expect(await receiveToast(official), isNull);
      expect(await receiveToast(phone), isNotNull);
    });

    test('host with Heart attacks off still sends, shows nothing itself',
        () async {
      final oldOff = getIt<Settings>().heartAttacks.value;
      getIt<Settings>().heartAttacks.value = false;
      addTearDown(() => getIt<Settings>().heartAttacks.value = oldOff);
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'ha-off-host');

      sendPhoneUpdate(phone, init,
          phoneState(init, heroes: {victim: {'health': 0, 'heartAttacks': 1}}));

      expect(await receiveToast(phone), contains('Blinkblade'));
      expect(_serverGameState.heartAttackToast.value, isEmpty);
    });
  });

  // ── Official-app heart attacks counted by the host ─────────────────────────

  group('Official-app heart attacks counted by the host', () {
    Future<void> waitUntilRosterEmpty() async {
      for (var i = 0; i < 200; i++) {
        if (_testServer.swerskiClients.isEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('roster never emptied between tests');
    }

    Future<void> greet(WireClient client, String id) async {
      client.send(SwerskiGreeting.encode(id: id, name: 'Kitchen phone'));
      expect(await client.receive(), equals(SwerskiGreeting.encodeAck()));
    }

    Future<String?> receiveToast(
      WireClient client, {
      int messages = 5,
      Duration timeout = const Duration(milliseconds: 300),
    }) async {
      for (var i = 0; i < messages; i++) {
        String raw;
        try {
          raw = await client.receive(timeout: timeout);
        } on TimeoutException {
          return null;
        }
        final parsed = SwerskiToast.parse(raw);
        if (parsed != null) return parsed;
      }
      return null;
    }

    setUp(() async {
      await waitUntilRosterEmpty();
      _serverGameState.heartAttackToast.value = '';
      // The little-attack detection needs a fresh choosing-initiative
      // baseline; an earlier test may have left the host playing turns.
      if (_serverGameState.roundState.value != RoundState.chooseInitiative) {
        _serverGameState.action(NextRoundCommand(
          gameState: _serverGameState,
          gameData: getIt<GameData>(),
          settings: getIt<Settings>(),
        ));
      }
      if (!getIt.isRegistered<TranslationService>()) {
        getIt.registerSingleton<TranslationService>(TranslationService());
        addTearDown(() => getIt.unregister<TranslationService>());
      }
    });

    String addHero(String className) {
      final was = _serverGameState.currentList
          .whereType<Character>()
          .map((c) => c.id)
          .toSet();
      _serverGameState
          .action(AddCharacterCommand(className, 'Frosthaven', null, 1));
      final id = _serverGameState.currentList
          .whereType<Character>()
          .map((c) => c.id)
          .firstWhere((i) => !was.contains(i));
      addTearDown(() {
        final left = _serverGameState.currentList
            .whereType<Character>()
            .where((c) => c.id == id)
            .toList();
        if (left.isNotEmpty) {
          _serverGameState.action(
              RemoveCharacterCommand(left, gameState: _serverGameState));
        }
      });
      return id;
    }

    String phoneState(
      StateEnvelope init, {
      Map<String, Map<String, Object?>> heroes = const {},
      int? round,
      Map<String, String> duplicate = const {},
      Map<String, Object?> copyAs = const {},
      bool official = false,
    }) {
      final json = jsonDecode(init.state) as Map<String, dynamic>;
      final list = (json['currentList'] as List).cast<Map<String, dynamic>>();
      for (final dup in duplicate.entries) {
        final src = list.firstWhere((e) => e['id'] == dup.key);
        final copy = jsonDecode(jsonEncode(src)) as Map<String, dynamic>;
        copy['id'] = dup.value;
        copy.addAll(copyAs);
        list.add(copy);
      }
      for (final entry in list) {
        final state = entry['characterState'];
        if (state is! Map<String, dynamic>) continue;
        final changes = heroes[entry['id']];
        if (changes != null) state.addAll(changes);
        if (official) {
          state.remove('heartAttacks');
          state.remove('heartAttacksBefore');
          state.remove('littleHeartAttacks');
          state.remove('littleHeartAttacksBefore');
        }
      }
      if (round != null) json['roundState'] = round;
      return jsonEncode(json);
    }

    void sendPhoneUpdate(
        WireClient phone, StateEnvelope init, String state) {
      phone.send(StateEnvelope(
        index: init.index + 1,
        description: 'phone action',
        eventJson: '{"type":"none"}',
        state: state,
      ).encode());
    }

    Character hostHero(String id) => _serverGameState.currentList
        .whereType<Character>()
        .firstWhere((c) => c.id == id);
    int hostMajor(String id) => hostHero(id).characterState.heartAttacks.value;
    int hostLittle(String id) =>
        hostHero(id).characterState.littleHeartAttacks.value;

    test('an official update dropping a hero to 0 is counted, saved and sent',
        () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await official.doInit();
      await phone.doInit();
      await greet(phone, 'off-major-1');

      sendPhoneUpdate(official, init,
          phoneState(init, heroes: {victim: {'health': 0}}, official: true));

      // The greeted phone witnesses both the forwarded state (written with
      // the host's new count, since the command ran before the save) and
      // the announced line.
      StateEnvelope? forwarded;
      String? toast;
      for (var i = 0; i < 5 && (forwarded == null || toast == null); i++) {
        final raw = await phone.receive(timeout: const Duration(seconds: 2));
        final line = SwerskiToast.parse(raw);
        if (line != null) {
          toast = line;
          continue;
        }
        final envelope = StateEnvelope.tryDecode(raw);
        if (envelope != null && envelope.index == init.index + 1) {
          forwarded = envelope;
        }
      }
      expect(toast, contains('Blinkblade'));
      expect(_serverGameState.heartAttackToast.value, equals(toast));
      expect(hostMajor(victim), equals(1));
      final sentJson = jsonDecode(forwarded!.state) as Map<String, dynamic>;
      final sentHero = (sentJson['currentList'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == victim);
      expect(
          (sentHero['characterState'] as Map<String, dynamic>)['heartAttacks'],
          equals(1),
          reason: 'the state sent on to the other clients carries the count');
    });

    test('a host Undo removes the counted heart attack', () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      final init = await official.doInit();

      sendPhoneUpdate(official, init,
          phoneState(init, heroes: {victim: {'health': 0}}, official: true));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(hostMajor(victim), equals(1));

      _testServer.undoState();
      expect(hostMajor(victim), equals(0),
          reason: 'the count was written before the save, so Undo takes it '
              'back with everything else from that update');
    });

    test('a Swerski phone that counts itself is not counted again', () async {
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(phone.close);
      final init = await phone.doInit();
      await greet(phone, 'off-no-dbl');

      // The Swerski snapshot carries its own heartAttacks: 1 — the host
      // sees the key and leaves the counting to the phone.
      sendPhoneUpdate(phone, init,
          phoneState(init, heroes: {victim: {'health': 0, 'heartAttacks': 1}}));

      expect(await receiveToast(phone), contains('Blinkblade'));
      expect(hostMajor(victim), equals(1));
    });

    test('host with Heart attacks off does not count for the official app',
        () async {
      final oldOff = getIt<Settings>().heartAttacks.value;
      getIt<Settings>().heartAttacks.value = false;
      addTearDown(() => getIt<Settings>().heartAttacks.value = oldOff);
      final victim = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await official.doInit();
      await phone.doInit();
      await greet(phone, 'off-off-1');

      sendPhoneUpdate(official, init,
          phoneState(init, heroes: {victim: {'health': 0}}, official: true));

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
      expect(hostMajor(victim), equals(0));
    });

    test('an official long rest through a Draw earns the little count',
        () async {
      final hero = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await official.doInit();
      await phone.doInit();
      await greet(phone, 'off-little-1');

      sendPhoneUpdate(
          official,
          init,
          phoneState(init,
              heroes: {hero: {'initiative': 99}},
              round: RoundState.playTurns.index,
              official: true));

      final toast = await receiveToast(phone);
      expect(toast, contains('Blinkblade'));
      expect(toast, endsWith('(long rest).'));
      expect(hostLittle(hero), equals(1));
      expect(hostMajor(hero), equals(0));
    });

    test('an official long rest without a Draw earns nothing', () async {
      final hero = addHero('Blinkblade');
      addHero('Banner Spear');
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await official.doInit();
      await phone.doInit();
      await greet(phone, 'off-little-2');

      // The Draw did not happen: the round is still choosing initiative.
      sendPhoneUpdate(official, init,
          phoneState(init,
              heroes: {hero: {'initiative': 99}}, official: true));

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
      expect(hostLittle(hero), equals(0));
    });

    test('an official Objective dropped to 0 and a hero added dead gain '
        'nothing', () async {
      final src = addHero('Blinkblade');
      addHero('Banner Spear');
      _serverGameState.action(AddCharacterCommand('Objective', 'na', 'guard', 1));
      final objectiveId = _serverGameState.currentList
          .whereType<Character>()
          .firstWhere(
              (c) => GameMethods.isObjectiveOrEscort(c.characterClass))
          .id;
      addTearDown(() {
        final gone = _serverGameState.currentList
            .whereType<Character>()
            .where((c) => c.id == 'Hail' || c.id == objectiveId)
            .toList();
        if (gone.isNotEmpty) {
          _serverGameState.action(
              RemoveCharacterCommand(gone, gameState: _serverGameState));
        }
      });
      final official = await WireClient.connect('127.0.0.1', _serverPort);
      final phone = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(official.close);
      addTearDown(phone.close);
      final init = await official.doInit();
      await phone.doInit();
      await greet(phone, 'off-excluded-1');

      // A copy of the table's Blinkblade under a fresh id: the host has
      // never seen it, so its fall is nobody's heart attack. The Objective
      // is on the before table but not watched. Both dropped to 0, so a
      // wrong count would show up here.
      sendPhoneUpdate(
          official,
          init,
          phoneState(
              init,
              duplicate: {src: 'ghost-1'},
              copyAs: {'characterClass': 'Hail', 'edition': 'Mercenary Packs'},
              heroes: {
                'ghost-1': {'health': 0},
                objectiveId: {'health': 0},
              },
              official: true));

      expect(await receiveToast(phone), isNull);
      expect(_serverGameState.heartAttackToast.value, isEmpty);
      // A loaded Character takes its id from its class, not the JSON 'id':
      // the duplicate is the Hail on the host's table. firstWhere asserts
      // it landed at all.
      expect(
          _serverGameState.currentList
              .whereType<Character>()
              .firstWhere((c) => c.id == 'Hail')
              .characterState
              .heartAttacks
              .value,
          equals(0));
      expect(hostMajor(objectiveId), equals(0));
      expect(hostMajor(src), equals(0));
    });
  });

  // ── Command-index sync (issue #10) ────────────────────────────────────────────

  group('command-index sync', () {
    test(
        'conflicting client action triggers Mismatch carrying the current index',
        () async {
      final clientA = await WireClient.connect('127.0.0.1', _serverPort);
      final clientB = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(clientA.close);
      addTearDown(clientB.close);

      final initA = await clientA.doInit();
      await clientB.doInit();

      final firstIndex = initA.index + 1;

      // Client A wins: its action is accepted at firstIndex.
      clientA.send(StateEnvelope(
        index: firstIndex,
        description: 'ActionA',
        eventJson: '{"type":"none"}',
        state: initA.state,
      ).encode());

      // Wait for B to receive the forwarded state from A's action so we know
      // the server has processed A before B sends its conflicting message.
      final forwarded = StateEnvelope.tryDecode(await clientB.receive());
      expect(forwarded?.index, equals(firstIndex));

      // Client B now sends an action at the *same* (already-consumed) index.
      clientB.send(StateEnvelope(
        index: firstIndex, // stale — conflict
        description: 'ActionB_conflict',
        eventJson: '{"type":"none"}',
        state: initA.state,
      ).encode());

      final rawMismatch = await clientB.receive();
      expect(rawMismatch, startsWith('Mismatch:'),
          reason: 'Server must reject the conflicting action');

      // The Mismatch payload must be a valid envelope carrying the current index
      // so the client can re-sync without manual intervention.
      final mismatch =
          StateEnvelope.tryDecode(rawMismatch.substring('Mismatch:'.length));
      expect(mismatch, isNotNull);
      expect(mismatch!.index, equals(firstIndex),
          reason: 'Mismatch must carry the server\'s current index');
      expect(mismatch.state, isNotEmpty,
          reason: 'Mismatch must carry current state for re-sync');
    });

    test('action with index lower than server index triggers Mismatch',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);

      final initEnvelope = await client.doInit();

      // Advance the server by two server-side actions.
      _serverGameState.action(SetLevelCommand(4, null));
      _serverGameState.action(SetLevelCommand(5, null));
      // Consume the two pushed updates.
      await client.receive();
      await client.receive();

      // Now send an action at an old index (below current server index).
      client.send(StateEnvelope(
        index: initEnvelope.index + 1, // server is at initEnvelope.index + 2
        description: 'OldAction',
        eventJson: '{"type":"none"}',
        state: initEnvelope.state,
      ).encode());

      final rawMismatch = await client.receive();
      expect(rawMismatch, startsWith('Mismatch:'));
      final mismatch =
          StateEnvelope.tryDecode(rawMismatch.substring('Mismatch:'.length));
      expect(mismatch?.index, equals(_serverGameState.commandIndex.value));
    });

    test('client can re-sync after Mismatch and retry at correct index',
        () async {
      final client = await WireClient.connect('127.0.0.1', _serverPort);
      // Observer witnesses the retry being forwarded — more reliable than
      // polling commandIndex.value with a sleep.
      final observer = await WireClient.connect('127.0.0.1', _serverPort);
      addTearDown(client.close);
      addTearDown(observer.close);

      await client.doInit();
      await observer.doInit();

      // Advance server index out of band so client's next action is stale.
      _serverGameState.action(SetLevelCommand(5, null));
      final serverIndex = _serverGameState.commandIndex.value;
      // Consume pushed updates.
      await client.receive();
      await observer.receive();

      // Client sends at a stale index (already consumed by the server action).
      client.send(StateEnvelope(
        index: serverIndex, // same as current → rejected
        description: 'StaleAction',
        eventJson: '{"type":"none"}',
        state: '{}',
      ).encode());

      final rawMismatch = await client.receive();
      expect(rawMismatch, startsWith('Mismatch:'));
      final mismatch =
          StateEnvelope.tryDecode(rawMismatch.substring('Mismatch:'.length))!;
      expect(mismatch.index, equals(serverIndex));

      // Re-sync: retry the action at mismatch.index + 1 using the mismatch state.
      client.send(StateEnvelope(
        index: mismatch.index + 1,
        description: 'RetriedAction',
        eventJson: '{"type":"none"}',
        state: mismatch.state,
      ).encode());

      // The observer must receive the forwarded update — confirms the server
      // accepted the retried action.
      final forwarded = StateEnvelope.tryDecode(await observer.receive());
      expect(forwarded, isNotNull);
      expect(forwarded!.index, equals(mismatch.index + 1),
          reason: 'Server should have accepted the retried action at the '
              'correct index');
    });
  });
}
