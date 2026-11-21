import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double _kInfoIconSize = 20;
const double _kInfoTapTarget = 32;

/// Small ⓘ button that opens a dialog explaining what a setting trades away.
///
/// Sized down from the default 48px tap target so it can sit inline next to a
/// label without making the row taller than its neighbours.
class SettingsInfoButton extends StatelessWidget {
  const SettingsInfoButton({
    super.key,
    required this.infoTitle,
    required this.infoText,
  });

  final String infoTitle;
  final String infoText;

  void _show(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(infoTitle),
        content: SingleChildScrollView(child: Text(infoText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: infoTitle,
      iconSize: _kInfoIconSize,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: _kInfoTapTarget,
        minHeight: _kInfoTapTarget,
      ),
      onPressed: () => _show(context),
    );
  }
}

/// Swerski: a group heading in the settings list.
class SettingsHeading extends StatelessWidget {
  static const double _kPaddingLeft = 16.0;
  static const double _kPaddingTop = 20.0;
  static const double _kPaddingBottom = 4.0;

  const SettingsHeading(this.title, {super.key, this.trailing});

  final String title;

  /// Shown right after the title, e.g. a [SettingsInfoButton].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(title,
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
    final trailing = this.trailing;
    return Container(
      constraints: const BoxConstraints(minWidth: double.infinity),
      padding: const EdgeInsets.only(
          left: _kPaddingLeft, top: _kPaddingTop, bottom: _kPaddingBottom),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: trailing == null
          ? label
          : Row(children: [Flexible(child: label), trailing]),
    );
  }
}

class SettingsCheckbox extends StatelessWidget {
  const SettingsCheckbox({
    super.key,
    required this.title,
    required this.notifier,
    required this.onChanged,
    this.infoTitle,
    this.infoText,
  });

  final String title;
  final ValueListenable<bool> notifier;
  final ValueChanged<bool> onChanged;

  /// Heading for the explanation dialog. Required alongside [infoText].
  final String? infoTitle;

  /// When set, an info button appears next to the checkbox that opens a dialog
  /// describing what the setting trades away. For settings whose effects are
  /// not self-evident from the label.
  final String? infoText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) => CheckboxListTile(
        title: infoText == null
            ? Text(title)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible so a long label wraps rather than pushing the
                  // button off the row.
                  Flexible(child: Text(title)),
                  SettingsInfoButton(
                    infoTitle: infoTitle ?? title,
                    infoText: infoText ?? '',
                  ),
                ],
              ),
        value: value,
        onChanged: (newValue) => onChanged(newValue ?? false),
      ),
    );
  }
}
