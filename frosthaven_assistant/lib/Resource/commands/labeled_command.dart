import '../game_event.dart';
import '../state/game_state.dart';

/// Runs one command but lets the Undo list show a custom label.
///
/// The plain commands describe themselves in generic wording ("Add condition",
/// and a raw figure id when healing); attack mode wants its own style
/// ("−1 health (1)") even when only one standee is involved. Everything
/// except [describe] goes to the wrapped command, including its [event].
class LabeledCommand extends Command {
  LabeledCommand(this.inner, this.label);

  final Command inner;
  final String label;

  @override
  void execute() => inner.execute();

  @override
  void onUndo() => inner.onUndo();

  @override
  GameEvent get event => inner.event;

  @override
  String describe() => label;
}
