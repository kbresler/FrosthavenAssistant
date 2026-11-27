import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_event.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/heart_attack_lines.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant_server/game_server.dart';

import '../../l10n/app_localizations.dart';
import '../service_locator.dart';
import 'communication.dart';
import 'connection.dart';
import 'network.dart';
import 'superfan/fans.dart';
import 'superfan/greeting.dart';
import 'superfan/preserve_swerski_fields.dart';
import 'superfan/roster.dart';
import 'superfan/toast.dart';

class Server extends GameServer {
  final GameState _gameState;
  final Communication _communication;
  final Connection _connection;
  final Settings? _settingsOverride;
  final SwerskiRoster _swerskiRoster;

  /// The last fans list sent to the greeted devices, so an unchanged list is
  /// not re-sent on every ping tick.
  List<SwerskiFan>? _lastSentFans;

  /// What each device id was last announced as playing. A disconnect does not
  /// forget it — reconnecting is not joining again — only stopping the server
  /// does.
  final Map<String, List<String>> _announcedPlays = {};

  Server(
      {GameState? gameState,
      Communication? communication,
      Connection? connection,
      Settings? settings})
      : _gameState = gameState ?? getIt<GameState>(),
        _communication = communication ?? getIt<Communication>(),
        _connection = connection ?? getIt<Connection>(),
        _swerskiRoster = SwerskiRoster(connection ?? getIt<Connection>()),
        _settingsOverride = settings;

  Settings get _settings => _settingsOverride ?? getIt<Settings>();

  /// The Swerski devices that have greeted on this server since it started.
  List<SwerskiDevice> get swerskiClients => _swerskiRoster.devices;

