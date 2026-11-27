import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/ModifierDeckWidget/modifier_deck_widget.dart';
import 'package:frosthaven_assistant/Layout/background.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../Model/campaign.dart';
import '../Model/room.dart';
import '../Resource/game_data.dart';
import '../Resource/game_methods.dart';
import '../Resource/scaling.dart';
import '../Resource/settings.dart';
import '../Resource/ui_utils.dart';
import '../services/network/client.dart';
import '../services/network/network.dart';
import '../services/network/superfan/fans.dart';
import '../services/service_locator.dart';
import '../l10n/app_localizations.dart';
import 'LootDeckWidget/loot_deck_widget.dart';
import 'MainList/main_list.dart';
import 'attack_mode/attack_mode_controller.dart';
import 'attack_mode/attack_mode_panel.dart';
import 'bottom_bar.dart';
import 'section_list.dart';
import 'bottom_overlay.dart';
import 'character_amds_widget.dart';
import 'empty_board_prompt.dart';
import 'menus/AutoAddStandeeMenu/auto_add_standee_menu.dart';
import 'menus/main_menu.dart';
import 'menus/super_fan_choice_menu.dart';
import 'message_panel.dart';
import 'view_models/character_amds_view_model.dart';
import 'view_models/main_scaffold_view_model.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, this.settings});

  // injected for testing
  final Settings? settings;

  @override
  Widget build(BuildContext context) {
    final settings = this.settings ?? getIt<Settings>();

    return ValueListenableBuilder<double>(
        valueListenable: settings.userScalingBars,
        builder: (context, value, child) {
          return SafeArea(
              left: false,
              right: false,
              maintainBottomViewPadding: true,
              child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  bottomNavigationBar: RepaintBoundary(child: BottomBar()),
                  appBar: PreferredSize(
                      preferredSize: Size(double.infinity,
                          kBarHeight * settings.userScalingBars.value),
                      child: const RepaintBoundary(child: TopBar())),
                  drawer: MainMenu(),
                  body: const RepaintBoundary(child: MainScaffoldBody())));
        });
  }
}

/// Swerski: the bridge between the saved `toastMessage` and the message
/// panel: the wound text joins the panel as a wound entry, anything else as
/// the reminder; the game clearing the message (`''` at next round, a new
/// scenario, an Undo) takes both entries off; and when the panel drops a
/// wound or the reminder, `toastMessage` is set to what the panel still
/// shows for the game — the reminder on screen, or `''`.
class ToastNotifier extends StatefulWidget {
  const ToastNotifier({super.key, this.gameState, this.panel});

  // injected for testing
  final GameState? gameState;
  final MessagePanel? panel;

  @override
  State<ToastNotifier> createState() => _ToastNotifierState();
}

class _ToastNotifierState extends State<ToastNotifier> {
  /// Set around the bridge's own write-back so the listener below ignores
  /// it: clearing the message after a tapped reminder must not sync the
  /// panel back and take a still-shown wound with it.
  bool _writingBack = false;

  GameState get _gs => widget.gameState ?? getIt<GameState>();
  MessagePanel get _panel => widget.panel ?? MessagePanel.instance;

  @override
  void initState() {
    super.initState();
    _panel.onRemoved = _onPanelRemoved;
    // Swerski: every game change lands on the panel as it happens — a
    // build-triggered sync would miss values that come and go within one
    // frame, like a battle-goal reminder cleared and replaced by a wound.
    _gs.toastMessage.addListener(_onToastMessage);
    // Swerski: a reminder already in the message when the panel first
    // appears is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(_gs.toastMessage.value);
    });
  }

  @override
  void dispose() {
    _gs.toastMessage.removeListener(_onToastMessage);
    if (_panel.onRemoved == _onPanelRemoved) _panel.onRemoved = null;
    super.dispose();
  }

  void _onToastMessage() {
    if (_writingBack) return; // the panel's own echo, already applied
    _sync(_gs.toastMessage.value);
  }

  /// Writes back only when the removed entry is what the game holds: with a
  /// wound current, tapping the reminder beside it must not touch the
  /// wound's message.
  void _onPanelRemoved(MessageEntry entry, bool timedOut) {
    if (entry.kind != MessageKind.wound &&
        entry.kind != MessageKind.reminder) {
      return;
    }
    if (_gs.toastMessage.value != entry.text) return; // the game moved on
    final shown = _panel.entries.where((e) => e.kind == MessageKind.reminder);
    _writingBack = true;
    GameUtilMethods.setToastMessage(
        shown.isEmpty ? '' : shown.first.text,
        gameState: _gs);
    _writingBack = false;
  }

  void _sync(String value) {
    if (value.isEmpty) {
      _panel.removeSilently(MessageKind.reminder);
      _panel.removeSilently(MessageKind.wound);
      return;
    }
    _panel.add(isWoundMessage(value)
        ? MessageEntry(MessageKind.wound, value)
        : MessageEntry(MessageKind.reminder, value));
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 0,
      height: 0,
    );
  }
}

