// ignore_for_file: missing-test-assertion

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:fluent_assertions/fluent_assertions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/client.dart';
import 'package:frosthaven_assistant/services/network/communication.dart';
import 'package:frosthaven_assistant/services/network/connection.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/superfan/fans.dart';
import 'package:frosthaven_assistant/services/network/superfan/greeting.dart';
import 'package:frosthaven_assistant_server/game_server.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'client_test.mocks.dart';

Client _sut = Client();
final _getIt = GetIt.instance;
const _address = '127.0.0.1';

@GenerateNiceMocks([
  MockSpec<Communication>(),
  MockSpec<Connection>(),
  MockSpec<Network>(),
  MockSpec<Settings>(),
  MockSpec<Socket>(),
  MockSpec<ValueNotifier<String>>(as: Symbol('MockValueNotifierString')),
  MockSpec<ValueNotifier<ClientState>>(
      as: Symbol('MockValueNotifierClientState'))
])
final _connection = MockConnection();
final _gameState = GameState(communication: _communication);
final _communication = MockCommunication();
final _network = MockNetwork();
final _settings = MockSettings();
final _valueNotifierString = MockValueNotifierString();
final _valueNotifierClientState = MockValueNotifierClientState();

List<String> _log = [];

void main() {
  setUpAll(() {
    when(_settings.lastKnownPort).thenReturn('0000');
    when(_settings.locale).thenReturn(ValueNotifier<String>('en'));
    when(_settings.deviceId).thenReturn('device-0');
    when(_settings.deviceName).thenReturn(ValueNotifier<String>(''));
    when(_settings.devicePlays).thenReturn(ValueNotifier<List<String>>([]));
    when(_network.networkMessage).thenReturn(ValueNotifier<String>(''));
    when(_network.networkMessageIsError).thenReturn(ValueNotifier<bool>(false));
    when(_network.hostGreeted).thenReturn(ValueNotifier<bool>(false));
    when(_network.superFans).thenReturn(ValueNotifier<List<SwerskiFan>>(const []));
    when(_network.superFanJoined)
        .thenReturn(ValueNotifier<SwerskiFan?>(null));
    _getIt.registerFactory<Connection>(() => _connection);
    _getIt.registerFactory<GameState>(() => _gameState);
    _getIt.registerFactory<Communication>(() => _communication);
    _getIt.registerFactory<Network>(() => _network);
    _getIt.registerFactory<Settings>(() => _settings);
  });

  test('connect creates client connection with server', _overridePrint(() {
    // arrange
    when(_network.networkMessage).thenReturn(_valueNotifierString);
    when(_settings.client).thenReturn(_valueNotifierClientState);

    // act
    _sut.connect(_address);

    // assert
    _log.any((element) => element.contains('port nr: 0')).shouldBeTrue();
  }));

  // Regression guard for a bug observed on device: after the app resumes from
  // background, the socket has been dropped and reconnect-on-resume opens a new
  // one — but the previous connection's pending ping `Future.delayed` thaws and
  // latches onto the replacement, so two chains ping the same socket forever.
  // Beyond the doubled traffic they race on the responsive flag, which breaks
  // the unresponsive-server watchdog.
  test('a ping scheduled by a replaced connection does not keep pinging', () {
    final connection = MockConnection();
    final communication = MockCommunication();
    final network = MockNetwork();
    final settings = MockSettings();
    final socket = MockSocket();

    when(settings.lastKnownPort).thenReturn('4567');
    when(settings.locale).thenReturn(ValueNotifier<String>('en'));
    when(settings.client)
        .thenReturn(ValueNotifier<ClientState>(ClientState.disconnected));
    when(settings.deviceId).thenReturn('device-1');
    when(settings.deviceName).thenReturn(ValueNotifier<String>(''));
    when(settings.devicePlays).thenReturn(ValueNotifier<List<String>>([]));
    when(network.networkMessage).thenReturn(ValueNotifier<String>(''));
    when(network.networkMessageIsError).thenReturn(ValueNotifier<bool>(false));
    when(network.hostGreeted).thenReturn(ValueNotifier<bool>(false));
    when(network.superFans).thenReturn(ValueNotifier<List<SwerskiFan>>(const []));
    when(network.superFanJoined).thenReturn(ValueNotifier<SwerskiFan?>(null));
    when(network.appInBackground).thenReturn(false);
    when(socket.remoteAddress).thenReturn(InternetAddress('127.0.0.1'));
    when(socket.remotePort).thenReturn(4567);
    when(connection.connect(any, any)).thenAnswer((_) async => socket);
    when(connection.established()).thenReturn(true);

    final client = Client(
      gameState: _gameState,
      communication: communication,
      connection: connection,
      network: network,
      settings: settings,
    );

    fakeAsync((async) {
      client.connect(_address); // chain A, would ping at t=12s
      async.elapse(const Duration(seconds: 6));

      // The socket dies while the app is away; the resume path reconnects.
      final onDone = verify(communication.listen(any, any, captureAny))
          .captured
          .last as void Function()?;
      onDone?.call();
      client.connect(_address); // chain B, pings at t=18s
      async.elapse(const Duration(seconds: 14)); // to t=20s

      // Only chain B is alive, and it has pinged once, at t=18s.
      verify(communication.sendToAll('ping')).called(1);

      // Before the fix chain A also fired, at t=12s, and cleared the responsive
      // flag out from under chain B — so chain B read a pong it had no reason
      // to expect yet and force-disconnected a perfectly healthy connection.
      settings.client.value.shouldBe(ClientState.connected);
    });
  });

  test('client greets the host right after init', () {
    final connection = MockConnection();
    final communication = MockCommunication();
    final network = MockNetwork();
    final settings = MockSettings();
    final socket = MockSocket();

    when(settings.lastKnownPort).thenReturn('4567');
    when(settings.locale).thenReturn(ValueNotifier<String>('en'));
    when(settings.client)
        .thenReturn(ValueNotifier<ClientState>(ClientState.disconnected));
    when(settings.deviceId).thenReturn('device-1');
    when(settings.deviceName).thenReturn(ValueNotifier<String>('Table phone'));
    when(settings.devicePlays)
        .thenReturn(ValueNotifier<List<String>>(['play-1']));
    when(network.networkMessage).thenReturn(ValueNotifier<String>(''));
    when(network.networkMessageIsError).thenReturn(ValueNotifier<bool>(false));
    when(network.hostGreeted).thenReturn(ValueNotifier<bool>(false));
    when(network.superFans).thenReturn(ValueNotifier<List<SwerskiFan>>(const []));
    when(network.superFanJoined).thenReturn(ValueNotifier<SwerskiFan?>(null));
    when(network.appInBackground).thenReturn(false);
    when(socket.remoteAddress).thenReturn(InternetAddress('127.0.0.1'));
    when(socket.remotePort).thenReturn(4567);
    when(connection.connect(any, any)).thenAnswer((_) async => socket);
    when(connection.established()).thenReturn(true);

    final client = Client(
      gameState: _gameState,
      communication: communication,
      connection: connection,
      network: network,
      settings: settings,
    );

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      // First greeting of the app run asks to be prompted (B2).
      verifyInOrder([
        communication.sendToAll(
            'init protocolVersion:${GameServer.protocolVersion}'),
        communication.sendToAll(SwerskiGreeting.encode(
            id: 'device-1',
            name: 'Table phone',
            plays: ['play-1'],
            asking: true)),
      ]);

      // A throw from the greeting must not swallow the rest of the connect
      // sequence: the zone guard would eat it and only ping/listen would be
      // visibly missing.
      verify(communication.listen(any, any, any)).called(1);
      async.elapse(const Duration(seconds: 13));
      verify(communication.sendToAll('ping')).called(1);
    });
  });

  test('the host ack marks the host greeted', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.hostGreeted.value.shouldBeFalse();

      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.hostGreeted.value.shouldBeTrue();
    });
  });

  test('swerski messages that are not the ack are ignored', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      // A greeting aimed at the client (it is the host's turn to greet, so
      // this is protocol noise) must not flip anything.
      host.push(
          'S3nD:${SwerskiGreeting.encode(id: 'other-1', name: 'Tablet')}[EOM]');
      host.hostGreeted.value.shouldBeFalse();
    });
  });

  test('disconnect clears hostGreeted', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.hostGreeted.value.shouldBeTrue();

      client.disconnect(null);
      host.hostGreeted.value.shouldBeFalse();
    });
  });

  test('a new connect starts with hostGreeted false', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.hostGreeted.value.shouldBeTrue();

      // Reconnect without an intervening disconnect: the new connection has
      // not been greeted yet, whatever the previous one was told.
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.hostGreeted.value.shouldBeFalse();
    });
  });

  test('a fans message fills the SuperNetwork list', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.superFans.value.shouldBeEmpty();

      host.push('S3nD:${SwerskiFan.encodeFans(const [
        SwerskiFan(
            id: 'host-1', name: 'Tablet host', plays: ['blinkblade@1'], host: true),
        SwerskiFan(id: 'dev-2', name: 'Hatchet'),
      ])}[EOM]');

      final fans = host.superFans.value;
      fans.length.shouldBe(2);
      fans.first.id.shouldBeEqualTo('host-1');
      fans.first.host.shouldBeTrue();
      fans.first.plays.shouldBeEqualTo(['blinkblade@1']);
      fans.last.name.shouldBeEqualTo('Hatchet');
    });
  });

  test('an empty fans message empties the list', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'host-1', host: true),
      ])}[EOM]');
      host.superFans.value.length.shouldBe(1);

      host.push('S3nD:${SwerskiFan.encodeFans(const [])}[EOM]');
      host.superFans.value.shouldBeEmpty();
    });
  });

  test('a joined message names the new fan for the banner', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      host.push('S3nD:${SwerskiFan.encodeJoined(
          const SwerskiFan(id: 'dev-9', name: 'Hatchet', plays: ['blinkblade@1']))}[EOM]');
      // The banner needs the plays too, so the notifier carries the fan.
      host.superFanJoined.value?.name.shouldBeEqualTo('Hatchet');
      host.superFanJoined.value?.plays.shouldBeEqualTo(['blinkblade@1']);
    });
  });

  test('malformed fans and joined messages change nothing', () {
    final host = _FakeHost();
    final client = host.client();
    final prefix = SwerskiGreeting.encode(id: 'x').substring(0, 8);

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'host-1', host: true),
      ])}[EOM]');
      host.superFanJoined.value = const SwerskiFan(id: 'shown', name: 'already shown');

      for (final junk in [
        '${prefix}fans {not json}',
        '${prefix}fans',
        '${prefix}joined {}',
      ]) {
        host.push('S3nD:$junk[EOM]');
      }

      host.superFans.value.length.shouldBe(1);
      host.superFanJoined.value?.name.shouldBeEqualTo('already shown');
    });
  });

  test('disconnect clears the SuperNetwork list', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'host-1', host: true),
      ])}[EOM]');
      host.push('S3nD:${SwerskiFan.encodeJoined(
          const SwerskiFan(id: 'dev-2', name: 'Hatchet'))}[EOM]');

      client.disconnect(null);
      host.superFans.value.shouldBeEmpty();
      // A banner nobody got to show must not fire on the next connection.
      expect(host.superFanJoined.value, isNull);
    });
  });

  test('a new connect starts with an empty SuperNetwork list', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiFan.encodeFans(const [
        SwerskiFan(id: 'host-1', host: true),
      ])}[EOM]');

      // Reconnect without an intervening disconnect: whatever the previous
      // host advertised is stale until the new one says otherwise.
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.superFans.value.shouldBeEmpty();
    });
  });

  test('the greeting asks to be prompted while the question is pending', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      final greeting = SwerskiGreeting.parse(host.onlyGreetingMessage());
      greeting?.id.shouldBeEqualTo('device-1');
      (greeting?.asking ?? false).shouldBeTrue();
    });
  });

  test('a greeting stops asking once the question was asked', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.markSuperFanAsked();
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      // Byte-identical to the plain greeting: no asking key at all.
      host.onlyGreetingMessage()
          .shouldBeEqualTo(SwerskiGreeting.encode(id: 'device-1'));
    });
  });

  test('the ack requests the choice dialog', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.superFanChoiceRequested.value.shouldBeFalse();

      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.superFanChoiceRequested.value.shouldBeTrue();
    });
  });

  test('an ack does not request the dialog after the question was asked', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.markSuperFanAsked();
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.superFanChoiceRequested.value.shouldBeFalse();
    });
  });

  test('marking the question asked clears a pending request', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.superFanChoiceRequested.value.shouldBeTrue();

      // The dialog is opening, so the request is consumed. (A game with no
      // characters clears only the notifier without marking, so the question
      // stays unasked.)
      client.markSuperFanAsked();
      host.superFanChoiceRequested.value.shouldBeFalse();
    });
  });

  test('nothing to ask re-sends the normal greeting, keeps the question', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.superFanChoiceRequested.value.shouldBeTrue();

      // The trigger found no characters: the host gets a normal greeting so it
      // can announce the device after all, and the question stays unasked.
      clearInteractions(host.communication);
      client.superFanNothingToAsk();

      host.superFanChoiceRequested.value.shouldBeFalse();
      verify(host.communication.sendToAll(SwerskiGreeting.encode(
              id: 'device-1')))
          .called(1);

      // Still unasked: the next ack requests the dialog again.
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');
      host.superFanChoiceRequested.value.shouldBeTrue();
    });
  });

  test('nothing to ask sends nothing before the ack', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      clearInteractions(host.communication);
      client.superFanNothingToAsk();

      host.superFanChoiceRequested.value.shouldBeFalse();
      verifyNever(host.communication.sendToAll(SwerskiGreeting.encode(
              id: 'device-1')));
    });
  });

  test('saving the choice stores it, saves settings and re-sends the greeting',
      () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');

      // connect() sent and saved too; count only what the choice causes.
      clearInteractions(host.settings);
      clearInteractions(host.communication);
      client.saveSuperFanPlays(['blinkblade@1']);

      host.devicePlays.value.shouldBeEqualTo(['blinkblade@1']);
      verify(host.settings.saveToDisk()).called(1);
      verify(host.communication.sendToAll(SwerskiGreeting.encode(
              id: 'device-1', plays: ['blinkblade@1'])))
          .called(1);
    });
  });

  test('saving the choice does not send while the host is not greeted', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      // No ack: an official host, or no host at all. Nothing to re-greet.
      client.saveSuperFanPlays(['blinkblade@1']);

      host.devicePlays.value.shouldBeEqualTo(['blinkblade@1']);
      verifyNever(host.communication.sendToAll(SwerskiGreeting.encode(
              id: 'device-1', plays: ['blinkblade@1'])));
    });
  });

  test('a new name is re-sent when the settings menu closed', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));
      host.push('S3nD:${SwerskiGreeting.encodeAck()}[EOM]');

      clearInteractions(host.communication);
      host.deviceName.value = 'Kitchen tablet';
      client.reannounceSuperFanIdentity();

      verify(host.communication.sendToAll(SwerskiGreeting.encode(
              id: 'device-1', name: 'Kitchen tablet')))
          .called(1);
    });
  });

  test('a new name sends nothing before the ack', () {
    final host = _FakeHost();
    final client = host.client();

    fakeAsync((async) {
      client.connect(_address);
      async.elapse(const Duration(milliseconds: 50));

      clearInteractions(host.communication);
      host.deviceName.value = 'Kitchen tablet';
      client.reannounceSuperFanIdentity();

      verifyNever(host.communication.sendToAll(SwerskiGreeting.encode(
              id: 'device-1', name: 'Kitchen tablet')));
    });
  });
}