  AppLocalizations get _l10n {
    final code = _settings.locale.value;
    try {
      return lookupAppLocalizations(Locale(code));
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  /// The host's own entry: it plays the whole table (brief rule 6), whatever
  /// its own stored `devicePlays` hold — those belong to a device that joins
  /// someone else's game. Listed first.
  SwerskiFan _hostFan() => SwerskiFan(
        id: _settings.deviceId.isEmpty ? 'local' : _settings.deviceId,
        name: _settings.deviceName.value,
        plays: const [],
        host: true,
      );

  List<SwerskiFan> _currentFans() => [
        _hostFan(),
        for (final device in _swerskiRoster.devices)
          SwerskiFan(id: device.id, name: device.name, plays: device.plays),
      ];

  /// Refills [Network.superFans]; when the list changed and the server runs,
  /// re-sends it to every greeted device. Listing the roster prunes sockets
  /// that died, so the ping tick picks those up too. A socket that [greeter]
  /// marks — the one that just greeted — always gets the current list, even
  /// when it is unchanged: after a quick reconnect the roster still holds the
  /// device, so the diff alone would leave the new socket listless.
  void _refreshSuperFans({Socket? greeter}) {
    final fans = _currentFans();
    final last = _lastSentFans;
    final changed = last == null ||
        SwerskiFan.encodeFans(fans) != SwerskiFan.encodeFans(last);
    if (changed && serverSocket != null) {
      final message = SwerskiFan.encodeFans(fans);
      for (final device in _swerskiRoster.devices) {
        if (identical(device.socket, greeter)) continue;
        sendToOnly(message, device.socket);
      }
      _lastSentFans = fans;
    }
    if (greeter != null && serverSocket != null) {
      sendToOnly(SwerskiFan.encodeFans(fans), greeter);
    }
    getIt<Network>().superFans.value = fans;
  }

  /// Swerski: the host renamed itself, so its own entry and every greeted
  /// device get the new name. Nothing is announced: a rename is not a join.
  void refreshHostIdentity() {
    if (serverSocket == null) return;
    _refreshSuperFans();
  }

  /// Announces a device that finished choosing: sent once per id, then again
  /// only when its plays change. Renames and reconnects stay quiet, and so
  /// does the same set of plays in a new order — initiative reorders the
  /// character list without anything being chosen anew.
  void _announceJoin(SwerskiGreeting greeting) {
    final previous = _announcedPlays[greeting.id];
    if (previous != null &&
        setEquals(Set.of(previous), Set.of(greeting.plays))) {
      return;
    }
    _announcedPlays[greeting.id] = List.of(greeting.plays);
    final message = SwerskiFan.encodeJoined(SwerskiFan(
      id: greeting.id,
      name: greeting.name,
      plays: greeting.plays,
    ));
    for (final device in _swerskiRoster.devices) {
      sendToOnly(message, device.socket);
    }
    getIt<Network>().superFanJoined.value = SwerskiFan(
      id: greeting.id,
      name: greeting.name,
      plays: greeting.plays,
    );
  }

  @override
  bool get serverEnabled {
    return _settings.server.value;
  }

  @override
  set serverEnabled(bool value) {
    _settings.server.value = value;
    super.serverEnabled = value;
  }

  @override
  Future<String> getConnectToIP() async {
    String connectTo = InternetAddress.anyIPv6.address; //"0.0.0.0";
    if (getIt<Network>().networkInfo.wifiIPv6.value.isNotEmpty &&
        !getIt<Network>().networkInfo.wifiIPv6.value.contains("Fail")) {
      connectTo = getIt<Network>().networkInfo.wifiIPv6.value;
    } else {
      getIt<Network>().networkInfo.wifiIPv6.value =
          connectTo; //if not on wifi show local ip
    }
    return connectTo;
  }

  @override
  void resetState() {
    _gameState.commandIndex.value = -1;
    _gameState.resetCommandHistory();
    _pinging = false;
    _lastSentFans = null;
    _announcedPlays.clear();
    // The server calls this at the end of starting and again when stopping.
    // Started: the list starts out holding the host itself, so Settings shows
    // the SuperNetwork block before anyone joins. Stopped: empty.
    getIt<Network>().superFans.value = serverEnabled ? _currentFans() : const [];
    getIt<Network>().superFanJoined.value = null;
  }

  @override
  void undoState() {
    _gameState.undo();
  }

  @override
  void redoState() {
    _gameState.redo();
  }

  static const String _noEventJson = '{"type":"none"}';

  String _lastSavedState() {
    return _gameState.gameSaveStates.isNotEmpty
        ? (_gameState.gameSaveStates.last?.getState() ?? _gameState.toString())
        : _gameState.toString();
  }

  @override
  void updateStateFromMessage(StateUpdateMessage message, Socket client) {
    // Swerski: a phone's action arrives as a whole state, so its heart
    // attacks are spotted by comparing the table before and after the load.
    final heartAttackBefore = _heartAttackWatch();
    final roundBefore = _gameState.roundState.value;
    if (message.index > _gameState.commandDescriptions.length) {
      //invalid: index too high. send correction to clients
      String commandDescription = "";
      if (_gameState.commandDescriptions.isNotEmpty) {
        commandDescription = _gameState.commandDescriptions.last;
      }
      send(StateEnvelope(
        index: _gameState.commandIndex.value,
        description: commandDescription,
        eventJson: _noEventJson,
        state: _lastSavedState(),
      ).encode());
    } else if (message.index > _gameState.commandIndex.value) {
      if (message.index >= 0) {
        _gameState.insertReceivedDescription(message.index, message.description);
      }
      // An official-app snapshot lacks the Swerski keys; restore them so a
      // client action cannot wipe the host's heart-attack counts.
      _gameState.loadFromData(preserveSwerskiFields(
        incoming: message.data,
        current: _gameState.toString(),
      ));
      // Set event before commandIndex fires so VLB callbacks see it.
      _gameState.lastEvent.value = GameEvent.fromJsonString(message.eventJson);
      _gameState.commandIndex.value = message.index;
      _gameState.save();
      _gameState.updateAllUI();
      sendToOthers(
          StateEnvelope(
            index: _gameState.commandIndex.value,
            description: _gameState.commandDescriptions.last,
            eventJson: message.eventJson,
            state: _lastSavedState(),
          ).encode(),
          client);
      _announceHeartAttacks(heartAttackBefore, roundBefore);
    } else {
      log('Got same or lower index. ignoring: received index: ${message.indexString} current index ${_gameState.commandIndex.value}');

      //overwrite client state with current server state.
      final idx = _gameState.commandIndex.value;
      final mismatchDesc = (idx >= 0 && idx < _gameState.commandDescriptions.length)
          ? _gameState.commandDescriptions[idx]
          : '';
      sendToOnly(
          "Mismatch:${StateEnvelope(
            index: idx,
            description: mismatchDesc,
            eventJson: _noEventJson,
            state: _lastSavedState(),
          ).encode()}",
          client);
      //ignore if same index from server
    }
  }

