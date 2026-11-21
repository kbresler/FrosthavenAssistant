import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Layout/draw_button.dart';
import 'package:frosthaven_assistant/Layout/view_models/bottom_bar_view_model.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/services/network/network_ui.dart';

import '../Resource/settings.dart';
import '../Resource/state/game_state.dart';
import '../Resource/ui_utils.dart';
import 'ModifierDeckWidget/modifier_deck_widget.dart';
import 'bottom_bar_level_widget.dart';
import 'section_list.dart';
import 'view_models/main_scaffold_view_model.dart';
import '../services/service_locator.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({super.key, this.settings, this.gameState});

  final Settings? settings;
  final GameState? gameState;

  @override
  Widget build(BuildContext context) {
    final vm = BottomBarViewModel(settings: settings, gameState: gameState);
    return ValueListenableBuilder<double>(
        valueListenable: vm.userScalingBars,
        builder: (context, value, child) {
          final barScale = vm.userScalingBars.value;
          return RepaintBoundary(
              child: SizedBox(
                  height: kBarHeight * barScale,
                  child: Stack(children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: ValueListenableBuilder<bool>(
                          valueListenable: vm.darkMode,
                          builder: (context, value, child) {
                            return Container(
                                height: kBarHeight * barScale,
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  color: vm.backgroundColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      // Full-screen-width blur: one of the
                                      // more expensive passes on this screen.
                                      blurRadius:
                                          reducePowerEnabled() ? 0 : 10,
                                      offset: const Offset(0, -4),
                                    )
                                  ],
                                  image: DecorationImage(
                                      opacity: vm.backgroundOpacity,
                                      image: ResizeImage(
                                          AssetImage(vm.backgroundImagePath),
                                          height: quantizeDecodeSize(
                                              kBarHeight * barScale,
                                              quantum: kBarDecodeSizeQuantum)),
                                      fit: BoxFit.cover,
                                      repeat: ImageRepeat.repeatX),
                                ),
                                child: Row(
                                  children: [
                                    const DrawButton(),
                                    // Swerski: the scenario and level sit by
                                    // the Draw button, the section buttons
                                    // next, and what is left of the bar
                                    // goes to them (they scroll if there are
                                    // more than fit).
                                    BottomBarLevelWidget(),
                                    Expanded(
                                        child: _SectionsInBar(
                                            settings: settings,
                                            gameState: gameState)),
                                    const NetworkUI(),
                                    if (vm.showModifierDeck(context))
                                      const ModifierDeckWidget(name: '')
                                  ],
                                ));
                          }),
                    )
                  ])));
        });
  }
}

/// Swerski: true when the bottom bar has no room for the section buttons (a
/// narrow screen), so the main screen shows them in a row above the bar
/// instead, as it always did.
final ValueNotifier<bool> sectionsDontFitInBar = ValueNotifier<bool>(false);

/// The scenario's section buttons, in the bottom bar. Shown under the same
/// conditions as before (the setting is on, and some are still to be added);
/// a row that scrolls sideways when there are more than fit. With room for
/// less than one button, it steps aside (see [sectionsDontFitInBar]).
class _SectionsInBar extends StatelessWidget {
  static const double _kFitWidth = 60.0;

  const _SectionsInBar({this.settings, this.gameState});

  final Settings? settings;
  final GameState? gameState;

  // Not while building: listeners rebuild the main screen.
  void _report(bool dontFit) {
    if (sectionsDontFitInBar.value == dontFit) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sectionsDontFitInBar.value = dontFit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = MainScaffoldViewModel(gameState: gameState, settings: settings);
    final barSettings = settings ?? getIt<Settings>();
    return ListenableBuilder(
        listenable: Listenable.merge([
          vm.scenario,
          vm.currentCampaign,
          vm.scenarioSectionsVersion,
          vm.modelData,
          barSettings.showSectionsInMainView,
          barSettings.userScalingBars,
        ]),
        builder: (context, _) {
          if (vm.availableSections == null) {
            _report(false);
            return const SizedBox.shrink();
          }
          return LayoutBuilder(builder: (context, box) {
            final fits =
                box.maxWidth >= _kFitWidth * barSettings.userScalingBars.value;
            _report(!fits);
            if (!fits) return const SizedBox.shrink();
            return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Center(
                    child:
                        SectionList(settings: settings, gameState: gameState)));
          });
        });
  }
}
