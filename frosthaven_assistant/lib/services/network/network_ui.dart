import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/services/network/client.dart';

import '../service_locator.dart';
import 'network.dart';

class NetworkUI extends StatelessWidget {
  const NetworkUI({super.key, this.network, this.settings, this.client});

  // injected for testing
  final Network? network;
  final Settings? settings;
  final Client? client;

  Network get _network => network ?? getIt<Network>();
  Settings get _settings => settings ?? getIt<Settings>();
  Client get _client => client ?? getIt<Client>();

  @override
  Widget build(BuildContext context) {
    //dummy ui to react to network messages.
    return ValueListenableBuilder<String>(
        valueListenable: _network.networkMessage,
        builder: (context, value, child) {
          Future.delayed(const Duration(milliseconds: 200), () {
            String message = _network.networkMessage.value;
            if (message != "") {
              if (_network.networkMessageIsError.value) {
                MessagePanel.instance.add(MessageEntry(
                    MessageKind.error,
                    message,
                    onRetry: () {
                      if (_settings.client.value != ClientState.connected &&
                          _settings.lastKnownConnection != "") {
                        _settings.client.value = ClientState.connecting;
                        unawaited(
                            _client.connect(_settings.lastKnownConnection));
                        _settings.saveToDisk();
                      }
                    }));
              } else {
                MessagePanel.instance
                    .add(MessageEntry(MessageKind.timed, message));
              }
              _network.networkMessageIsError.value = false;
              _network.networkMessage.value = "";
            }
          });

          return const SizedBox(
            //todo: remove hack?
            width: 0.00001,
            height: 0.00001,
          );
        });
  }
}
