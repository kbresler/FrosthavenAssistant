import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Layout/theme.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';

class MenuCard extends StatelessWidget {
  static const double _kDefaultMaxWidth = 400;

  const MenuCard({
    super.key,
    required this.child,
    this.maxWidth = _kDefaultMaxWidth,
    this.cardMargin,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? cardMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        margin: cardMargin,
        // Swerski: brown edge on parchment menus.
        shape: useParchmentMenus() ? kParchmentPanelShape : null,
        child: Stack(children: [
          child,
          Positioned(
            width: kCloseButtonWidth,
            height: kButtonSize,
            right: 0,
            bottom: 0,
            child: TextButton(
              child: Text(
                AppLocalizations.of(context)!.close,
                style: kButtonLabelStyle,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