  @override
  void setNetworkMessage(String data) {
    // Translate known static messages; leave dynamic ones (IPs, errors) as-is.
    final bool isError = data.toLowerCase().contains('error') ||
        data.toLowerCase().contains('offline') ||
        data.toLowerCase().contains('mismatch') ||
        data.toLowerCase().contains('outdated');
    final String translated = switch (data) {
      'Server Offline' => _l10n.serverOffline,
      'Client left.' => _l10n.clientLeft,
      "Old client attempted to connect. Please update the app." =>
        _l10n.clientTooOld,
      _ => data,
    };
    getIt<Network>().networkMessageIsError.value = isError;
    getIt<Network>().networkMessage.value = translated;
  }

  @override
  String currentStateMessage(String commandDescription) {
    return StateEnvelope(
      index: _gameState.commandIndex.value,
      description: commandDescription,
      eventJson: _noEventJson,
      state: _lastSavedState(),
    ).encode();
  }

  bool _pinging = false; //to not restart this ping sub process, if one is running
  @override
  void sendPing() {
    if (serverSocket != null &&
        _settings.server.value &&
        !_pinging) {
      _pinging = true;
      Future.delayed(const Duration(seconds: 20), () {
        _pinging = false;
        if (serverSocket == null || !_settings.server.value) {
          return;
        }
        // A socket that died since the last tick drops out of the roster when
        // it is listed; push the new list to the devices that are still there.
        _refreshSuperFans();
        // Skip the broadcast while backgrounded — the radio wakeup costs far
        // more battery than the keepalive is worth. Keep rescheduling so the
        // chain resumes on foreground. (Android hosting keeps its foreground
        // service, which is what actually holds the connection open there.)
        if (!getIt<Network>().appInBackground) {
          send("ping");
        }
        sendPing();
      });
    }
  }

  @override
  void processMessages(String message, Socket client) {
    if (SwerskiGreeting.isSwerskiMessage(message)) {
      final greeting = SwerskiGreeting.parse(message);
      if (greeting != null) {
        _swerskiRoster.greet(greeting, client);
        sendToOnly(SwerskiGreeting.encodeAck(), client);
        _refreshSuperFans(greeter: client);
        if (!greeting.asking) _announceJoin(greeting);
      }
      // Anything else Swerski-prefixed is ignored. Game state and the command
      // index are never touched by Swerski traffic.
      return;
    }
    super.processMessages(message, client);
  }

  @override
  void addClientConnection(Socket client) {
    _connection.add(client);
  }

  @override
  void removeClientConnection(Socket client) {
    _connection.remove(client);
    _swerskiRoster.drop(client);
    _refreshSuperFans();
  }

  @override
  void removeAllClientConnections() {
    _connection.removeAll();
    _swerskiRoster.clear();
    _lastSentFans = null;
    _announcedPlays.clear();
    getIt<Network>().superFans.value = const [];
  }

  static const int _defaultPort = 4567;

