import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:frosthaven_assistant/services/network/communication.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant_server/game_server.dart';

import '../../Resource/game_event.dart';
import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../l10n/app_localizations.dart';
import '../service_locator.dart';
import 'connection.dart';
import 'superfan/fans.dart';
import 'superfan/greeting.dart';
import 'superfan/toast.dart';

class Client {
  String _leftOverMessage = "";
  bool _serverResponsive = true;

  // Consecutive ping windows the server has failed to answer. A single missed
  // pong is usually just a transient network hiccup, so tolerate a few before
  // treating the server as gone — dropping on the first miss disconnected
  // players too eagerly on flaky wifi.
  int _missedPongs = 0;
  static const int _maxMissedPongs = 2;

  bool _connectCancelled = false;

  /// Whether the "who do you play?" dialog has been offered during this app
  /// run. In memory only — a fresh app start asks again.
  bool _askedThisRun = false;
  final GameState _gameState;
  final Communication _communication;
  final Connection _connection;
  final Network _network;
  final Settings _settings;

  AppLocalizations get _l10n {
    final code = _settings.locale.value;
    try {
      return lookupAppLocalizations(Locale(code));
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  Client({
    GameState? gameState,
    Communication? communication,
    Connection? connection,
    Network? network,
    Settings? settings,
  }) : _gameState = gameState ?? getIt<GameState>(),
       _communication = communication ?? getIt<Communication>(),
       _connection = connection ?? getIt<Connection>(),
       _network = network ?? getIt<Network>(),
       _settings = settings ?? getIt<Settings>();

  void _setNetworkMessage(String msg, {bool isError = false}) {
    _network.networkMessageIsError.value = isError;
    _network.networkMessage.value = msg;
  }

  Future<void> connect(String address) async {
    _serverResponsive = true;
    _missedPongs = 0;
    _connectCancelled = false;
    _network.hostGreeted.value = false;
    _network.superFans.value = const [];
    _network.superFanJoined.value = null;
    _pingGeneration++;
    // Bumping the generation retires any chain from a previous connection, so
    // the old chain can no longer stand in for this one — clear the re-entrancy
    // guard too, or a reconnect that happens without an intervening _cleanup()
    // would end up with no ping chain at all.
    _pinging = false;
    try {
      int port = int.parse(_settings.lastKnownPort);
      debugPrint("port nr: ${port.toString()}");
      final socket = await _connection.connect(address, port);
      runZonedGuarded(
        () {
          _settings.client.value = ClientState.connected;
          String info = _l10n.clientConnectedTo(
              '${socket.remoteAddress.address}:${socket.remotePort}');
          debugPrint(info);
          _gameState.clearLocalCommands();
          _setNetworkMessage(info);
          if (Platform.isAndroid || Platform.isIOS) {
            _settings.connectClientOnStartup = true;
          }
          _settings.saveToDisk();
          _send("init protocolVersion:${GameServer.protocolVersion}");
          _sendSuperFanGreeting(asking: !_askedThisRun);
          _sendPing();
          _listen();
        },
        (error, stack) {
          debugPrint('Client zone error: $error\n$stack');
          _setNetworkMessage(_l10n.clientError(error.toString()), isError: true);
        },
      );
    } catch (error) {
      if (_connectCancelled) {
        debugPrint("client connect cancelled by user");
        _setNetworkMessage(_l10n.connectionCancelled);
      } else {
        debugPrint("client error: $error");
        _setNetworkMessage(_l10n.clientError(error.toString()), isError: true);
      }
      _settings.client.value = ClientState.disconnected;
      _settings.connectClientOnStartup = false;
      _settings.saveToDisk();
      _connectCancelled = false;
    }
  }

  /// Aborts an in-progress connection attempt started via [connect]. The
  /// pending attempt then fails fast and is reported as cancelled rather than
  /// as an error.
  void cancelConnect() {
    _connectCancelled = true;
    _connection.cancelConnect();
  }

  void _sendSuperFanGreeting({bool asking = false}) {
    _send(SwerskiGreeting.encode(
      id: _settings.deviceId,
      name: _settings.deviceName.value,
      plays: _settings.devicePlays.value,
      asking: asking,
    ));
  }

  /// The choice dialog was shown: the question is asked for this app run and
  /// will not come up again until the app restarts. A game with no characters
  /// must not call this — the question stays unasked for the next connection.
  void markSuperFanAsked() {
    _askedThisRun = true;
    _network.superFanChoiceRequested.value = false;
  }

  /// The picker will not produce an answer — the game has no characters to
  /// ask about, or the player dismissed it without OK so the stored choice
  /// stands. A greeted host gets the normal greeting with that choice, so it
  /// announces this device instead of waiting for one that never comes.
  void superFanNothingToAsk() {
    _network.superFanChoiceRequested.value = false;
    if (_settings.client.value == ClientState.connected &&
        _network.hostGreeted.value) {
      _sendSuperFanGreeting();
    }
  }

  /// Re-sends this device's greeting after its name changed in Settings: the
  /// other devices learn the new name when the menu closes, not per keystroke.
  /// A rename is not a join, so no banner follows it.
  void reannounceSuperFanIdentity() {
    if (_settings.client.value == ClientState.connected &&
        _network.hostGreeted.value) {
      _sendSuperFanGreeting();
    }
  }

  /// Stores what this device plays and saves settings; while connected to a
  /// greeted host, re-sends the greeting so the SuperNetwork list picks the
  /// change up right away.
  void saveSuperFanPlays(List<String> plays) {
    _settings.devicePlays.value = plays;
    _settings.saveToDisk();
    if (_settings.client.value == ClientState.connected &&
        _network.hostGreeted.value) {
      _sendSuperFanGreeting();
    }
  }

  bool _pinging =
      false; //to not restart this ping sub process, if one is running

  /// Bumped whenever a connection starts or ends. A scheduled ping captures the
  /// value it was created under and drops out if it no longer matches, so a
  /// pending [Future.delayed] left over from a previous connection cannot
  /// attach itself to the next one.
  ///
  /// Without this, resuming from background produces two concurrent ping chains
  /// on one socket: the thawed chain from the old connection plus the one
  /// started by reconnect-on-resume. Beyond the doubled traffic, the two race
  /// on [_serverResponsive] — one clears it, the other's pong sets it — which
  /// makes the unresponsive-server watchdog unable to fire correctly at all.
  int _pingGeneration = 0;

  void _sendPing() {
    if (_connection.established() &&
        _settings.client.value == ClientState.connected &&
        !_pinging) {
      _pinging = true;
      final int generation = _pingGeneration;
      Future.delayed(const Duration(seconds: 12), () {
        if (generation != _pingGeneration) {
          return; //belongs to a connection that has since been replaced
        }
        _pinging = false;
        // Skip the ping while backgrounded: waking the radio every 12s is
        // disproportionately expensive on battery, and the watchdog below
        // would otherwise fire on a socket the OS has frozen and force a
        // spurious "server unresponsive" disconnect. Reschedule regardless so
        // the chain is still alive when the app comes back to the foreground.
        if (_network.appInBackground) {
          _serverResponsive = true;
          _sendPing();
          return;
        }
        if (_serverResponsive) {
          _missedPongs = 0;
        } else {
          _missedPongs++;
          if (_missedPongs >= _maxMissedPongs) {
            disconnect(_l10n.serverUnresponsive);
            return;
          }
        }
        _communication.sendToAll("ping");
        _serverResponsive = false; //set back to true when get response
        _sendPing();
      });
    }
  }

  void _listen() {
    // listen for responses from the server
    try {
      _communication.listen(onListenData, onListenError, onListenDone);
    } catch (error) {
      debugPrint(error.toString());
      //_socket?.destroy();
      _setNetworkMessage(_l10n.clientListenError(error.toString()), isError: true);
      //_cleanup();
    }
  }

  void onListenDone() {
    debugPrint('Lost connection to server.');
    if (_serverResponsive) {
      _setNetworkMessage(
          '${_network.networkMessage.value} ${_l10n.lostConnectionToServer}',
          isError: true);
    }
    _connection.removeAll();
    _cleanup();
  }

  void onListenError(Object error) {
    debugPrint('Client error: ${error.toString()}');
    _setNetworkMessage(_l10n.clientError(error.toString()), isError: true);
  }

  void onListenData(Uint8List data) {
    _leftOverMessage += utf8.decode(data);

    // Use indexOf-based framing so that "S3nD:" inside a payload (e.g. in a
    // JSON game-state string) never creates false message boundaries.
    const String prefix = 'S3nD:';
    const String suffix = '[EOM]';
    while (true) {
      final int start = _leftOverMessage.indexOf(prefix);
      if (start == -1) break;
      final int contentStart = start + prefix.length;
      final int end = _leftOverMessage.indexOf(suffix, contentStart);
      if (end == -1) break;

      final String content = _leftOverMessage.substring(contentStart, end);
      _leftOverMessage = _leftOverMessage.substring(end + suffix.length);
      _serverResponsive = true;
      _handleContent(content);
    }
  }

  void _handleContent(String message) {
    if (SwerskiToast.isToastMessage(message)) {
      // The host's heart-attack line for the whole table. A malformed line
      // is ignored, and a device with "Heart attacks" off shows nothing.
      // Must come before the greeting branch: `swerski:` is its catch-all.
      final line = SwerskiToast.parse(message);
      if (line != null && _settings.heartAttacks.value) {
        _gameState.heartAttackToast.value = line;
      }
      return;
    }
    if (SwerskiFan.isFansMessage(message)) {
      // The host's SuperNetwork roster; a malformed list is ignored, the old
      // one stays.
      final fans = SwerskiFan.parseFans(message);
      if (fans != null) {
        _network.superFans.value = fans;
      }
      return;
    }
    if (SwerskiFan.isJoinedMessage(message)) {
      // A device finished joining — queued for the banner, which consumes and
      // clears it.
      final fan = SwerskiFan.parseJoined(message);
      if (fan != null) {
        _network.superFanJoined.value = fan;
      }
      return;
    }
    if (SwerskiGreeting.isSwerskiMessage(message)) {
      // The host's ack to our greeting; any other Swerski traffic (a greeting
      // aimed at us, a future version) is protocol noise we pass over.
      if (SwerskiGreeting.isAck(message)) {
        _network.hostGreeted.value = true;
        if (!_askedThisRun) {
          _network.superFanChoiceRequested.value = true;
        }
      }
      return;
    }

    if (message.startsWith("Mismatch:")) {
      message = message.substring("Mismatch:".length);
      _setNetworkMessage(_l10n.stateMismatch);
    }

    final StateEnvelope? envelope = StateEnvelope.tryDecode(message);
    if (envelope != null) {
      final GameEvent event = GameEvent.fromJsonString(envelope.eventJson);
      debugPrint(
        'Client Receive Data, index: ${envelope.index}, event:${event.runtimeType}',
      );
      _gameState.loadFromData(envelope.state);
      // Set event before commandIndex fires so VLB callbacks see it.
      _gameState.lastEvent.value = event;
      _gameState.commandIndex.value = envelope.index;
      _gameState.updateAllUI();
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _gameState.save(),
      );
    } else if (message.startsWith("Error")) {
      _setNetworkMessage(message, isError: true);
      disconnect(message);
    } else if (message.startsWith("ping")) {
      _send("pong");
    } else if (message.startsWith("pong")) {
      _serverResponsive = true;
      _missedPongs = 0;
    }
  }

  void _send(String data) {
    _communication.sendToAll(data);
  }

  void disconnect(String? message) {
    message ??= _l10n.clientDisconnected;
    if (_connection.established()) {
      debugPrint(message);
      _setNetworkMessage(message, isError: true);
      _connection.removeAll();
      _settings.connectClientOnStartup = false;
      _settings.saveToDisk();
      _cleanup();
    }
  }

  void _cleanup() {
    _settings.client.value = ClientState.disconnected;
    _gameState.commandIndex.value = -1;
    _gameState.resetCommandHistory();
    _leftOverMessage = "";
    _pinging = false;
    _pingGeneration++;
    _missedPongs = 0;
    _network.hostGreeted.value = false;
    _network.superFans.value = const [];
    _network.superFanJoined.value = null;

    if (_network.appInBackground) {
      _network.clientDisconnectedWhileInBackground = true;
    }
    _serverResponsive = true;
  }
}
