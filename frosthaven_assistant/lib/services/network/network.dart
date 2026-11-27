import 'package:flutter/cupertino.dart';
import 'package:frosthaven_assistant/services/network/server.dart';

import 'network_info.dart';

enum ClientState { connected, disconnected, connecting } // ignore: prefer-match-file-name, file contains network state and enum together

class Network {
  final Server server;
  final NetworkInformation networkInfo = NetworkInformation();
  final networkMessage = ValueNotifier<String>("");
  final networkMessageIsError = ValueNotifier<bool>(false);

  /// Whether the host answered this connection's Swerski greeting with its
  /// ack. False until the ack arrives, again false on disconnect.
  final hostGreeted = ValueNotifier<bool>(false);

  bool appInBackground = false;
  bool clientDisconnectedWhileInBackground = false;

  Network({Server? server}) : server = server ?? Server();
}
