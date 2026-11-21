import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

final _linuxFallback = !kIsWeb && Platform.isLinux
    ? const ['NotoSans', 'NotoSansKR', 'NotoSansSC', 'NotoSansTC', 'NotoSansThai']
    : const <String>[];

final theme = ThemeData(
  useMaterial3: false,
  primarySwatch: Colors.lightBlue,
  fontFamily: 'Pirata',
  fontFamilyFallback: _linuxFallback,
);

// Swerski: parchment popups with a dark-red accent (Settings.parchmentMenus).
const Color kParchment = Color(0xFFF2E6C9);
const Color kParchmentBorder = Color(0xFF7A5A2E);
const Color kSwerskiAccent = Color(0xFF8E2A1F);
const double kParchmentRadius = 10.0;
const double kParchmentBorderWidth = 2.0;
const double _kSelectionAlpha = 0.3;
const double _kDividerAlpha = 0.4;

/// The bordered panel shape for menu cards when parchment menus are on.
const ShapeBorder kParchmentPanelShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(kParchmentRadius)),
  side: BorderSide(color: kParchmentBorder, width: kParchmentBorderWidth),
);

/// [base] with parchment panels, drawer and dialogs, and the dark-red accent
/// on buttons, checkboxes, radios, sliders and text fields.
ThemeData withParchmentMenus(ThemeData base) {
  const rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(kParchmentRadius)));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: kSwerskiAccent,
      secondary: kSwerskiAccent,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    cardTheme: const CardThemeData(color: kParchment, shape: rounded),
    dialogTheme: const DialogThemeData(
        backgroundColor: kParchment, shape: kParchmentPanelShape),
    drawerTheme: const DrawerThemeData(backgroundColor: kParchment),
    dividerColor: kParchmentBorder.withValues(alpha: _kDividerAlpha),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: kSwerskiAccent,
      selectionHandleColor: kSwerskiAccent,
      selectionColor: kSwerskiAccent.withValues(alpha: _kSelectionAlpha),
    ),
  );
}

final themeFH = ThemeData(
  useMaterial3: false,
  primarySwatch: Colors.lightBlue,
  fontFamily: 'GermaniaOne',
  fontFamilyFallback: _linuxFallback,
);
