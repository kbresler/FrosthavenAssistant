import 'dart:io';

import 'package:frosthaven_assistant/services/network/connection.dart';
import 'package:frosthaven_assistant/services/network/superfan/greeting.dart';

/// One greeted Swerski device on the host side: what it announced, and the
/// connection it announced itself on.
class SwerskiDevice {
  final String id;
  final String name;
  final List<String> plays;
  final Socket socket;

  const SwerskiDevice({
    required this.id,
    required this.name,
    required this.plays,
    required this.socket,
  });
}

/// The devices that have greeted this host since it started serving.
///
/// An entry lives as long as its connection: the same id greeting again (a
/// reconnect) replaces the old entry, and an entry is dropped when its socket
/// goes away — whether through `removeClientConnection`, a dead socket pruned
/// by `Communication`, or the server stopping.
class SwerskiRoster {
  final Connection _connection;
  final _devices = <String, SwerskiDevice>{};

  SwerskiRoster(this._connection);

  /// Records [greeting] from [socket]. The same id on a new connection
  /// replaces the previous entry, as does a new greeting on the same one.
  void greet(SwerskiGreeting greeting, Socket socket) {
    drop(socket); // one connection, one entry
    _devices[greeting.id] = SwerskiDevice(
      id: greeting.id,
      name: greeting.name,
      plays: greeting.plays,
      socket: socket,
    );
  }

  /// The live entries, dropping any whose connection is gone.
  List<SwerskiDevice> get devices {
    _devices.removeWhere((_, d) => !_isLive(d.socket));
    return List.unmodifiable(_devices.values);
  }

  /// Removes the entry that greeted on [socket], if any.
  void drop(Socket socket) {
    _devices.removeWhere((_, d) => d.socket == socket);
  }

  void clear() => _devices.clear();

  bool _isLive(Socket socket) {
    if (!_connection.getAll().contains(socket)) return false;
    try {
      // A remotely-closed socket throws here.
      socket.remoteAddress;
      socket.remotePort;
      return true;
    } on SocketException {
      return false;
    } on OSError {
      return false;
    }
  }
}
