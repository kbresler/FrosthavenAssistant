import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/ModifierDeckWidget/modifier_deck_widget.dart';
import 'package:frosthaven_assistant/Layout/background.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../Model/campaign.dart';
import '../Model/room.dart';
import '../Resource/commands/command_l10n.dart';
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

class ToastNotifier extends StatefulWidget {
  static const int _kWoundToastSeconds = 6;

  const ToastNotifier({super.key, this.gameState});

  // injected for testing
  final GameState? gameState;

  @override
  State<ToastNotifier> createState() => _ToastNotifierState();
}

class _ToastNotifierState extends State<ToastNotifier> {
  /// Bumped per show attempt: a wound timer from a replaced or re-queued
  /// message must not clear the bar.
  int _showSeq = 0;

  /// The running wound self-clear, cancelled on dispose so a late-shown
  /// wound cannot outlive the widget.
  Timer? _woundTimer;

  GameState get _gs => widget.gameState ?? getIt<GameState>();

  @override
  void dispose() {
    _showSeq++;
    _woundTimer?.cancel();
    heartAttackLineShown.removeListener(_lineGone);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Swerski: when the heart-attack line lets go of the bar, show whatever
    // message waited for it.
    heartAttackLineShown.addListener(_lineGone);
  }

  void _lineGone() {
    if (heartAttackLineShown.value != null || !mounted) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final message = _gs.toastMessage.value;
      if (message != "") _show(message);
    });
  }

  void _show(String message) {
    if (heartAttackLineShown.value != null) return; // the line has the bar
    final int seq = ++_showSeq;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    showToastSticky(context, message, clearOnDismiss: () => _showSeq == seq);
    // Wound messages are short-lived, also when undo or a network update
    // brings an old one back. The seconds count from when the wound shows.
    if (message.startsWith(commandL10n.toastWoundDamage(''))) {
      _woundTimer = Timer(const Duration(seconds: ToastNotifier._kWoundToastSeconds), () {
        if (!mounted || _showSeq != seq) return;
        if (_gs.toastMessage.value == message) {
          GameUtilMethods.setToastMessage('', gameState: _gs);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: _gs.toastMessage,
        builder: (context, value, child) {
          final messenger = ScaffoldMessenger.of(context);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            final message = _gs.toastMessage.value;
            if (message != "") {
              // Swerski: the newest message replaces the one on screen
              // instead of queueing behind a sticky message forever — but a
              // heart-attack line on the bar gets shown first, and this one
              // waits for it.
              _show(message);
            } else if (heartAttackLineShown.value == null) {
              // Clearing the message must not wipe a line off the bar.
              messenger.clearSnackBars();
            }
          });

          return const SizedBox(
            width: 0,
            height: 0,
          );
        });
  }
}

/// Swerski: shows a heart-attack reply line as a single passing toast, then
/// clears it. Reads the transient (non-synced, non-undoable) notifier the
/// health command sets on the device that applied the change. The line takes
/// the message bar from any sticky message, which shows again once the line
/// is gone (see [ToastNotifier]).
class HeartAttackToastNotifier extends StatelessWidget {
  const HeartAttackToastNotifier({super.key, this.gameState});

  // injected for testing
  final GameState? gameState;

  @override
  Widget build(BuildContext context) {
    final gameState = this.gameState ?? getIt<GameState>();
    return ValueListenableBuilder<String>(
        valueListenable: gameState.heartAttackToast,
        builder: (context, message, child) {
          if (message.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Clear before showing so the same line can fire again later.
              gameState.heartAttackToast.value = "";
              if (context.mounted) _showLine(context, message);
            });
          }
          return const SizedBox(
            width: 0,
            height: 0,
          );
        });
  }

  void _showLine(BuildContext context, String line) {
    // Always take the bar, whatever is on it: a sticky message (a wound, a
    // reminder, even the day-long network error toast) must never queue the
    // line behind it. [showToastSticky] callers see heartAttackLineShown set
    // first, so they know this removal is not their message going away.
    heartAttackLineCount++;
    heartAttackLineShown.value = line;
    final int seq = heartAttackLineCount;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    showToast(context, line)?.closed.whenComplete(() {
      // Only this line's own close lets go: a newer line that already took
      // the bar must not be cleared by this one's dismissal.
      if (heartAttackLineCount == seq && heartAttackLineShown.value == line) {
        heartAttackLineShown.value = null;
      }
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

/// Swerski: a one-passing toast when a device joins the SuperNetwork:
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
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              showToast(context, text);
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
                  })
            ],
          );
        });
  }
}
