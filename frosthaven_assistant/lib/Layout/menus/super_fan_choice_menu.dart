import 'package:flutter/material.dart';

import '../../Resource/state/game_state.dart';
import '../../Resource/ui_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../services/service_locator.dart';
import '../../services/translation_service.dart';
import '../CharacterWidget/character_widget_internal.dart';
import '../widgets/modal_background.dart';

/// Swerski: asks which characters this device plays on the SuperNetwork.
/// Opened once per app run after the host's greeting ack, and from Settings
/// afterwards. OK pops the ticked character ids (empty means "the whole
/// table"); dismissing pops null and keeps the stored choice. At most
/// [SuperFanChoiceMenu.maxPicks] characters can be ticked.
class SuperFanChoiceMenu extends StatefulWidget {
  const SuperFanChoiceMenu({
    super.key,
    required this.characters,
    required this.storedPlays,
    this.localInitChanges,
  });

  static const double _kMenuWidth = 300.0;

  /// A device plays at most this many characters.
  static const int maxPicks = 4;

  final List<Character> characters;
  final List<String> storedPlays;

  /// Injected for testing; defaults to the device's own initiative typing.
  final Set<String>? localInitChanges;

  @override
  State<SuperFanChoiceMenu> createState() => _SuperFanChoiceMenuState();
}

class _SuperFanChoiceMenuState extends State<SuperFanChoiceMenu> {
  Set<String> _picks = {};

  @override
  void initState() {
    super.initState();
    _picks = _initialPicks(widget);
  }

  static List<String> _initialIds(SuperFanChoiceMenu widget) =>
      widget.characters.map((c) => c.id).toList();

  static Set<String> _initialPicks(SuperFanChoiceMenu widget) {
    final ids = _initialIds(widget);
    var picks = ids.where(widget.storedPlays.contains).toList();
    if (picks.isEmpty) {
      final local = widget.localInitChanges ??
          CharacterWidgetInternal.localCharacterInitChanges;
      picks = ids.where(local.contains).toList();
    }
    return picks.take(SuperFanChoiceMenu.maxPicks).toSet();
  }

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        _picks.add(id);
      } else {
        _picks.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = getModalMenuScale(context);
    final l10n = AppLocalizations.of(context)!;
    final full = _picks.length >= SuperFanChoiceMenu.maxPicks;

    return ModalBackground(
      width: SuperFanChoiceMenu._kMenuWidth * scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.superFanChoiceTitle,
                textAlign: TextAlign.center,
                style: getTitleTextStyle(scale)),
            SizedBox(height: 4 * scale),
            Text(l10n.superFanChoiceHint,
                textAlign: TextAlign.center,
                style: getSmallTextStyle(scale)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final character in widget.characters)
                      CheckboxListTile(
                        title: Text(getIt<TranslationService>()
                            .t(character.characterState.display.value)),
                        value: _picks.contains(character.id),
                        // Over the limit the unticked rows go dark rather
                        // than eating a tap that changes nothing.
                        onChanged: _picks.contains(character.id) || !full
                            ? (value) =>
                                _toggle(character.id, value ?? false)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(
                  _initialIds(widget).where(_picks.contains).toList(),
                ),
                child: Text(MaterialLocalizations.of(context).okButtonLabel,
                    style: getButtonTextStyle(scale)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
