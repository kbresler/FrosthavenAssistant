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
import '../Resource/scaling.dart';
import '../Resource/settings.dart';
import '../Resource/ui_utils.dart';
import '../services/service_locator.dart';
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

class ToastNotifier extends StatelessWidget {
  static const int _kWoundToastSeconds = 6;

  const ToastNotifier({super.key, this.gameState});

  // injected for testing
  final GameState? gameState;

  @override
  Widget build(BuildContext context) {
    final gameState = this.gameState ?? getIt<GameState>();
    return ValueListenableBuilder<String>(
        valueListenable: gameState.toastMessage,
        builder: (context, value, child) {
          Future.delayed(const Duration(milliseconds: 200), () {
            String message = gameState.toastMessage.value;
            if (message != "") {
              if (context.mounted) {
                // Swerski: the newest message replaces the one on screen
                // instead of queueing behind a sticky message forever.
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                showToastSticky(context, message);
                // Wound messages are short-lived, also when undo or a
                // network update brings an old one back.
                if (message.startsWith(commandL10n.toastWoundDamage(''))) {
                  Future.delayed(const Duration(seconds: _kWoundToastSeconds),
                      () {
                    if (gameState.toastMessage.value == message) {
                      GameUtilMethods.setToastMessage('',
                          gameState: gameState);
                    }
                  });
                }
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
              }
            }
          });

          return const SizedBox(
            width: 0,
            height: 0,
          );
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
              const AutoAddDialogTrigger(),
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