  void startServer() {
    final int port =
        int.tryParse(_settings.lastKnownPort) ?? _defaultPort;
    startServerInternal(InternetAddress.anyIPv6.address, port);
  }

  @override
  void send(String data) {
    _communication.sendToAll(data);
  }

  @override
  void sendToOnly(String data, Socket client) {
    _communication.sendTo(client, data);
  }

  @override
  void sendToOthers(String data, Socket client) {
    _communication.sendToAllExcept(client, data);
  }

  /// Swerski: shows [line] on every greeted device. Nothing happens while the
  /// server is not running. The host's "Heart attacks" setting does NOT gate
  /// this: a host that hides the lines itself still passes on the ones its
  /// phones produce.
  void sendSuperFanToast(String line) {
    if (serverSocket == null) return;
    final message = SwerskiToast.encode(line);
    for (final device in _swerskiRoster.devices) {
      sendToOnly(message, device.socket);
    }
  }

  /// Where the health and heart-attack tallies stood before a state load,
  /// per tracked character. Objectives and Escorts are not tracked.
  Map<String, ({int health, int major, int little})> _heartAttackWatch() {
    final watch = <String, ({int health, int major, int little})>{};
    for (final item in _gameState.currentList) {
      if (item is Character &&
          !GameMethods.isObjectiveOrEscort(item.characterClass)) {
        final state = item.characterState;
        watch[item.id] = (
          health: state.health.value,
          major: state.heartAttacks.value,
          little: state.littleHeartAttacks.value,
        );
      }
    }
    return watch;
  }

  /// Swerski: spots the heart attacks a phone's update just caused and shows
  /// one line for them, the host writing it. Major: a tracked character went
  /// from above 0 to exactly 0 with its count up. Little: a count up while
  /// the round went from choosing initiative to playing turns. Little wins,
  /// and among majors the last one in list order. The line goes to every
  /// greeted device — including the phone that caused it — and this host's
  /// "Heart attacks" setting only decides whether the host shows it too.
  void _announceHeartAttacks(
    Map<String, ({int health, int major, int little})> before,
    RoundState roundBefore,
  ) {
    final majors = <Character>[];
    final resting = <Character>[];
    final roundChanged = _gameState.roundState.value == RoundState.playTurns &&
        roundBefore == RoundState.chooseInitiative;
    for (final item in _gameState.currentList) {
      if (item is! Character ||
          GameMethods.isObjectiveOrEscort(item.characterClass)) {
        continue;
      }
      final was = before[item.id];
      if (was == null) continue; // newly added: not this phone's doing
      final state = item.characterState;
      if (was.health > 0 &&
          state.health.value == 0 &&
          state.heartAttacks.value > was.major) {
        majors.add(item);
      }
      if (roundChanged && state.littleHeartAttacks.value > was.little) {
        resting.add(item);
      }
    }
    String? line;
    if (resting.isNotEmpty) {
      line = heartAttackRestingLine(resting);
    } else if (majors.isNotEmpty) {
      line = heartAttackReplyLine(majors.last, _gameState);
    }
    if (line == null || line.isEmpty) return;
    sendSuperFanToast(line);
    if (_settings.heartAttacks.value) {
      _gameState.heartAttackToast.value = line;
    }
  }

  @override
  void sendInitResponse(Socket client) {
    String commandDescription = "";
    if (_gameState.commandIndex.value > 0 &&
        _gameState.commandDescriptions.length > _gameState.commandIndex.value) {
      commandDescription =
          _gameState.commandDescriptions[_gameState.commandIndex.value];
    } else {
      //should not happen
      if (kDebugMode) {
        print("?");
      }
    }
    log('Server sends init response: "S3nD:Index:${_gameState.commandIndex.value}Description:$commandDescription');
    sendToOnly(
        StateEnvelope(
          index: _gameState.commandIndex.value,
          description: commandDescription,
          eventJson: _noEventJson,
          state: _lastSavedState(),
        ).encode(),
        client);
  }
}