/// A wired-up set of local mocks for one client: `Network.hostGreeted` is a
/// real notifier, and [push] feeds a framed message to the listen callback the
/// client registered on the communication mock.
class _FakeHost {
  final connection = MockConnection();
  final communication = MockCommunication();
  final network = MockNetwork();
  final settings = MockSettings();
  final socket = MockSocket();
  final hostGreeted = ValueNotifier<bool>(false);
  final superFans = ValueNotifier<List<SwerskiFan>>(const []);
  final superFanJoined = ValueNotifier<SwerskiFan?>(null);
  final superFanChoiceRequested = ValueNotifier<bool>(false);
  final devicePlays = ValueNotifier<List<String>>([]);
  final deviceName = ValueNotifier<String>('');

  _FakeHost() {
    when(settings.lastKnownPort).thenReturn('4567');
    when(settings.locale).thenReturn(ValueNotifier<String>('en'));
    when(settings.client)
        .thenReturn(ValueNotifier<ClientState>(ClientState.disconnected));
    when(settings.deviceId).thenReturn('device-1');
    when(settings.deviceName).thenReturn(deviceName);
    when(settings.devicePlays).thenReturn(devicePlays);
    when(network.networkMessage).thenReturn(ValueNotifier<String>(''));
    when(network.networkMessageIsError).thenReturn(ValueNotifier<bool>(false));
    when(network.hostGreeted).thenReturn(hostGreeted);
    when(network.superFans).thenReturn(superFans);
    when(network.superFanJoined).thenReturn(superFanJoined);
    when(network.superFanChoiceRequested).thenReturn(superFanChoiceRequested);
    when(network.appInBackground).thenReturn(false);
    when(socket.remoteAddress).thenReturn(InternetAddress('127.0.0.1'));
    when(socket.remotePort).thenReturn(4567);
    when(connection.connect(any, any)).thenAnswer((_) async => socket);
    when(connection.established()).thenReturn(true);
  }

  Client client() => Client(
        gameState: _gameState,
        communication: communication,
        connection: connection,
        network: network,
        settings: settings,
      );

void Function(Uint8List)? _onData;

  void push(String message) {
    // The listen invocation can only be verified once, so keep the captured
    // callback for later pushes.
    final onData = _onData ??= verify(communication.listen(captureAny, any, any))
        .captured
        .last as void Function(Uint8List);
    onData(utf8.encode(message));
  }

  /// The single Swerski greeting this client sent. Verification consumes the
  /// send calls, so callers get either this or a targeted `verify` — not both.
  String onlyGreetingMessage() {
    final sent = verify(communication.sendToAll(captureAny))
        .captured
        .cast<String>()
        .where((m) =>
            SwerskiGreeting.isSwerskiMessage(m) && !SwerskiGreeting.isAck(m))
        .toList();
    expect(sent.length, equals(1));
    return sent.single;
  }
}

void Function() _overridePrint(void Function() testFn) => () {
      var spec = ZoneSpecification(print: (_, __, ___, String msg) {
        _log.add(msg);
      });
      return Zone.current.fork(specification: spec).run<void>(testFn);
    };
