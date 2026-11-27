import 'package:flutter/cupertino.dart';
import 'package:frosthaven_assistant/services/network/server.dart';

import 'network_info.dart';
import 'superfan/fans.dart';

enum ClientState { connected, disconnected, connecting } // ignore: prefer-match-file-name, file contains network state and enum together

class Network {
  final Server server;
  final NetworkInformation networkInfo = NetworkInformation();
  final networkMessage = ValueNotifier<String>("");
  final networkMessageIsError = ValueNotifier<bool>(false);

  /// Whether the host answered this connection's Swerski greeting with its
  /// ack. False until the ack arrives, again false on disconnect.
  final hostGreeted = ValueNotifier<bool>(false);

  /// Every device on the SuperNetwork, the host first. The host keeps this
  /// current for itself; a client fills it from the host's `fans` messages.
  /// Empty while no server runs.
  final superFans = ValueNotifier<List<SwerskiFan>>(const []);

  /// The device that joined most recently, null when there is nothing to
  /// announce. Transient like [GameState.heartAttackToast]: the banner shows
  /// it, then clears it.
  final superFanJoined = ValueNotifier<SwerskiFan?>(null);

  /// Set when the greeted host answers and this app run has not picked its
  /// characters yet: a trigger widget offers the choice dialog, then calls
  /// `Client.markSuperFanAsked` to consume it. A game without characters
  /// leaves the question unasked, so the next connection asks again.
  final superFanChoiceRequested = ValueNotifier<bool>(false);

  bool appInBackground = false;
  bool clientDisconnectedWhileInBackground = false;

  Network({Server? server}) : server = server ?? Server();
}