/// Swerski: shows a heart-attack reply line on the message panel as a
/// passing entry, then clears the notifier. Reads the transient (non-synced,
/// non-undoable) notifier the health command sets on the device that applied
/// the change.
class HeartAttackToastNotifier extends StatelessWidget {
  const HeartAttackToastNotifier({super.key, this.gameState, this.panel});

  // injected for testing
  final GameState? gameState;
  final MessagePanel? panel;

  @override
  Widget build(BuildContext context) {
    final gameState = this.gameState ?? getIt<GameState>();
    final panel = this.panel ?? MessagePanel.instance;
    return ValueListenableBuilder<String>(
        valueListenable: gameState.heartAttackToast,
        builder: (context, message, child) {
          if (message.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Clear before showing so the same line can fire again later.
              gameState.heartAttackToast.value = "";
              panel.add(MessageEntry(MessageKind.line, message));
            });
          }
          return const SizedBox(
            width: 0,
            height: 0,
          );
        });
  }
}

/// Swerski: opens the "who do you play?" picker when the greeted host has
/// answered and this app run has not picked its characters yet. A game
/// without characters keeps the question unasked for the next connection.
class SuperFanChoiceDialogTrigger extends StatelessWidget {
  const SuperFanChoiceDialogTrigger({super.key, this.network, this.client});

  // injected for testing
  final Network? network;
  final Client? client;

  @override
  Widget build(BuildContext context) {
    final network = this.network ?? getIt<Network>();
    final client = this.client ?? getIt<Client>();
    return ValueListenableBuilder<bool>(
        valueListenable: network.superFanChoiceRequested,
        builder: (context, requested, child) {
          if (requested) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              network.superFanChoiceRequested.value = false;
              final characters = GameMethods.getCurrentCharacters();
              if (characters.isEmpty) {
                client.superFanNothingToAsk();
                return;
              }
              client.markSuperFanAsked();
              openDialogWithDismissOption<List<String>>(
                context,
                SuperFanChoiceMenu(
                  characters: characters,
                  storedPlays: getIt<Settings>().devicePlays.value,
                ),
                true,
              ).then((picks) {
                if (picks != null) {
                  client.saveSuperFanPlays(picks);
                } else {
                  // Dismissed without OK: the stored choice stands, but the
                  // host still has to hear from this device, so it gets
                  // announced instead of waiting for an answer.
                  client.superFanNothingToAsk();
                }
              });
            });
          }
          return const SizedBox(width: 0, height: 0);
        });
  }
}

/// Swerski: a passing panel entry when a device joins the SuperNetwork:
/// "Da Bears! Hatchet's phone is on the SuperNetwork", or "The table" when it
/// plays nothing. Reads the transient announcement the host sets for itself
/// and the client sets from the host's `joined` message.
class SuperFanJoinBannerNotifier extends StatelessWidget {
  const SuperFanJoinBannerNotifier({super.key, this.network, this.gameState});

  // injected for testing
  final Network? network;
  final GameState? gameState;

  @override
  Widget build(BuildContext context) {
    final network = this.network ?? getIt<Network>();
    return ValueListenableBuilder<SwerskiFan?>(
        valueListenable: network.superFanJoined,
        builder: (context, fan, child) {
          if (fan != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Clear before showing so the next arrival can fire again.
              network.superFanJoined.value = null;
              if (!context.mounted) return;
              final l10n = AppLocalizations.of(context);
              if (l10n == null) return;
              final names =
                  GameMethods.superFanPlaysNames(fan.plays, gameState: gameState);
              final text = names.isEmpty
                  ? l10n.superFanBannerTable
                  : l10n.superFanBannerPhone(names.join(' & '));
              MessagePanel.instance
                  .add(MessageEntry(MessageKind.banner, text));
            });
          }
          return const SizedBox(width: 0, height: 0);
        });
  }
}

class AutoAddDialogTrigger extends StatelessWidget {
  const AutoAddDialogTrigger({super.key, this.gameState});

  final GameState? gameState;

  @override
  Widget build(BuildContext context) {
    final gameState = this.gameState ?? getIt<GameState>();
    return ValueListenableBuilder<List<RoomMonsterData>?>(
        valueListenable: gameState.pendingAutoAddDialog,
        builder: (context, monsterData, child) {
          if (monsterData != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                gameState.pendingAutoAddDialog.value = null;
                openDialogWithDismissOption(context,
                    AutoAddStandeeMenu(monsterData: monsterData), false);
              }
            });
          }
          return const SizedBox(width: 0, height: 0);
        });
  }
}

class MainScaffoldBody extends StatelessWidget {
  static const double _kBarBottom = 4.0;
  static const double _kBarLeft = 5.0;
  static const double _kDeckMargin = 4.0;
  const MainScaffoldBody(
      {super.key, this.gameState, this.settings, this.gameData});

  // injected for testing
  final GameState? gameState;
  final Settings? settings;
  final GameData? gameData;

