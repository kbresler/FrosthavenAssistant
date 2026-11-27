import 'dart:async';

import 'package:flutter/material.dart';

import '../../../Resource/app_constants.dart';
import '../../../Resource/game_methods.dart';
import '../../../Resource/settings.dart';
import '../../../Resource/ui_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/network/client.dart';
import '../../../services/network/network.dart';
import '../../../services/network/superfan/fans.dart';
import '../super_fan_choice_menu.dart';
import 'settings_checkbox.dart';

class SettingsNetworkSection extends StatefulWidget {
  static const double _kInputWidth = 200.0;
  static const double _kInputHeight = 40.0;
  static const double _kDropdownHeight = 20.0;
  static const int _kPortMaxLength = 6;

  const SettingsNetworkSection({
    super.key,
    required this.settings,
    required this.network,
    required this.client,
  });

  final Settings settings;
  final Network network;
  final Client client;

  @override
  SettingsNetworkSectionState createState() => SettingsNetworkSectionState();
}

class SettingsNetworkSectionState extends State<SettingsNetworkSection> {
  final TextEditingController _serverTextController = TextEditingController();
  final TextEditingController _portTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.network.networkInfo.initNetworkInfo();
    _serverTextController.text = widget.settings.lastKnownConnection;
    _portTextController.text = widget.settings.lastKnownPort;
  }

  List<DropdownMenuItem<String>> _getIPList() {
    return widget.network.networkInfo.wifiIPv6List
        .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(AppLocalizations.of(context)!.networkConnectLocal),
        ValueListenableBuilder<ClientState>(
            valueListenable: widget.settings.client,
            builder: (context, value, child) {
              final l10n = AppLocalizations.of(context)!;
              bool connected = false;
              final clientState = widget.settings.client.value;
              String connectionText = l10n.connectAsClientLabel;
              if (clientState == ClientState.connected) {
                connected = true;
                connectionText = l10n.connectedAsClient;
              }
              if (clientState == ClientState.connecting) {
                connectionText = l10n.connecting;
              }
              return CheckboxListTile(
                  enabled: !widget.settings.server.value &&
                      widget.settings.client.value != ClientState.connecting,
                  secondary: clientState == ClientState.connecting
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.cancelConnect,
                          onPressed: () => widget.client.cancelConnect(),
                        )
                      : null,
                  title: Text(connectionText),
                  value: connected,
                  onChanged: (bool? value) {
                    if (widget.settings.client.value != ClientState.connected) {
                      setState(() {
                        widget.settings.client.value = ClientState.connecting;
                        widget.settings.lastKnownPort =
                            _portTextController.text;
                        widget.settings.lastKnownConnection =
                            _serverTextController.text;
                      });
                      unawaited(widget.client
                          .connect(_serverTextController.text)
                        ..whenComplete(widget.settings.saveToDisk));
                    } else {
                      setState(() {
                        widget.client.disconnect(null);
                      });
                    }
                  });
            }),
        Container(
          margin:
              const EdgeInsets.only(top: SettingsNetworkSection._kInputHeight),
          width: SettingsNetworkSection._kInputWidth,
          child: TextField(
            controller: _serverTextController,
            decoration: InputDecoration(
              counterText: "",
              helperText: AppLocalizations.of(context)!.networkServerIpHint,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: kMenuTopPadding),
          width: SettingsNetworkSection._kInputWidth,
          height: SettingsNetworkSection._kInputHeight,
          child: TextField(
            keyboardType: TextInputType.number,
            controller: _portTextController,
            decoration: InputDecoration(
              counterText: "",
              helperText: AppLocalizations.of(context)!.networkPortHint,
            ),
            maxLength: SettingsNetworkSection._kPortMaxLength,
          ),
        ),
        ValueListenableBuilder<bool>(
            valueListenable: widget.settings.server,
            builder: (context, value, child) {
              final l10n = AppLocalizations.of(context)!;
              return CheckboxListTile(
                  title: Text(widget.settings.server.value
                      ? l10n.stopServerButton
                      : l10n.startHostServerButton),
                  value: widget.settings.server.value,
                  onChanged: (bool? value) {
                    if (!widget.settings.server.value) {
                      widget.settings.lastKnownPort = _portTextController.text;
                      widget.settings.lastKnownHostIP =
                          "(${widget.network.networkInfo.wifiIPv6.value})";
                      widget.settings.saveToDisk();
                      widget.network.server.startServer();
                    } else {
                      widget.network.server.stopServer(null);
                    }
                  });
            }),
        ValueListenableBuilder<String>(
            valueListenable: widget.network.networkInfo.wifiIPv6,
            builder: (context, value, child) {
              return SizedBox(
                width: SettingsNetworkSection._kInputWidth,
                height: SettingsNetworkSection._kDropdownHeight,
                child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                        value: widget.network.networkInfo.wifiIPv6.value,
                        items: _getIPList(),
                        onChanged: (value) => widget
                            .network.networkInfo.wifiIPv6.value = value ?? "")),
              );
            }),
        ValueListenableBuilder<String>(
            valueListenable: widget.network.networkInfo.outgoingIPv6,
            builder: (context, value, child) {
              return SizedBox(
                  width: SettingsNetworkSection._kInputWidth,
                  height: SettingsNetworkSection._kDropdownHeight,
                  child: Text(widget.network.networkInfo.outgoingIPv6.value));
            }),
        Container(
          margin: const EdgeInsets.only(top: kMenuTopPadding),
          width: SettingsNetworkSection._kInputWidth,
          height: SettingsNetworkSection._kInputHeight,
          child: TextField(
            controller: _portTextController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              counterText: "",
              helperText: AppLocalizations.of(context)!.networkPortHint,
            ),
            maxLength: SettingsNetworkSection._kPortMaxLength,
          ),
        ),
        _superNetworkSection(context),
      ],
    );
  }

  /// Swerski: who is on the SuperNetwork. While hosting, or connected to a
  /// host that greeted, one row per device: its name, a "host" marker, and
  /// what it plays. A character two devices play is flagged on both rows.
  Widget _superNetworkSection(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge(
            [widget.settings.server, widget.settings.client, widget.network.hostGreeted]),
        builder: (context, child) {
          final hosting = widget.settings.server.value;
          final greetedClient = widget.settings.client.value ==
                  ClientState.connected &&
              widget.network.hostGreeted.value;
          if (!hosting && !greetedClient) return const SizedBox.shrink();
          return ValueListenableBuilder<List<SwerskiFan>>(
              valueListenable: widget.network.superFans,
              builder: (context, fans, child) {
                final l10n = AppLocalizations.of(context)!;
                if (fans.isEmpty && !greetedClient) {
                  return const SizedBox.shrink();
                }
                final claims = <String, int>{};
                for (final fan in fans) {
                  for (final play in fan.plays) {
                    claims[play] = (claims[play] ?? 0) + 1;
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsHeading(l10n.superFanNetworkHeading),
                    for (final fan in fans) _fanRow(context, l10n, fan, claims),
                    if (greetedClient) _myChoiceRow(context, l10n),
                  ],
                );
              });
        });
  }

  /// Swerski: as a client of a greeted host, what this device plays and a
  /// button to open the choice picker again.
  Widget _myChoiceRow(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<List<String>>(
        valueListenable: widget.settings.devicePlays,
        builder: (context, plays, child) {
          final names = GameMethods.superFanPlaysNames(plays);
          return ListTile(
            title: Text(l10n.superFanYourChoice),
            subtitle: Text(
                names.isEmpty ? l10n.superFanPlaysTable : names.join(', ')),
            trailing: TextButton(
              // With no characters the picker would be empty and its OK
              // would wipe the stored choice, so it stays shut.
              onPressed: GameMethods.getCurrentCharacters().isEmpty
                  ? null
                  : () {
                      openDialogWithDismissOption<List<String>>(
                        context,
                        SuperFanChoiceMenu(
                          characters: GameMethods.getCurrentCharacters(),
                          storedPlays: widget.settings.devicePlays.value,
                        ),
                        true,
                      ).then((picks) {
                        if (picks != null) {
                          widget.client.saveSuperFanPlays(picks);
                        }
                      });
                    },
              child: Text(l10n.superFanChangeButton),
            ),
          );
        });
  }

  Widget _fanRow(BuildContext context, AppLocalizations l10n, SwerskiFan fan,
      Map<String, int> claims) {
    final name = fan.name.isEmpty ? l10n.superFanUnnamedDevice : fan.name;
    final names = GameMethods.superFanPlaysNames(fan.plays);
    final plays = <String>[];
    for (var i = 0; i < fan.plays.length; i++) {
      final shared = (claims[fan.plays[i]] ?? 0) > 1;
      plays.add(shared ? l10n.superFanPlaysShared(names[i]) : names[i]);
    }
    final theme = Theme.of(context);
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(name)),
          if (fan.host) ...[
            const SizedBox(width: 8),
            Text(l10n.superFanHostMarker,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
      subtitle: Text(plays.isEmpty ? l10n.superFanPlaysTable : plays.join(', ')),
    );
  }
}
