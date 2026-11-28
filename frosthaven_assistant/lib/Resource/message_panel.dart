import 'dart:async';

import 'package:flutter/foundation.dart';

import 'commands/command_l10n.dart';

/// Swerski: kinds of message the panel stacks. `timed` is everything that
/// just passes by (draw blocked, network info); the rest have their own
/// rules.
enum MessageKind { line, banner, wound, reminder, error, timed }

/// Swerski: one message on the panel: its kind, its text, and for the
/// network error its Retry action.
class MessageEntry {
  const MessageEntry(this.kind, this.text, {this.onRetry});

  final MessageKind kind;
  final String text;

  /// The network error's Retry action; null for every other kind.
  final void Function()? onRetry;

  /// Whether this entry leaves by itself after a while.
  bool get timed => kind != MessageKind.reminder && kind != MessageKind.error;
}

/// Swerski: the message panel's contents — a list of entries, each living
/// on its own timer, nothing replacing anything but its own kind. UI-only:
/// not game state, not saved. The sync with `GameState.toastMessage` lives
/// beside the widget; [onRemoved] is where it hooks in.
class MessagePanel extends ChangeNotifier {
  static const int maxOnScreen = 3;
  static const Duration _kShort = Duration(seconds: 4);
  static const Duration _kWound = Duration(seconds: 6);

  static MessagePanel? _instance;

  /// The app-wide panel: sources reach it without a context, the widget
  /// renders it.
  static MessagePanel get instance => _instance ??= MessagePanel();

  /// Starts a fresh empty panel. Tests only: drops the current one without
  /// notifying.
  static void reset() {
    _instance?.cancelTimers();
    _instance = null;
  }

  /// Called when an entry leaves by tap, timeout or cap drop: [timedOut]
  /// says which. Replacing an entry of the same kind does NOT call this —
  /// the game still owns that message. The rule-5 write-back to
  /// `toastMessage` hangs off this.
  void Function(MessageEntry entry, bool timedOut)? onRemoved;

  bool _visible = true;

  final List<_TimedEntry> _entries = [];

  /// Tells the panel whether the board can be seen (a dialog, the drawer or
  /// a backgrounded app means it cannot). While hidden no timer runs and
  /// none starts — adds and in-place replacements included; on becoming
  /// visible every timed entry gets its full time again.
  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    if (!visible) {
      cancelTimers();
      return;
    }
    for (final e in _entries) {
      _arm(e);
    }
  }

  /// Oldest first; the panel draws newest at the bottom.
  List<MessageEntry> get entries =>
      List<MessageEntry>.unmodifiable(_entries.map((e) => e.entry));

  /// Adds [entry]. A kind that is already on screen (wound, reminder,
  /// error) replaces it in place — a growing reminder keeps its spot;
  /// otherwise, at [maxOnScreen] the oldest entry that expires by itself
  /// makes room first (the oldest overall if none does), so a new message
  /// always shows.
  void add(MessageEntry entry) {
    if (_replacesInPlace(entry.kind)) {
      final sameKind = _entries.indexWhere((e) => e.entry.kind == entry.kind);
      if (sameKind >= 0) {
        _entries[sameKind].timer?.cancel();
        _entries[sameKind] = _withTimer(entry);
        notifyListeners();
        return;
      }
    }
    while (_entries.length >= maxOnScreen) {
      final oldestTimed = _entries.indexWhere((e) => e.entry.timed);
      _drop(oldestTimed >= 0 ? oldestTimed : 0, timedOut: false);
    }
    _entries.add(_withTimer(entry));
    notifyListeners();
  }

  /// Kinds the game keeps exactly one of: a new value of these replaces
  /// the entry instead of stacking another copy.
  bool _replacesInPlace(MessageKind kind) => switch (kind) {
        MessageKind.wound || MessageKind.reminder || MessageKind.error =>
          true,
        MessageKind.line || MessageKind.banner || MessageKind.timed => false,
      };

  /// Removes one entry (a tap on it) and reports it through [onRemoved].
  void remove(MessageEntry entry) {
    final index = _entries.indexWhere((e) => e.entry == entry);
    if (index < 0) return;
    _drop(index, timedOut: false);
  }

  /// Drops the entry of [kind], if any, without [onRemoved]: the game
  /// cleared its message, so there is nothing to write back.
  void removeSilently(MessageKind kind) {
    final index = _entries.indexWhere((e) => e.entry.kind == kind);
    if (index < 0) return;
    _entries[index].timer?.cancel();
    _entries.removeAt(index);
    notifyListeners();
  }

  /// Empties the panel without [onRemoved]: between games or tests, where
  /// no write-back belongs.
  void clearAll() {
    cancelTimers();
    _entries.clear();
    notifyListeners();
  }

  /// Stops every timer without touching the list: the widget calls this on
  /// dispose when the panel outlives it.
  void cancelTimers() {
    for (final e in _entries) {
      e.timer?.cancel();
    }
  }

  @override
  void dispose() {
    cancelTimers();
    _entries.clear();
    super.dispose();
  }

  void _drop(int index, {required bool timedOut}) {
    final entry = _entries.removeAt(index);
    entry.timer?.cancel();
    onRemoved?.call(entry.entry, timedOut);
    notifyListeners();
  }

  _TimedEntry _withTimer(MessageEntry entry) {
    final duration = switch (entry.kind) {
      MessageKind.wound => _kWound,
      MessageKind.reminder || MessageKind.error => null,
      MessageKind.line ||
      MessageKind.banner ||
      MessageKind.timed =>
        _kShort,
    };
    final timed = _TimedEntry(entry, duration);
    if (_visible) _arm(timed);
    return timed;
  }

  void _arm(_TimedEntry e) {
    final duration = e.duration;
    if (duration == null) return;
    e.timer = Timer(duration, () => _expire(e));
  }

  /// An entry's own timer firing: the entry may already be gone (tapped,
  /// replaced or dropped at the cap) — then this is nothing.
  void _expire(_TimedEntry entry) {
    final index = _entries.indexOf(entry);
    if (index < 0) return;
    _drop(index, timedOut: true);
  }
}

class _TimedEntry {
  _TimedEntry(this.entry, this.duration);

  final MessageEntry entry;

  /// How long this entry lives; null for the kinds that stay until removed.
  final Duration? duration;
  Timer? timer;
}

/// Swerski: whether a `toastMessage` value is a wound-damage message
/// (its text decides; see TurnStartWounds).
bool isWoundMessage(String text) =>
    text.isNotEmpty && text.startsWith(commandL10n.toastWoundDamage(''));
