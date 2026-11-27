// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get menuSetScenario => 'Szenario festlegen';

  @override
  String get menuAddCharacter => 'Charakter hinzufügen';

  @override
  String get customScenario => 'Custom scenario';

  @override
  String get emptyBoardHint =>
      'Start by choosing a scenario and adding your characters';

  @override
  String get menuRemoveCharacters => 'Charaktere entfernen';

  @override
  String get menuSetLevel => 'Stufe festlegen';

  @override
  String get menuLootDeck => 'Plünderungsstapel';

  @override
  String get menuAddMonsters => 'Monster hinzufügen';

  @override
  String get menuRemoveMonsters => 'Monster entfernen';

  @override
  String get menuShowAllyDeck =>
      'Verbündeten-Angriffs­modifikationsstapel anzeigen';

  @override
  String get menuHideAllyDeck =>
      'Verbündeten-Angriffs­modifikationsstapel ausblenden';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuDocumentation => 'Dokumentation';

  @override
  String get menuDonate => 'Spenden';

  @override
  String get menuExit => 'Beenden';

  @override
  String get menuAddSection => 'Abschnitt hinzufügen';

  @override
  String get menuAddRandomDungeonCard => 'Zufällige Verließkarte hinzufügen';

  @override
  String get menuActionLog => 'Aktionsprotokoll anzeigen';

  @override
  String get actionLogTitle => 'Letzte 20 Aktionen';

  @override
  String get actionLogEmpty => 'Noch keine Aktionen';

  @override
  String get actionLogRollbackHint =>
      'Tippe auf eine Aktion, um dorthin zurückzukehren';

  @override
  String get actionLogRollbackTitle => 'Zurücksetzen?';

  @override
  String actionLogRollbackBody(String action, int count) {
    return 'Zurück zu \"$action\"? Dies macht $count spätere Aktion(en) rückgängig. Du kannst sie wiederherstellen, bis du etwas änderst.';
  }

  @override
  String get actionLogRollbackConfirm => 'Zurücksetzen';

  @override
  String get menuAddNoteRow => 'Notizzeile hinzufügen';

  @override
  String get noteRowTitle => 'Notiz';

  @override
  String get noteRowHint => 'Notiztext…';

  @override
  String get noteRowColourLabel => 'Farbe';

  @override
  String get noteRowConnectLabel => 'Verbinden mit:';

  @override
  String get noteRowConnectNone => 'Nichts (freie Notiz)';

  @override
  String get noteRowConnectPlayer => 'Spieler';

  @override
  String get noteRowConnectMonster => 'Monster';

  @override
  String get noteRowWholeGroup => 'Ganze Gruppe';

  @override
  String get noteRowAll => 'Alle';

  @override
  String noteRowStandeeNr(int nr) {
    return 'Aufsteller $nr';
  }

  @override
  String get noteRowAddFromMenu => 'Notiz hinzufügen';

  @override
  String get noteRowDelete => 'Notiz löschen';

  @override
  String get undo => 'Rückgängig';

  @override
  String undoWithDescription(String description) {
    return 'Rückgängig: $description';
  }

  @override
  String get redo => 'Wiederholen';

  @override
  String redoWithDescription(String description) {
    return 'Wiederholen: $description';
  }

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get connectedAsClient => 'Als Client verbunden';

  @override
  String get connecting => 'Verbinde...';

  @override
  String get cancelConnect => 'Cancel';

  @override
  String get connectionCancelled => 'Connection cancelled';

  @override
  String connectAsClientWithIp(String ip) {
    return 'Als Client verbinden ($ip)';
  }

  @override
  String get connectAsClientLabel => 'Als Client verbinden';

  @override
  String stopServerWithIp(String ip) {
    return 'Server stoppen $ip';
  }

  @override
  String startHostServerWithIp(String ip) {
    return 'Host-Server starten $ip';
  }

  @override
  String get stopServerButton => 'Server stoppen';

  @override
  String get startHostServerButton => 'Host-Server starten';

  @override
  String get networkConnectLocal => 'Geräte im lokalen WLAN verbinden:';

  @override
  String get networkServerIpHint => 'Server-IP-Adresse';

  @override
  String get networkPortHint => 'Port';

  @override
  String get settingsLanguage => 'Sprache:';

  @override
  String get settingsDarkMode => 'Dunkelmodus';

  @override
  String get settingsSoftNumpad => 'Soft-Nummernblock für Eingabe';

  @override
  String get settingsNoInit => 'Nicht nach Initiative fragen';

  @override
  String get settingsGroupSwerski => 'Swerski Edition';

  @override
  String get settingsGroupGameplay => 'Gameplay';

  @override
  String get settingsGroupDisplay => 'Display';

  @override
  String get settingsGroupOther => 'Other';

  @override
  String get settingsExpireConditions => 'Zustände ablaufen lassen';

  @override
  String get settingsPerStandeeTurns => 'Monster turns one standee at a time';

  @override
  String get settingsAutoApplyWounds => 'Apply wound damage at start of turn';

  @override
  String get settingsStandeeChips => 'Easy-read numbers when adding standees';

  @override
  String get settingsParchmentMenus => 'Parchment menus and popups';

  @override
  String get settingsAttackSeveral => 'Attack several monsters at once';

  @override
  String get settingsHeartAttacks => 'Heart attacks';

  @override
  String get settingsDeviceName => 'Device name';

  @override
  String heartAttackBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count major heart attacks',
      one: '1 major heart attack',
    );
    return '$_temp0';
  }

  @override
  String heartAttackLittleBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count little heart attacks',
      one: '1 little heart attack',
    );
    return '$_temp0';
  }

  @override
  String heartAttackFirstNoted(String victim) {
    return '$victim\'s first heart attack. Noted.';
  }

  @override
  String heartAttackFirstScenario(String victim) {
    return 'That\'s the first heart attack on record. $victim.';
  }

  @override
  String heartAttackFirstBoard(String victim) {
    return '$victim is on the board. One heart attack.';
  }

  @override
  String heartAttackRepeatAgain(String victim, int count) {
    return '$victim again. Heart attack number $count.';
  }

  @override
  String heartAttackRepeatAnyway(String victim, int count) {
    return '$count heart attacks for $victim. Anyway.';
  }

  @override
  String heartAttackRepeatWriteDown(String victim, int count) {
    return '$victim: heart attack number $count. I\'ll write it down.';
  }

  @override
  String heartAttackRepeatRespectable(String victim, int count) {
    return '$victim has $count heart attacks now. Respectable.';
  }

  @override
  String heartAttackRepeatCarryOn(String victim, int count) {
    return 'Heart attack, $victim, $count. Carry on.';
  }

  @override
  String heartAttackLead(String victim, int count) {
    return '$victim takes the lead with $count heart attacks.';
  }

  @override
  String heartAttackOnlyOn(String victim, int count, int speakerCount) {
    return '$victim is on $count heart attacks. I\'m only on $speakerCount.';
  }

  @override
  String heartAttackNotARace(String victim, int count, int speakerCount) {
    return '$count heart attacks for $victim, $speakerCount for me. Not a race.';
  }

  @override
  String heartAttackNotWorried(String victim, int count, int speakerCount) {
    return '$victim has $count heart attacks. I have $speakerCount. I\'m not worried.';
  }

  @override
  String heartAttackJustSaying(String victim, int count, int speakerCount) {
    return '$victim is on $count heart attacks. I\'m on $speakerCount. Just saying.';
  }

  @override
  String heartAttackComfortable(String victim, int count, int speakerCount) {
    return '$victim has $count heart attacks. I\'m on $speakerCount. Comfortable.';
  }

  @override
  String heartAttackTied(String victim, int count) {
    return '$victim and I are level on $count heart attacks.';
  }

  @override
  String heartAttackRecovering(String names) {
    return '$names had a little heart attack and is recovering until their turn (long rest).';
  }

  @override
  String heartAttackRecoveringPlural(String names) {
    return '$names each had a little heart attack and are recovering until their turn (long rest).';
  }

  @override
  String heartAttacksMenuTitle(String hero) {
    return '$hero: heart attacks';
  }

  @override
  String get heartAttacksLittle => 'Little';

  @override
  String get heartAttacksMajor => 'Major';

  @override
  String get heartAttacksEarlier => 'Earlier';

  @override
  String get heartAttacksThisScenario => 'This scenario';

  @override
  String cmdAdjustHeartAttacks(
    String hero,
    String kind,
    String period,
    String sign,
  ) {
    return '$hero: $kind heart attacks $period ($sign)';
  }

  @override
  String get attackSeveralMenu => 'Attack several…';

  @override
  String get attackSeveralTooltip => 'Attack several monsters';

  @override
  String attackSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get attackCancel => 'Cancel';

  @override
  String attackHeader(int active, int total) {
    return 'Attacking $active of $total';
  }

  @override
  String get attackUndo => 'Undo';

  @override
  String attackUndoWith(String what) {
    return 'Undo $what';
  }

  @override
  String get attackDone => 'Done';

  @override
  String get attackSelectAll => 'Select all';

  @override
  String get attackSelectNone => 'Select none';

  @override
  String get attackHarmful => 'Harmful';

  @override
  String get attackHelpful => 'Helpful';

  @override
  String get attackMarks => 'Character marks';

  @override
  String get attackHoldHint => 'Hold a standee for just that one.';

  @override
  String get attackHealthEach => 'Health, each';

  @override
  String get attackBless => 'Bless';

  @override
  String get attackCurse => 'Curse';

  @override
  String get attackChill => 'Chill';

  @override
  String attackKilled(int count) {
    return '$count killed';
  }

  @override
  String get attackAll => 'all';

  @override
  String attackDeckAndLeft(String deck, int left) {
    return '$deck · $left left';
  }

  @override
  String get settingsGameStyleMessages => 'Parchment message banner';

  @override
  String get settingsTurnGlow => 'Green glow on whose turn it is';

  @override
  String get settingsNoStandees => 'Figuren nicht verfolgen';

  @override
  String get settingsAutoAddStandees => 'Figuren automatisch hinzufügen';

  @override
  String get settingsAutoAddSpawns =>
      'Zeitgesteuerte Spawns automatisch hinzufügen';

  @override
  String get settingsRandomStandees => 'Zufällige Figuren';

  @override
  String get settingsNoCalculations => 'Keine Berechnungen';

  @override
  String get settingsHideLootDeck => 'Plünderungsstapel ausblenden';

  @override
  String get settingsShimmer => 'Statuskartentext schimmern lassen';

  @override
  String get settingsPowerModeLabel => 'Power saving';

  @override
  String get powerModeNormal => 'Normal';

  @override
  String get powerModeDimWhenIdle => 'Dim when idle';

  @override
  String get settingsPowerModeInfoTitle => 'Power saving';

  @override
  String get settingsPowerModeInfo =>
      'Three levels of battery saving, from none to most.\n\nNormal — the screen is held awake at full brightness for as long as the app is open. Nothing is dimmed and nothing sleeps. Best while you are actively playing.\n\nDim when idle — the screen is still held awake and the app never locks, but after 30 seconds without input the board dims. The board stays readable from across the table, and a single tap brings it straight back with nothing lost. Good for a game in progress that you glance at between turns.\n\nReduce power use — hands the screen back to your device, so it dims and turns off on its own schedule and you unlock to return. Also lowers drawing quality to save more: card and monster box shadows become hard-edged instead of softly blurred, icons are filtered more cheaply, and shimmering text effects are turned off. Best for infrequent use and low battery capacity devices.\n\nNothing about how the game works changes at any level — no tracking, syncing or rules behaviour is affected.';

  @override
  String get settingsReducePower => 'Reduce power use';

  @override
  String get settingsReducePowerInfoTitle => 'Reduce power use';

  @override
  String get settingsReducePowerInfo =>
      'Saves battery by doing less drawing work, at the cost of some visual polish.\n\nWhat changes:\n\n• The screen is allowed to dim and turn off on its own. Normally this app keeps it awake the whole time it is open, which is by far the biggest drain on a phone or tablet.\n\n• Card and monster box shadows become hard-edged instead of softly blurred.\n\n• Icons are filtered more cheaply. You may notice slightly rougher edges on small images.\n\n• Shimmering text effects are turned off.\n\nNothing about how the game works changes — no tracking, syncing or rules behaviour is affected. You can turn this off again at any time.';

  @override
  String get settingsFhHazTerrainCalc =>
      'Frosthaven-Gefahrengeländeberechnung in OG Gloomhaven verwenden';

  @override
  String get settingsAllyDeckOGGloom =>
      'Verbündeten-Angriffsmodifikationsstapel in OG Gloomhaven verwenden';

  @override
  String get settingsShowScenarioNames => 'Szenarionamen in der Liste anzeigen';

  @override
  String get settingsShowBattleGoalReminder => 'Kampfziel-Erinnerung anzeigen';

  @override
  String get settingsShowCustomContent => 'Benutzerdefinierte Inhalte anzeigen';

  @override
  String get settingsShowSections =>
      'Abschnitte auf dem Hauptbildschirm anzeigen';

  @override
  String get settingsShowReminders =>
      'Erinnerungen für spezielle Rundenregeln anzeigen';

  @override
  String get settingsShowAmdDeck => 'Angriffsmodifikationsstapel anzeigen';

  @override
  String get settingsShowCharacterAmd =>
      'Charakter-Angriffsmodifikationsstapel anzeigen';

  @override
  String get settingsHealthWheel =>
      'Lebensrad aktivieren: Links-rechts ziehen zum Ändern';

  @override
  String get settingsFullscreen => 'Vollbild';

  @override
  String get settingsMainListScaling => 'Hauptlisten-Skalierung:';

  @override
  String get settingsAppBarScaling => 'App-Leisten-Skalierung:';

  @override
  String get settingsStyleLabel => 'Stil:';

  @override
  String get styleFrosthaven => 'Frosthaven';

  @override
  String get styleOriginal => 'Original';

  @override
  String get settingsClearUnlocked =>
      'Freigeschaltete Charaktere und Inhalte zurücksetzen';

  @override
  String get settingsUnlockSpecials => 'Speziales freischalten';

  @override
  String get settingsLoadSaveState => 'Spielstand laden/speichern';

  @override
  String get noResultsFound => 'Keine Ergebnisse gefunden';

  @override
  String get close => 'Schließen';

  @override
  String get retry => 'WIEDERHOLEN';

  @override
  String get specialUnlocks => 'Spezielle Freischaltungen';

  @override
  String get loadSaveDeleteCharacters =>
      'Charaktere laden, speichern oder löschen.';

  @override
  String get loadAddDeleteSaves =>
      'Spielstände laden, hinzufügen oder löschen.';

  @override
  String get addNewSave => 'Neuen Spielstand hinzufügen';

  @override
  String get addNewSaveLabel => 'Neuen Spielstand hinzufügen:';

  @override
  String get loadButton => 'Laden';

  @override
  String get saveButton => 'Speichern';

  @override
  String get deleteButton => 'Löschen';

  @override
  String get setSaveName => 'Speichername festlegen:';

  @override
  String get loadOrSaveCharacters => 'Charaktere laden oder speichern';

  @override
  String get loadCharacter => 'Charakter laden:';

  @override
  String get removeAll => 'Alle entfernen';

  @override
  String get removeCardQuestion => 'Karte entfernen?';

  @override
  String get sendToBottom => 'Nach unten senden';

  @override
  String get shuffleUndrawnCards => 'Nicht gezogene Karten mischen';

  @override
  String get returnToDiscardPile => 'Auf den Ablagestapel zurücklegen';

  @override
  String get returnToDrawPile => 'Auf den Zugstapel zurücklegen';

  @override
  String get addExtraLootCard => 'Zusätzliche Plünderungskarte hinzufügen';

  @override
  String get addStandeeNr => 'Figurennummer hinzufügen';

  @override
  String get summonedLabel => 'Herbeigerufen:';

  @override
  String get characterDecks => 'Charakterstapel';

  @override
  String get deckTabMonsters => 'Monsters';

  @override
  String get deckTabCharacters => 'Characters';

  @override
  String get shuffleAndDraw => 'Mischen\n& Ziehen';

  @override
  String get draw => 'Ziehen';

  @override
  String get nextRound => ' Nächste\nRunde';

  @override
  String get returnTopCard => 'Oberste Karte zurücklegen';

  @override
  String removeCardWithDetails(String title, int nr) {
    return '$title entfernen\n(Karten-Nr.: $nr)';
  }

  @override
  String get tapCardToAddToDeck =>
      'Karte antippen, um sie zum Stapel hinzuzufügen';

  @override
  String get removeCardFromDeckQuestion => 'Karte aus dem Stapel entfernen?';

  @override
  String get changeName => 'Namen ändern:';

  @override
  String get showBosses => 'Bosse anzeigen';

  @override
  String get showScenarioSpecialMonsters =>
      'Spezielle Szenariomonster anzeigen';

  @override
  String get addAsAlly => 'Als Verbündeten hinzufügen';

  @override
  String get addMonsterLabel => 'Monster hinzufügen';

  @override
  String get allCampaigns => 'Alle Kampagnen';

  @override
  String get showMonstersFrom => '      Monster anzeigen von:   ';

  @override
  String setMonsterLevel(String name) {
    return 'Stufe von $name festlegen';
  }

  @override
  String setSummonHealth(String name) {
    return 'Maximale Lebenspunkte von $name festlegen';
  }

  @override
  String get setScenarioLevel => 'Szenariostufe festlegen';

  @override
  String enhancedLevel(String level) {
    return 'Verbessert: $level';
  }

  @override
  String get soloLabel => 'Solo:';

  @override
  String get automaticScenarioLevel => 'Automatische Szenariostufe:';

  @override
  String get difficultyLabel => 'Schwierigkeitsgrad:';

  @override
  String get lootCardEnhancements => 'Plünderungskarten-Verbesserungen';

  @override
  String get addPerks => 'Vorteile hinzufügen';

  @override
  String get useFrosthavenPerks => 'Frosthaven-Vorteile verwenden';

  @override
  String currentCampaign(String campaign) {
    return 'Aktuelle Kampagne: $campaign';
  }

  @override
  String get addCharacterHint =>
      'Charakter hinzufügen (Namen eingeben für versteckte Charakterklassen)';

  @override
  String get trapDamage => 'Fallenschaden';

  @override
  String get hazardousTerrainDamage => 'Gefahrengeländeschaden';

  @override
  String get experienceAdded => 'Erfahrung hinzugefügt';

  @override
  String get goldCoinValue => 'Goldmünzwert';

  @override
  String get levelLegendLabel => 'Stufe';

  @override
  String get saveStateNote =>
      'Bitte beachten: Die App speichert deinen Fortschritt automatisch nach jeder Aktion. Diese Spielstände sind für Sicherheitskopien oder mehrere Kampagnen.';

  @override
  String clientConnectedTo(String address) {
    return 'Client verbunden mit: $address';
  }

  @override
  String clientError(String error) {
    return 'Client-Fehler: $error';
  }

  @override
  String clientListenError(String error) {
    return 'Client-Empfangsfehler: $error';
  }

  @override
  String get lostConnectionToServer => 'Verbindung zum Server verloren';

  @override
  String get stateMismatch =>
      'Dein Spielstand war nicht aktuell, bitte erneut versuchen.';

  @override
  String get serverUnresponsive => 'Server antwortet nicht. Client getrennt.';

  @override
  String get clientDisconnected => 'Client getrennt';

  @override
  String get serverOffline => 'Server offline';

  @override
  String get clientLeft => 'Client hat die Verbindung getrennt.';

  @override
  String get clientTooOld =>
      'Ein veralteter Client hat versucht, sich zu verbinden. Bitte die App aktualisieren.';

  @override
  String networkConnection(String status) {
    return 'Netzwerkverbindung: $status';
  }

  @override
  String get failedToGetWifiIp => 'IP-Adresse konnte nicht ermittelt werden';

  @override
  String get badOmen => 'Böses Omen';

  @override
  String badOmensLeft(int count) {
    return 'Böse Omen übrig: $count';
  }

  @override
  String get corrosiveSpew => 'Ätzender Ausstoß';

  @override
  String get empowersOnTop => 'Stärkt oben auf';

  @override
  String addMinusOneCard(String direction, int count) {
    String _temp0 = intl.Intl.selectLogic(direction, {
      'added': '-1-Karte hinzufügen (hinzugefügt: $count)',
      'removed': '-1-Karte hinzufügen (entfernt: $count)',
      'other': '-1-Karte ($count)',
    });
    return '$_temp0';
  }

  @override
  String get removeMinusOneCard => '-1-Karte entfernen';

  @override
  String get removeMinusTwoCard => '-2-Karte entfernen';

  @override
  String get minusTwoCardRemoved => '-2-Karte entfernt';

  @override
  String get removePlusZeroCard => '+0-Karte entfernen';

  @override
  String get plusZeroCardRemoved => '+0-Karte entfernt';

  @override
  String get removeImbue => 'Einbettung entfernen';

  @override
  String get imbue => 'Einbetten';

  @override
  String get advancedImbue => 'Erweiterte Einbettung';

  @override
  String get removeHailPerk => 'Hagel-Vorteil entfernen';

  @override
  String get addHailPerk => 'Hagel-Vorteil hinzufügen';

  @override
  String get removeCassandraPerk => 'Kassandra-\nVorteil entfernen';

  @override
  String get addCassandraPerk => 'Kassandra-\nVorteil hinzufügen';

  @override
  String get dontSaveRevealedCards => 'Aufgedeckte\nKarten nicht speichern';

  @override
  String get saveRevealedCards => 'Aufgedeckte\nKarten speichern';

  @override
  String removedCountLabel(int count) {
    return 'Entfernt: $count';
  }

  @override
  String get removeDonation => 'Spende\nentfernen';

  @override
  String get donateSanctuary => 'An Heiligtum\nspenden';

  @override
  String get removePartyCard => 'Gruppenkarte\nentfernen:';

  @override
  String get addPartyCard => 'Gruppenkarte\nhinzufügen:';

  @override
  String get perks => 'Vorteile';

  @override
  String get revealCards => 'Karten\naufdecken:';

  @override
  String get revealAll => 'Alle';

  @override
  String get drawExtraCard => 'Zusätzliche Karte ziehen';

  @override
  String get extraShuffle => 'Zusätzlich mischen';

  @override
  String get inactivateMonster => 'Monster\ndeaktivieren';

  @override
  String get activateMonster => 'Monster\naktivieren';

  @override
  String addEliteStandees(int count, String name) {
    return '$count Elite $name hinzufügen';
  }

  @override
  String addNormalStandees(int count, String name) {
    return '$count Normale $name hinzufügen';
  }

  @override
  String get allEliteStandeesPlaced => 'All elites placed';

  @override
  String get allNormalStandeesPlaced => 'All normals placed';

  @override
  String get characterLoot => 'Charakterausbeute';

  @override
  String addSpecialCard(int nr) {
    return 'Karte $nr hinzufügen';
  }

  @override
  String removeSpecialCard(int nr) {
    return 'Karte $nr entfernen';
  }

  @override
  String get enhanceCards => 'Karten verbessern';

  @override
  String get addLootCard => 'Karte hinzufügen';

  @override
  String get returnToTop => 'Nach oben zurücklegen';

  @override
  String get returnToBottom => 'Nach unten zurücklegen';

  @override
  String characterLootTitle(String name) {
    return 'Ausbeute von $name:';
  }

  @override
  String get setLootOwner => 'Besitzer festlegen:';

  @override
  String get lootNameCoin => 'Münze';

  @override
  String get lootNameHide => 'Fell';

  @override
  String get lootNameLumber => 'Holz';

  @override
  String get lootNameMetal => 'Metall';

  @override
  String get lootNameArrowvine => 'Pfeilranke';

  @override
  String get lootNameAxenut => 'Axtmuss';

  @override
  String get lootNameCorpsecap => 'Leichenpilz';

  @override
  String get lootNameFlamefruit => 'Flammenfrucht';

  @override
  String get lootNameRockroot => 'Felswurzel';

  @override
  String get lootNameSnowthistle => 'Schneendistel';

  @override
  String get lootAmount2For2 => '2 für 2 Spieler';

  @override
  String get lootAmount2For23 => '2 für 2-3 Spieler';

  @override
  String cmdActivateMonster(String name) {
    return '$name aktivieren';
  }

  @override
  String cmdDeactivateMonster(String name) {
    return '$name deaktivieren';
  }

  @override
  String cmdAddCharacter(String id) {
    return '$id hinzufügen';
  }

  @override
  String cmdAddCondition(String condition) {
    return 'Zustand hinzufügen: $condition';
  }

  @override
  String cmdRemoveCondition(String condition) {
    return 'Zustand entfernen: $condition';
  }

  @override
  String cmdAddPartyCard(String character, String type) {
    return '$character Gruppenk. $type hinzufügen';
  }

  @override
  String cmdRemovePartyCard(String character) {
    return '$character Gruppenkarte entfernen';
  }

  @override
  String cmdAddFactionCard(String character) {
    return '$character Fraktionskarte hinzufügen';
  }

  @override
  String cmdRemoveFactionCard(String character) {
    return '$character Fraktionskarte entfernen';
  }

  @override
  String cmdAddLootCard(String type) {
    return '$type-Plünderungskarte hinzufügen';
  }

  @override
  String cmdAddMonster(String name) {
    return '$name hinzufügen';
  }

  @override
  String cmdAddSpecialLootCard(int nr) {
    return 'Sonderplünderungskarte $nr hinzufügen';
  }

  @override
  String cmdRemoveSpecialLootCard(int nr) {
    return 'Sonderplünderungskarte $nr entfernen';
  }

  @override
  String get cmdAddMinusOne => '-1 hinzufügen';

  @override
  String get cmdRemoveMinusOne => '-1 entfernen';

  @override
  String get cmdRemoveMinusTwo => '-2 entfernen';

  @override
  String get cmdAddBackMinusTwo => '-2 zurücklegen';

  @override
  String get cmdRemovePlusZero => '+0 entfernen';

  @override
  String get cmdAddBackPlusZero => '+0 zurücklegen';

  @override
  String cmdRevealModifierCards(int count) {
    return '$count Modifikatorkarten aufdecken';
  }

  @override
  String cmdCassandraLeaveRevealed(String deck) {
    return 'Aufgedeckte Karten oben auf Stapel $deck lassen';
  }

  @override
  String cmdCassandraSpecialOff(String deck) {
    return 'Kassandra-Spezial für Stapel $deck deaktiviert';
  }

  @override
  String get cmdImbueMonsterDeck => 'Monsterstapel einbetten';

  @override
  String get cmdAdvancedImbueMonsterDeck => 'Monsterstapel erweitert einbetten';

  @override
  String get cmdRemoveImbueMonsterDeck => 'Einbettung entfernen';

  @override
  String get cmdChangeName => 'Charaktername ändern';

  @override
  String get cmdAddNoteRow => 'Notizzeile hinzufügen';

  @override
  String get cmdSetNoteRowText => 'Notiz bearbeiten';

  @override
  String get cmdSetNoteRowColor => 'Notizfarbe ändern';

  @override
  String get cmdLinkNoteRow => 'Notizzeile verknüpfen';

  @override
  String get cmdRemoveNoteRow => 'Notizzeile entfernen';

  @override
  String get cmdAddBless => 'Segen hinzufügen';

  @override
  String get cmdRemoveBless => 'Segen entfernen';

  @override
  String get cmdAddCurse => 'Fluch hinzufügen';

  @override
  String get cmdRemoveCurse => 'Fluch entfernen';

  @override
  String get cmdAddEmpower => 'Stärkung hinzufügen';

  @override
  String get cmdRemoveEmpower => 'Stärkung entfernen';

  @override
  String get cmdAddEnfeeble => 'Schwächung hinzufügen';

  @override
  String get cmdRemoveEnfeeble => 'Schwächung entfernen';

  @override
  String cmdIncreaseMaxHealth(String owner) {
    return 'Maximale Lebenspunkte von $owner erhöhen';
  }

  @override
  String cmdDecreaseMaxHealth(String owner) {
    return 'Maximale Lebenspunkte von $owner verringern';
  }

  @override
  String get cmdChangeStat => 'Statuswert ändern';

  @override
  String cmdIncreaseXp(String figure, int amount) {
    return 'EP von $figure um $amount erhöhen';
  }

  @override
  String cmdDecreaseXp(String figure, int amount) {
    return 'EP von $figure um $amount verringern';
  }

  @override
  String get cmdClearUnlockedClasses => 'Freigeschaltete Klassen zurücksetzen';

  @override
  String cmdDonateSanctuary(String character) {
    return '$character spendet an Heiligtum';
  }

  @override
  String cmdRemoveSanctuaryDonation(String character) {
    return 'Spende von $character entfernen';
  }

  @override
  String get cmdDrawExtraAbilityCard => 'Zusätzliche Fähigkeitskarte ziehen';

  @override
  String get cmdDraw => 'Ziehen';

  @override
  String get cmdDrawLootCard => 'Plünderungskarte ziehen';

  @override
  String cmdDrawModifierCard(String name) {
    return '$name-Modifikatorkarte ziehen';
  }

  @override
  String get cmdRemoveLootEnhancement => 'Plünderungsverbesserung entfernen';

  @override
  String get cmdAddLootEnhancement => 'Plünderungsverbesserung hinzufügen';

  @override
  String get cmdHideAllyDeck => 'Verbündeten-Stapel ausblenden';

  @override
  String get cmdShowAllyDeck => 'Verbündeten-Stapel anzeigen';

  @override
  String get cmdIceWraithTurnNormal => 'Eisgeist wird normal';

  @override
  String get cmdIceWraithTurnElite => 'Eisgeist wird Elite';

  @override
  String cmdImbueElement(String element) {
    return 'Element $element einbetten';
  }

  @override
  String cmdUseElement(String element) {
    return 'Element $element verbrauchen';
  }

  @override
  String cmdLoadCharacter(String name) {
    return 'Gespeicherten Charakter laden: $name';
  }

  @override
  String cmdLoadGame(String name) {
    return 'Gespeichertes Spiel laden: $name';
  }

  @override
  String get cmdNextRound => 'Nächste Runde';

  @override
  String get cmdRemoveAmdCard => 'AMD-Karte entfernen';

  @override
  String cmdRemoveCard(String deck, int nr) {
    return '$deck-Karte Nr. $nr entfernen';
  }

  @override
  String get cmdRemoveAllCharacters => 'Alle Charaktere entfernen';

  @override
  String cmdRemoveCharacter(String id) {
    return '$id entfernen';
  }

  @override
  String get cmdRemoveAllMonsters => 'Alle Monster entfernen';

  @override
  String cmdRemoveMonster(String name) {
    return '$name entfernen';
  }

  @override
  String get cmdReorderAbilityCards => 'Fähigkeitskarten neu anordnen';

  @override
  String get cmdReorderList => 'Liste neu anordnen';

  @override
  String get cmdReorderModifierCards => 'Modifikatorkarten neu anordnen';

  @override
  String get cmdReturnLootCard => 'Plünderungskarte zurücklegen';

  @override
  String get cmdReturnModifierCard => 'Modifikatorkarte nach oben zurücklegen';

  @override
  String get cmdReturnRemovedAmdCard => 'Entfernte AMD-Karte zurücklegen';

  @override
  String get cmdNoAllyDeckInOgGloom =>
      'Kein Verbündeten-Stapel in 1. Edition Gloomhaven';

  @override
  String get cmdUseAllyDeckInOgGloom =>
      'Verbündeten-Stapel in 1. Edition Gloomhaven verwenden';

  @override
  String cmdMarkAsSummon(String owner) {
    return '$owner als Beschworenen markieren';
  }

  @override
  String cmdRemoveSummonMark(String owner) {
    return '$owner\'s Beschwörungsmarkierung entfernen';
  }

  @override
  String get cmdAutoLevelOn => 'Automatische Stufenaktualisierung ein';

  @override
  String get cmdAutoLevelOff => 'Automatische Stufenaktualisierung aus';

  @override
  String cmdSetCampaign(String campaign) {
    return 'Kampagne $campaign festlegen';
  }

  @override
  String cmdSetCharacterLevel(String character) {
    return 'Stufe von $character festlegen';
  }

  @override
  String cmdSetDifficulty(String difficulty) {
    return 'Schwierigkeitsgrad auf $difficulty festlegen';
  }

  @override
  String cmdSetInitiative(String character) {
    return 'Initiative von $character festlegen';
  }

  @override
  String cmdSetCharacterNote(String character) {
    return 'Notiz für $character festlegen';
  }

  @override
  String get characterNoteTitle => 'Notiz';

  @override
  String get characterNoteHint => 'Notiz hinzufügen…';

  @override
  String get characterNoteQuickAdd => 'Kurznotiz';

  @override
  String cmdSetMonsterLevel(String monster) {
    return 'Stufe von $monster festlegen';
  }

  @override
  String get cmdSetLootOwner => 'Besitzer der Plünderungskarte festlegen';

  @override
  String get cmdSetScenario => 'Szenario festlegen';

  @override
  String get cmdSetSoloOn => 'Solo-Stufenempfehlung ein';

  @override
  String get cmdSetSoloOff => 'Solo-Stufenempfehlung aus';

  @override
  String get cmdExtraAbilityShuffle => 'Fähigkeitsstapel zusätzlich mischen';

  @override
  String get cmdExtraAmdShuffle => 'AMD-Stapel zusätzlich mischen';

  @override
  String get cmdDrawnAbilityShuffle => 'Gezogenen Fähigkeitsstapel mischen';

  @override
  String get cmdDontTrackStandees => 'Figuren nicht verfolgen';

  @override
  String get cmdTrackStandees => 'Figuren verfolgen';

  @override
  String cmdTurnDone(String id) {
    return 'Zug von $id beendet';
  }

  @override
  String toastWoundDamage(String names) {
    return 'Wound damage: $names';
  }

  @override
  String cmdAddPerk(String character, int index) {
    return 'Vorteil $index für \'$character\' hinzufügen';
  }

  @override
  String cmdRemovePerk(String character, int index) {
    return 'Vorteil $index für \'$character\' entfernen';
  }

  @override
  String cmdUnlock(String id) {
    return '$id freischalten';
  }

  @override
  String cmdLock(String id) {
    return '$id sperren';
  }

  @override
  String get cmdSetLevel => 'Stufe festlegen';

  @override
  String get cmdAddSection => 'Abschnitt hinzufügen';

  @override
  String cmdAddStandee(String name, int nr) {
    return '$name $nr hinzufügen';
  }

  @override
  String get cmdDrawMonsterModifierCard => 'Monstertmodifikatorkarte ziehen';

  @override
  String cmdIncreaseHealth(String figure, int amount) {
    return 'Lebenspunkte von $figure um $amount erhöhen';
  }

  @override
  String cmdKill(String owner) {
    return '$owner besiegen';
  }

  @override
  String cmdDecreaseHealth(String owner, int amount) {
    return 'Lebenspunkte von $owner um $amount verringern';
  }

  @override
  String cmdUseFhPerks(String character) {
    return '$character verwendet Frosthaven-Vorteile';
  }

  @override
  String cmdDontUseFhPerks(String character) {
    return '$character verwendet keine Frosthaven-Vorteile';
  }

  @override
  String get cmdRemoveNoCharacters => 'Keine Charaktere entfernt';

  @override
  String get cmdRemoveNoMonsters => 'Keine Monster entfernt';

  @override
  String get superFanChoiceTitle => 'Who do you play?';

  @override
  String get superFanChoiceHint =>
      'Leave all unticked to play the whole table.';

  @override
  String superFanBannerPhone(Object names) {
    return 'Da Bears! $names\'s phone is on the SuperNetwork';
  }

  @override
  String get superFanBannerTable =>
      'Da Bears! The table is on the SuperNetwork';

  @override
  String get superFanNetworkHeading => 'SuperNetwork';

  @override
  String get superFanUnnamedDevice => 'Unnamed device';

  @override
  String get superFanHostMarker => 'host';

  @override
  String get superFanPlaysTable => 'The table';

  @override
  String get superFanYourChoice => 'You play';

  @override
  String get superFanChangeButton => 'Change';

  @override
  String superFanPlaysShared(Object name) {
    return '$name (shared)';
  }
}
