import 'package:flutter/material.dart';

import '../../../Resource/game_methods.dart';
import '../../../Resource/settings.dart';
import '../../../Resource/state/game_state.dart';
import '../../../Resource/ui_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/service_locator.dart';
import '../../attack_mode/attack_mode_controller.dart';
import '../../view_models/status_menu_view_model.dart';
import '../../widgets/modal_background.dart';
import '../note_row_menu.dart';
import '../set_figure_note_menu.dart';
import 'status_menu_condition_panel.dart';
import 'status_menu_header.dart';
import 'status_menu_stat_column.dart';

class StatusMenu extends StatefulWidget {
  static const double _kMenuWidth = 340.0;

  const StatusMenu({
    super.key,
    required this.figureId,
    this.characterId,
    this.monsterId,
    this.gameState,
    this.settings,
  });

  final String figureId;
  final String? monsterId;
  final String? characterId;

  final GameState? gameState;
  final Settings? settings;

  @override
  StatusMenuState createState() => StatusMenuState();
}

class StatusMenuState extends State<StatusMenu> {
  GameState get _gameState => widget.gameState ?? getIt<GameState>();
  Settings get _settings => widget.settings ?? getIt<Settings>();

  @override
  initState() {
    super.initState();
  }

  /// Opens the note-row editor pre-linked to this figure's row, so a note
  /// created here is connected to (and rendered beneath) the figure.
  Widget _buildAddNoteButton(
      BuildContext context, StatusMenuViewModel vm, double scale) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        openDialog(
          context,
          NoteRowMenu(
            presetLinkId: vm.ownerId,
            gameState: _gameState,
            settings: _settings,
          ),
        );
      },
      icon: Icon(Icons.note_add_outlined, size: 18 * scale),
      label: Text(l10n.noteRowAddFromMenu, style: getButtonTextStyle(scale)),
    );
  }

  /// Inline-note entry point for a figure's row (character or monster). Always
  /// shown (even with an empty note) so a note can be added here; the row only
  /// shows the inline snippet once non-empty. Returns nothing for summons.
  Widget _buildNoteButton(
      BuildContext context, StatusMenuViewModel vm, double scale) {
    final ListItemData? figure =
        vm.isCharacter ? vm.character : (vm.isMonster ? vm.monster : null);
    if (figure == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<String>(
      valueListenable: figure.note,
      builder: (context, note, child) => TextButton.icon(
        onPressed: () => openDialog(
          context,
          SetFigureNoteMenu(
            figure: figure,
            gameState: _gameState,
            settings: _settings,
          ),
        ),
        icon: Icon(Icons.sticky_note_2_outlined, size: 18 * scale),
        label: Text(
          note.isEmpty ? l10n.characterNoteQuickAdd : note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: getButtonTextStyle(scale),
        ),
      ),
    );
  }

  /// Swerski: starts attack mode with this figure already picked. Monster
  /// standees and heroes, never summons.
  Widget _buildAttackSeveralButton(
      BuildContext context, StatusMenuViewModel vm, double scale) {
    final fig = vm.figure;
    final on = _settings.attackSeveral.value;
    final VoidCallback start;
    if (on && vm.isMonster && !vm.isCharacter && fig is MonsterInstance) {
      start = () {
        Navigator.of(context).pop();
        attackModeController().startSelecting(first: fig, ownerId: vm.ownerId);
      };
    } else if (on && vm.isCharacter && !vm.isSummon && fig is CharacterState) {
      start = () {
        Navigator.of(context).pop();
        attackModeController().startSelecting(firstHero: vm.characterId);
      };
    } else {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: start,
      icon: Image.asset('assets/images/abilities/attack_black.png',
          height: 18 * scale),
      label: Text(l10n.attackSeveralMenu, style: getButtonTextStyle(scale)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _gameState.commandIndex,
      builder: (context, child) {
        final vm = StatusMenuViewModel(
          figureId: widget.figureId,
          monsterId: widget.monsterId,
          characterId: widget.characterId,
          gameState: _gameState,
          settings: _settings,
        );

        final figure = vm.figure;
        if (figure == null) {
          return const SizedBox(height: 0, width: 0);
        }

        final owner = vm.owner;
        if (owner == null) {
          return const SizedBox(height: 0, width: 0);
        }

        double scale = getModalMenuScale(context);
        int nrOfCharacters = GameMethods.getCurrentCharacterAmount();

        return Wrap(
          children: [
            ModalBackground(
              width: StatusMenu._kMenuWidth * scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusMenuHeader(
                    name: vm.name,
                    figure: figure,
                    scale: scale,
                    hasShield: vm.hasShield,
                    hasRetaliate: vm.hasRetaliate,
                    owner: owner,
                    figureId: widget.figureId,
                    ownerId: vm.ownerId,
                    isIceWraith: vm.isIceWraith,
                    isElite: vm.isElite,
                    gameState: _gameState,
                    onIceWraithSwitch: () => setState(() {}),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatusMenuStatColumn(
                        figure: figure,
                        scale: scale,
                        isMonster: vm.isMonster,
                        isCharacter: vm.isCharacter,
                        isSummon: vm.isSummon,
                        characterId: widget.characterId,
                        monsterId: widget.monsterId,
                        immunities: vm.immunities,
                        hasVimthreader: vm.hasVimthreader,
                        hasLifespeaker: vm.hasLifespeaker,
                        hasIncarnate: vm.hasIncarnate,
                        character: vm.character,
                        hasPlagueHerald: vm.hasPlagueHerald,
                        figureId: widget.figureId,
                        ownerId: vm.ownerId,
                        monster: vm.monster,
                        showCustomContent: vm.showCustomContent,
                        gameState: _gameState,
                        settings: _settings,
                      ),
                      StatusMenuConditionPanel(
                        figureId: widget.figureId,
                        ownerId: vm.ownerId,
                        immunities: vm.immunities,
                        scale: scale,
                        isMonster: vm.isMonster,
                        isCharacter: vm.isCharacter,
                        isSummon: vm.isSummon,
                        nrOfCharacters: nrOfCharacters,
                        showCustomContent: vm.showCustomContent,
                        hasMireFoot: vm.hasMireFoot,
                        gameState: _gameState,
                        settings: _settings,
                      ),
                    ],
                  ),
                  _buildNoteButton(context, vm, scale),
                  _buildAddNoteButton(context, vm, scale),
                  _buildAttackSeveralButton(context, vm, scale),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