  static bool _attackShowing(Settings? settings) =>
      (settings ?? getIt<Settings>()).attackSeveral.value &&
      attackModeController().isAttacking;

  @override
  Widget build(BuildContext context) {
    final vm = MainScaffoldViewModel(
        gameState: gameState, settings: settings, gameData: gameData);
    final Size screenSize = MediaQuery.of(context).size;

    return ValueListenableBuilder<bool>(
        valueListenable: loading,
        builder: (context, isLoading, child) {
          return Stack(
            children: [
              // Swerski: attack mode covers the board (which stays where it
              // was, scroll position and all) while standees are attacked.
              if (!isLoading)
                ListenableBuilder(
                    listenable: Listenable.merge([
                      (settings ?? getIt<Settings>()).attackSeveral,
                      attackModeController().phase
                    ]),
                    // Hidden, not removed, and keeping its size: an Offstage
                    // board is 0x0 and would shrink this whole Stack, so the
                    // attack screen would get no room (a blank white view).
                    builder: (context, _) => Visibility(
                        visible: !_attackShowing(settings),
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: const MainList())),
              if (!isLoading) const EmptyBoardPrompt(),
              if (!isLoading)
                Positioned.fill(
                    child: ListenableBuilder(
                        listenable: Listenable.merge([
                          (settings ?? getIt<Settings>()).attackSeveral,
                          attackModeController().phase
                        ]),
                        builder: (context, _) => _attackShowing(settings)
                            ? const AttackModePanel()
                            : const SizedBox.shrink())),
              if (isLoading)
                BackGround(
                    child: const Center(
                  child: CircularProgressIndicator(),
                )),
              const ToastNotifier(),
              const HeartAttackToastNotifier(),
              const SuperFanJoinBannerNotifier(),
              const AutoAddDialogTrigger(),
              const SuperFanChoiceDialogTrigger(),
              ValueListenableBuilder<Map<String, CampaignModel>>(
                  valueListenable: vm.modelData,
                  builder: (context, value, child) {
                    return ListenableBuilder(
                        listenable: Listenable.merge([
                          vm.scenario,
                          vm.currentCampaign,
                          vm.lootDeckCardCount,
                          vm.hideLootDeck,
                          vm.showAmdDeckNotifier,
                          vm.showAllyDeck,
                          vm.allyDeckInOGGloom,
                          vm.currentListNotifier,
                        ]),
                        builder: (context, child) {
                          return ValueListenableBuilder<double>(
                              valueListenable: vm.userScalingBars,
                              builder: (context, value, child) {
                                final barScale = vm.userScalingBars.value;
                                final bool hasLootDeck = vm.hasLootDeck;
                                final bool modFitsOnBar =
                                    modifiersFitOnBar(context);
                                return Positioned(
                                    width: screenSize.width,
                                    bottom: barScale * _kBarBottom,
                                    left: barScale * _kBarLeft,
                                    // Swerski: the board scrolls clear of it.
                                    child: ReportBottomOverlayHeight(
                                        child: Column(children: [
                                      Row(
                                          mainAxisAlignment: hasLootDeck
                                              ? MainAxisAlignment.spaceBetween
                                              : MainAxisAlignment.end,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            if (hasLootDeck)
                                              const LootDeckWidget(),
                                            Column(children: [
                                              RepaintBoundary(
                                                  child: CharacterAmdsWidget()),
                                              if (vm.shouldShowAlliesDeck)
                                                Container(
                                                    margin: EdgeInsets.only(
                                                      top: _kDeckMargin *
                                                          barScale,
                                                    ),
                                                    child:
                                                        const ModifierDeckWidget(
                                                      name: 'allies',
                                                    )),
                                              if (!modFitsOnBar &&
                                                  !vm.isButtonsAndBugs &&
                                                  vm.showAmdDeck &&
                                                  // Swerski: unless the deck
                                                  // strip holds it.
                                                  !CharacterAmdsViewModel()
                                                      .holdsMonsterDeck(
                                                          fitsOnBar:
                                                              modFitsOnBar))
                                                Container(
                                                    margin: EdgeInsets.only(
                                                      top: _kDeckMargin *
                                                          barScale,
                                                    ),
                                                    child:
                                                        const ModifierDeckWidget(
                                                      name: '',
                                                    ))
                                            ])
                                          ]),
                                      // Swerski: only when the bottom bar has
                                      // no room for them (a narrow screen).
                                      ValueListenableBuilder<bool>(
                                          valueListenable: sectionsDontFitInBar,
                                          builder: (context, needsRow, _) =>
                                              needsRow
                                                  ? SizedBox(
                                                      width: screenSize.width,
                                                      child: const RepaintBoundary(
                                                          child: SectionList()),
                                                    )
                                                  : const SizedBox.shrink()),
                                    ])));
                              });
                        });
                  }),
              // Swerski: drawn last, above the deck corners: messages must
              // never hide under the decks, and only they take taps.
              const MessagePanelNotifier()
            ],
          );
        });
  }
}
