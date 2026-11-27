import 'package:frosthaven_assistant/services/network/client.dart';

/// A client that records the SuperNetwork calls instead of talking to a socket.
class RecordingClient extends Client {
  RecordingClient();

  final List<List<String>> savedPlays = [];
  int reannounced = 0;
  int nothingToAsk = 0;

  @override
  void saveSuperFanPlays(List<String> plays) {
    savedPlays.add(plays);
  }

  @override
  void superFanNothingToAsk() {
    nothingToAsk++;
  }

  @override
  void reannounceSuperFanIdentity() {
    reannounced++;
  }
}
