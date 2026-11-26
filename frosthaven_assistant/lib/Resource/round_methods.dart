part of 'state/game_state.dart';
// ignore_for_file: library_private_types_in_public_api

class RoundMethods {
  static const int _kMaxLevel = 7;
  static const int _kMinLevel = 0;
  static void setRoundState(_StateModifier _, RoundState state,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._roundState.value = state;
  }

  static void setRound(_StateModifier _, int round, {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._round.value = round;
    gs._totalRounds.value++;
  }

  static void resetRound(_StateModifier _, int round, bool resetTotal,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._round.value = round;
    if (resetTotal) {
      gs._totalRounds.value = round;
    }
  }

  static void sortCharactersFirst(_StateModifier _, {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._currentList.sort(_compareForCharactersFirst);
    // Sorting compares note rows as initiative 0, scattering them; re-glue any
    // linked notes back under their target. Callers that notify via
    // updateList.notify() (e.g. DrawCommand) bypass _notifyCurrentList, so the
    // reflow must happen here rather than only in _notifyCurrentList.
    gs._reflowNoteRows();
  }

  static int _compareForCharactersFirst(ListItemData a, ListItemData b) {
    final deadResult = _compareDeadCharacters(a, b);
    if (deadResult != null) return deadResult;

    final aIsChar = a is Character;
    final bIsChar = b is Character;
    if (aIsChar && bIsChar) return 0;
    if (bIsChar) return 1;
    if (aIsChar) return -1;

    // both are monsters — inactive at bottom
    if (a is Monster && b is Monster) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
    }
    return -1;
  }

  // Returns a sort result if either figure is a dead character (dead go last),
  // or null if neither is dead and the caller should continue comparing.
  static int? _compareDeadCharacters(ListItemData a, ListItemData b) {
    final aIsDead = a is Character && a.characterState.health.value == 0;
    final bIsDead = b is Character && b.characterState.health.value == 0;
    if (!aIsDead && bIsDead) return -1;
    if (aIsDead && !bIsDead) return 1;
    if (aIsDead) return -1; // both dead characters
    return null;
  }

  static void sortItemToPlace(_StateModifier _, String id, int initiative,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    final newList = gs.currentList.toList();
    ListItemData? item;
    int currentTurnItemIndex = 0;
    for (int i = 0; i < newList.length; i++) {
      if (newList[i].turnState.value == TurnsState.current) {
        currentTurnItemIndex = i;
      }
      if (newList[i].id == id) {
        item = newList.removeAt(i);
      }
    }
    if (item == null) {
      return;
    }

    int init = 0;
    for (int i = 0; i < newList.length; i++) {
      ListItemData currentItem = newList[i];
      int currentItemInitiative = GameMethods.getInitiative(currentItem);
      if (currentItemInitiative > initiative && currentItemInitiative > init) {
        if (i > currentTurnItemIndex) {
          newList.insert(i, item);
          gs._currentList = newList;
          gs._notifyCurrentList();
          return;
        } else {
          //in case initiative is earlier than current turn, ignore anything current turn, and earlier and place later
          int insertIndex = currentTurnItemIndex + 1;
          for (int j = currentTurnItemIndex + 1; j < newList.length; j++) {
            if (GameMethods.getInitiative(newList[j]) >= initiative) {
              insertIndex = j;
              break;
            }
          }
          if(insertIndex > newList.length) {
            newList.add(item);
          } else {
            newList.insert(insertIndex, item);
          }

          gs._currentList = newList;
          gs._notifyCurrentList();
          return;
        }
      }
      init =
          currentItemInitiative; //this check is for the case user has moved items around the order may be off
    }

    newList.add(item);
    gs._currentList = newList;
    gs._notifyCurrentList();
  }

  static void sortByInitiative(_StateModifier _, {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._currentList.sort((a, b) {
      final deadResult = _compareDeadCharacters(a, b);
      if (deadResult != null) return deadResult;

      int aInitiative = 0;
      int bInitiative = 0;
      if (a is Character) {
        aInitiative = a.characterState.initiative.value;
      } else if (a is Monster) {
        if (!a.isActive) {
          if (b is Monster && !b.isActive) {
            return -1;
          }
          return 1; //inactive at bottom
        }

        //find the deck
        for (final item in gs.currentAbilityDecks) {
          if (item.name == a.type.deck && item.discardPileIsNotEmpty) {
            aInitiative = item.discardPileTop.initiative;
          }
        }
      }
      if (b is Character) {
        bInitiative = b.characterState.initiative.value;
      } else if (b is Monster) {
        if (!b.isActive) {
          if (a is Monster && !a.isActive) {
            return 1;
          }
          return -1; //inactive at bottom
        }
        //find the deck
        for (final item in gs.currentAbilityDecks) {
          if (item.name == b.type.deck && item.discardPileIsNotEmpty) {
            bInitiative = item.discardPileTop.initiative;
          }
        }
      }
      return aInitiative.compareTo(bInitiative);
    });
    // Re-glue linked note rows after the initiative sort (see sortCharactersFirst).
    gs._reflowNoteRows();
  }

  static void sortMonsterInstances(
      _StateModifier _, List<MonsterInstance> instances) {
    instances.sort((a, b) {
      if (a.type == MonsterType.elite && b.type != MonsterType.elite) {
        return -1;
      }
      if (b.type == MonsterType.elite && a.type != MonsterType.elite) {
        return 1;
      }
      return a.standeeNr.compareTo(b.standeeNr);
    });
  }

  static void addToMainList(_StateModifier _, int? index, ListItemData item,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    final newList = gs.currentList.toList();
    if (index != null) {
      newList.insert(index, item);
    } else {
      newList.add(item);
    }
    gs._currentList = newList;
    gs._notifyCurrentList();
  }

  static void reorderMainList(_StateModifier _, int newIndex, int oldIndex,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._currentList.insert(newIndex, gs._currentList.removeAt(oldIndex));
    gs._notifyCurrentList();
  }

  static void removeFromMainList(_StateModifier _, String id,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._currentList = gs._currentList.where((item) => item.id != id).toList();
    gs._notifyCurrentList();
  }

  /// Deletes any note rows tied to a specific standee ([standeeNr] > 0) of the
  /// monster [linkedId] — called when that standee is defeated so its note goes
  /// with it. Notes for the whole group (standeeNr 0) are left alone.
  static void removeNoteRowsForStandee(
      _StateModifier _, String linkedId, int standeeNr,
      {GameState? gameState}) {
    if (standeeNr <= 0) return;
    final gs = gameState ?? getIt<GameState>();
    final filtered = gs._currentList
        .where((item) => !(item is NoteRow &&
            item.linkedId.value == linkedId &&
            item.standeeNr.value == standeeNr))
        .toList();
    if (filtered.length != gs._currentList.length) {
      gs._currentList = filtered;
      gs._notifyCurrentList();
    }
  }

  static void updateForSpecialRules(_StateModifier _,
      {GameState? gameState, GameData? gameData}) {
    final gs = gameState ?? getIt<GameState>();
    final gd = gameData ?? getIt<GameData>();
    List<SpecialRule>? rules = gd.modelData.value[gs.currentCampaign.value]
        ?.scenarios[gs.scenario.value]?.specialRules;
    if (rules != null) {
      for (SpecialRule rule in rules) {
        if (rule.type == "Objective" || rule.type == "Escort") {
          Character? character = gs.currentList
                  .firstWhereOrNull((element) => element.id == rule.name)
              as Character?;
          if (character != null) {
            int? newHealth =
                StatCalculator.calculateFormula(rule.health.toString());
            if (newHealth != character.characterState.maxHealth.value &&
                newHealth != null) {
              character.characterState._maxHealth.value = newHealth;
              character.characterState._health.value = newHealth;
            }
          }
        } else if (rule.type == "LevelAdjust") {
          Monster? monster = gs.currentList
                  .firstWhereOrNull((element) => element.id == rule.name)
              as Monster?;
          if (monster != null) {
            if (gs.level.value == monster.level.value) {
              int newLevel = (monster.level.value + rule.level)
                  .clamp(_kMinLevel, _kMaxLevel);
              monster._level.value = newLevel;
              for (MonsterInstance instance in monster._monsterInstances) {
                instance._setLevel(monster);
              }
            }
          }
        }
      }
    }
  }

  static void clearTurnStateConditions(
      _StateModifier _, FigureState figure, bool clearLastTurnToo) {
    if (!clearLastTurnToo) {
      figure._conditionsAddedPreviousTurn.clear();
      figure._conditionsAddedPreviousTurn
          .addAll(figure.conditionsAddedThisTurn.toSet());
    } else {
      figure._conditionsAddedPreviousTurn.clear();
    }

    figure._conditionsAddedThisTurn.clear();
    figure._woundTakenThisRound = false;

    figure._chill.value =
        figure.conditions.value.where((a) => a == Condition.chill).length;
  }

  static void clearTurnState(
      _StateModifier stateModifier, bool clearLastTurnToo,
      {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    for (final item in gs._currentList) {
      item._turnState.value = TurnsState.notDone;
      if (item is Monster) {
        _setAllStandeeTurns(item, TurnsState.notDone);
      }
      if (item is Character) {
        clearTurnStateConditions(
            stateModifier, item.characterState, clearLastTurnToo);
        for (final instance in item.characterState._summonList) {
          clearTurnStateConditions(stateModifier, instance, clearLastTurnToo);
        }
      } else if (item is Monster) {
        for (final instance in item._monsterInstances) {
          clearTurnStateConditions(stateModifier, instance, clearLastTurnToo);
        }
      }
    }
  }

  static void removeExpiringConditions(_StateModifier _, FigureState figure,
      {Settings? settings}) {
    if ((settings ?? getIt<Settings>()).expireConditions.value) {
      final conditions = figure._conditions.value;

      //handle chill separately
      int nrOfChills =
          figure.conditions.value.where((a) => a == Condition.chill).length;
      if (nrOfChills > 0) {
        //remove one if not added this turn
        if (!figure.conditionsAddedThisTurn.contains(Condition.chill) ||
                nrOfChills >
                    1 //this is a cop out: you can add more than one chill in a round, but since we store only if a condition has been added this turn, and not the amount, we have no way to tell
            ) {
          conditions.remove(Condition.chill);
          figure._conditionsAddedPreviousTurn.add(Condition.chill);
        }
      }

      figure._chill.value =
          figure.conditions.value.where((a) => a == Condition.chill).length;

      for (int i = conditions.length - 1; i >= 0; i--) {
        Condition item = conditions[i];
        if (GameMethods.canExpire(item)) {
          if (item != Condition.chill) {
            if (!figure.conditionsAddedThisTurn.contains(item)) {
              conditions.removeAt(i);
              figure._conditionsAddedPreviousTurn.add(item);
            }
          }
        }
      }
    }
  }

  static void removeExpiringConditionsFromListItem(
      _StateModifier s, ListItemData item) {
    if (item is Character) {
      removeExpiringConditions(s, item.characterState);
      for (final summon in item.characterState._summonList) {
        removeExpiringConditions(s, summon);
      }
    } else if (item is Monster) {
      for (final instance in item._monsterInstances) {
        removeExpiringConditions(s, instance);
      }
    }
  }

  static void reapplyConditions(_StateModifier _, FigureState figure) {
    for (final condition in figure.conditionsAddedPreviousTurn) {
      final conditions = figure._conditions.value;
      if (!conditions.contains(condition) || condition == Condition.chill) {
        conditions.add(condition);
        figure._conditionsAddedThisTurn.remove(condition);
      }
      if (condition == Condition.chill) {
        figure._chill.value =
            figure.conditions.value.where((a) => a == Condition.chill).length;
      }
    }
  }

  static void reapplyConditionsFromListItem(
      _StateModifier s, ListItemData item) {
    if (item is Character) {
      reapplyConditions(s, item.characterState);
      for (final summon in item.characterState.summonList) {
        reapplyConditions(s, summon);
      }
    } else if (item is Monster) {
      for (final instance in item._monsterInstances) {
        reapplyConditions(s, instance);
      }
    }
  }

  //1 if item WAS done OR not done, then set it to current, all before to done, and all after to not done
  //2 if item was current: set item to done, all before to done, next to current and rest to not done
  static void setTurnDone(_StateModifier s, int index,
      {GameState? gameState, Settings? settings}) {
    final gs = gameState ?? getIt<GameState>();
    final perStandee = _perStandeeTurns(settings);
    //set all before to done.
    for (int i = 0; i < index; i++) {
      if (gs.currentList[i].turnState.value != TurnsState.done) {
        _finishTurn(s, gs.currentList[i], perStandee);
      }
    }
    //if on index is NOT current then set to current else set to done
    int newIndex = index + 1;
    final indexItem = gs.currentList[index];
    if (indexItem.turnState.value == TurnsState.current) {
      // Swerski: a monster group plays one standee at a time. Tapping the
      // group finishes the current standee; the group is done after the last.
      if (perStandee &&
          indexItem is Monster &&
          _advanceStandeeTurn(s, indexItem)) {
        return;
      }
      //remove expiring conditions
      _finishTurn(s, indexItem, perStandee);
    } else {
      newIndex = index;
    }

    //get next active item and set to current
    for (; newIndex < gs.currentList.length; newIndex++) {
      ListItemData data = gs.currentList[newIndex];
      if (data is Monster) {
        if (data.isActive && !GameMethods.isInactiveForRule(data.type.name)) {
          // Per standee, _startStandeeTurns gives conditions back itself, to
          // only the standees that go again.
          if (!perStandee && data.turnState.value == TurnsState.done) {
            reapplyConditionsFromListItem(s, data);
          }
          data._turnState.value = TurnsState.current;
          if (perStandee) {
            _startStandeeTurns(s, data);
            if (_noOneCanAct(data)) {
              // All stunned: the turn passes straight to the next figure.
              _finishTurn(s, data, perStandee);
              continue;
            }
          }
          break;
        }
      } else if (data is Character) {
        if (data.characterState.health.value > 0) {
          if (data.turnState.value == TurnsState.done) {
            reapplyConditionsFromListItem(s, data);
          }
          data._turnState.value = TurnsState.current;
          break;
        }
      }
    }
    //set rest to not done
    for (int i = newIndex + 1; i < gs.currentList.length; i++) {
      final item = gs.currentList[i];
      if (perStandee && item is Monster) {
        // A group can be part way through: only standees that went lost any.
        _reapplyToDoneStandees(s, item);
      } else if (item.turnState.value == TurnsState.done) {
        reapplyConditionsFromListItem(s, item);
      }
      item._turnState.value = TurnsState.notDone;
      _setAllStandeeTurns(item, TurnsState.notDone);
    }
  }

  /// Ends any turn still going, for the end of a round: with one standee at a
  /// time, a group can be left with standees that never went.
  static void finishCurrentTurns(_StateModifier s,
      {GameState? gameState, Settings? settings}) {
    final gs = gameState ?? getIt<GameState>();
    for (final item in gs.currentList) {
      if (item.turnState.value == TurnsState.current) {
        _finishTurn(s, item, _perStandeeTurns(settings));
      }
    }
  }

  /// Marks [item]'s turn over and drops what expires with it. Per standee,
  /// those that already had their own turn have dropped theirs.
  static void _finishTurn(
      _StateModifier s, ListItemData item, bool perStandee) {
    item._turnState.value = TurnsState.done;
    if (perStandee && item is Monster) {
      for (final instance in item._monsterInstances) {
        if (instance._turnState != TurnsState.done) {
          _finishStandeeTurn(s, instance);
        }
      }
    } else {
      _setAllStandeeTurns(item, TurnsState.done);
      removeExpiringConditionsFromListItem(s, item);
    }
  }

  static void _finishStandeeTurn(_StateModifier s, MonsterInstance instance) {
    instance._turnState = TurnsState.done;
    removeExpiringConditions(s, instance);
  }

  static void _reapplyToDoneStandees(_StateModifier s, Monster monster) {
    for (final instance in monster._monsterInstances) {
      if (instance._turnState == TurnsState.done) {
        reapplyConditions(s, instance);
      }
    }
  }

  /// Makes [item] the current figure, as at the start of the round. With
  /// per-standee turns on, a monster group's first standee becomes current too.
  static void startTurn(_StateModifier s, ListItemData item,
      {GameState? gameState, Settings? settings}) {
    item._turnState.value = TurnsState.current;
    if (item is Monster && _perStandeeTurns(settings)) {
      _startStandeeTurns(s, item);
      if (_noOneCanAct(item)) {
        // All stunned: finish this group and start the next figure.
        final gs = gameState ?? getIt<GameState>();
        setTurnDone(s, gs.currentList.indexOf(item),
            gameState: gs, settings: settings);
      }
    }
  }

  /// After [_startStandeeTurns]: true when every standee still to go was
  /// stunned, so the group's turn is over as soon as it starts.
  static bool _noOneCanAct(Monster monster) =>
      monster._monsterInstances.isNotEmpty &&
      !monster._monsterInstances.any((i) => i.turnState == TurnsState.current);

  /// Called after the current standee of [monster] was removed mid-turn (for
  /// example killed by wound damage at the start of its turn). Moves on to the
  /// next standee, or ends the group's turn if none are left.
  static void continueAfterStandeeRemoved(_StateModifier s, Monster monster,
      {GameState? gameState, Settings? settings}) {
    final gs = gameState ?? getIt<GameState>();
    if (monster.turnState.value != TurnsState.current ||
        !_perStandeeTurns(settings)) {
      return;
    }
    if (monster._monsterInstances
        .any((i) => i.turnState == TurnsState.current)) {
      return;
    }
    if (_advanceStandeeTurn(s, monster)) {
      return;
    }
    final index = gs.currentList.indexOf(monster);
    if (index >= 0) {
      setTurnDone(s, index, gameState: gs, settings: settings);
    }
  }

  static bool _perStandeeTurns(Settings? settings) {
    if (settings != null) {
      return settings.perStandeeTurns.value;
    }
    if (!getIt.isRegistered<Settings>()) {
      return false;
    }
    return getIt<Settings>().perStandeeTurns.value;
  }

  static void _setAllStandeeTurns(ListItemData item, TurnsState state) {
    if (item is Monster) {
      for (final instance in item._monsterInstances) {
        instance._turnState = state;
      }
    }
  }

  /// Starts (or restarts) a group's turn. Standees that already acted this
  /// round stay done, so only those still to go take a turn (for example new
  /// standees revealed by a door after the group went). If every standee has
  /// already acted, it is a deliberate replay and they all go again.
  static void _startStandeeTurns(_StateModifier s, Monster monster) {
    for (final instance in monster._monsterInstances) {
      if (instance._turnState == TurnsState.current) {
        instance._turnState = TurnsState.notDone;
      }
    }
    final someStillToGo = monster._monsterInstances.any((i) =>
        i._turnState == TurnsState.notDone && i.health.value > 0);
    if (!someStillToGo) {
      _reapplyToDoneStandees(s, monster);
      _setAllStandeeTurns(monster, TurnsState.notDone);
    }
    _advanceStandeeTurn(s, monster);
  }

  /// Finishes the current standee (if any) and makes the next one that hasn't
  /// acted current. Stunned standees lose their turn and are skipped, but are
  /// marked so the start-of-turn effects still reach them.
  /// Returns false when no standee is left to act.
  static bool _advanceStandeeTurn(_StateModifier s, Monster monster) {
    for (final instance in monster._monsterInstances) {
      if (instance._turnState == TurnsState.current) {
        _finishStandeeTurn(s, instance);
      }
    }
    for (final instance in monster._monsterInstances) {
      if (instance._turnState != TurnsState.notDone ||
          instance.health.value <= 0) {
        continue;
      }
      if (instance.conditions.value.contains(Condition.stun)) {
        _finishStandeeTurn(s, instance);
        instance._skippedForStun = true;
        continue;
      }
      instance._turnState = TurnsState.current;
      return true;
    }
    return false;
  }
}
