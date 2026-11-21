import '../state/game_state.dart';

/// Runs several commands as ONE action, so one Undo reverses all of them.
///
/// Swerski attack mode uses it to change health or conditions on several
/// standees with a single tap.
class GroupCommand extends Command {
  GroupCommand(this.commands, this.label);

  final List<Command> commands;
  final String label;

  @override
  void execute() {
    for (final command in commands) {
      command.execute();
    }
  }

  @override
  String describe() => label;
}
