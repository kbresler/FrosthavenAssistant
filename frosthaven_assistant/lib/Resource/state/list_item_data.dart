import '../enums.dart';

class ListItemData {
  late String id;
  TurnsState _turnState = TurnsState.notDone;

  void setTurnState(TurnsState state, {bool init = false}) {
    _turnState = state;
  }

  TurnsState getTurnState() {
    return _turnState;
  }

  bool isTurnState(TurnsState state) {
    return state == _turnState;
  }
}
