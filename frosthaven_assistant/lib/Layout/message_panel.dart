import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Resource/commands/command_l10n.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

// Swerski: the stacked message panel's looks, same parchment banner and
// teal bar the single-message SnackBar had (Settings.gameStyleMessages).
const Color kPanelParchment = Color(0xFFF2E6C9);
const Color kPanelBorder = Color(0xFF7A5A2E);
const Color kPanelText = Color(0xFF3B2A14);
const Color kPanelTeal = Colors.teal;
const Color kPanelError = Colors.redAccent;
const double _kPanelMaxWidth = 640.0;
const double _kPanelRadius = 8.0;
const double _kPanelBorderWidth = 2.0;
const double _kPanelFontSize = 22.0;
const double _kPanelBottom = 8.0;
const double _kPanelGap = 6.0;
const double _kPanelSide = 8.0;
const EdgeInsets _kPanelBannerPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 6);
const EdgeInsets _kPanelBarPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 10);

bool _gameStyleMessages() =>
    getIt.isRegistered<Settings>() && getIt<Settings>().gameStyleMessages.value;

const TextStyle _kPanelBarText = TextStyle(
    fontFamily: 'Markazi', fontSize: kFontSizeToast, color: Colors.white);

/// Swerski: the message panel at the bottom of the main screen: entries
/// stack, newest at the bottom, tapping one removes only that one. Drawn
/// last in the scaffold's Stack, above the deck corners — messages must
/// never hide under the decks. Only the messages themselves take taps: the
/// space around them lets the board through.
class MessagePanelNotifier extends StatelessWidget {
  const MessagePanelNotifier({super.key, this.panel});

  // injected for testing
  final MessagePanel? panel;

  @override
  Widget build(BuildContext context) {
    final panel = this.panel ?? MessagePanel.instance;
    return ListenableBuilder(
        listenable: panel,
        builder: (context, _) {
          final entries = panel.entries;
          if (entries.isEmpty) return const SizedBox.shrink();
          return Positioned(
              left: 0,
              right: 0,
              bottom: _kPanelBottom,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final (i, entry) in entries.indexed) ...[
                  if (i > 0) const SizedBox(height: _kPanelGap),
                  _row(panel, entry),
                ]
              ]));
        });
  }

  Widget _row(MessagePanel panel, MessageEntry entry) {
    if (entry.kind == MessageKind.error) return _errorRow(panel, entry);
    if (!_gameStyleMessages()) return _barRow(panel, entry, kPanelTeal);
    return _bannerRow(panel, entry);
  }

  Widget _bannerRow(MessagePanel panel, MessageEntry entry) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kPanelSide),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kPanelMaxWidth),
                child: GestureDetector(
                    onTap: () => panel.remove(entry),
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: kPanelParchment,
                            borderRadius:
                                BorderRadius.circular(_kPanelRadius),
                            border: Border.all(
                                color: kPanelBorder,
                                width: _kPanelBorderWidth),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x40000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ]),
                        child: Padding(
                            padding: _kPanelBannerPadding,
                            child: Text(entry.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: 'Markazi',
                                    fontSize: _kPanelFontSize,
                                    height: 1.1,
                                    color: kPanelText))))))));
  }

  Widget _barRow(MessagePanel panel, MessageEntry entry, Color color) {
    return GestureDetector(
        onTap: () => panel.remove(entry),
        child: ColoredBox(
            color: color,
            child: SizedBox(
                width: double.infinity,
                child: Padding(
                    padding: _kPanelBarPadding,
                    child: Text(entry.text, style: _kPanelBarText)))));
  }

  Widget _errorRow(MessagePanel panel, MessageEntry entry) {
    return GestureDetector(
        onTap: () => panel.remove(entry),
        child: ColoredBox(
            color: kPanelError,
            child: SizedBox(
                width: double.infinity,
                child: Padding(
                    padding: _kPanelBarPadding,
                    child: Row(children: [
                      Expanded(
                          child: Text(entry.text, style: _kPanelBarText)),
                      TextButton(
                          onPressed: () {
                            entry.onRetry?.call();
                            panel.remove(entry);
                          },
                          child: Text(commandL10n.retry,
                              style: _kPanelBarText.copyWith(
                                  fontWeight: FontWeight.bold))),
                    ])))));
  }
}
