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

      verifyInOrder([
        communication.sendToAll(
            'init protocolVersion:${GameServer.protocolVersion}'),
        communication.sendToAll(SwerskiGreeting.encode(
            id: 'device-1', name: 'Table phone', plays: ['play-1'])),
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

  _FakeHost() {
    when(settings.lastKnownPort).thenReturn('4567');
    when(settings.locale).thenReturn(ValueNotifier<String>('en'));
    when(settings.client)
        .thenReturn(ValueNotifier<ClientState>(ClientState.disconnected));
    when(settings.deviceId).thenReturn('device-1');
    when(settings.deviceName).thenReturn(ValueNotifier<String>(''));
    when(settings.devicePlays).thenReturn(ValueNotifier<List<String>>([]));
    when(network.networkMessage).thenReturn(ValueNotifier<String>(''));
    when(network.networkMessageIsError).thenReturn(ValueNotifier<bool>(false));
    when(network.hostGreeted).thenReturn(hostGreeted);
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

  void push(String message) {
    final onData = verify(communication.listen(captureAny, any, any))
        .captured
        .last as void Function(Uint8List);
    onData(utf8.encode(message));
  }
}

void Function() _overridePrint(void Function() testFn) => () {
      var spec = ZoneSpecification(print: (_, __, ___, String msg) {
        _log.add(msg);
      });
      return Zone.current.fork(specification: spec).run<void>(testFn);
    };
