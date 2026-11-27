// ignore_for_file: no-magic-number, avoid-late-keyword, avoid-top-level-members-in-tests, prefer-match-file-name, avoid-non-null-assertion

import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/adjust_heart_attacks_command.dart';
import 'package:frosthaven_assistant/Resource/commands/remove_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_level_command.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/communication.dart';
import 'package:frosthaven_assistant/services/network/connection.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/server.dart';
import 'package:frosthaven_assistant/services/network/superfan/greeting.dart';
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
      await client.receive(); // ack

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
