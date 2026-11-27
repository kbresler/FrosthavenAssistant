// The SuperNetwork identity: a device id that is generated once and never
// changes, plus the device name and played characters the greeting carries.
// `Settings.toString` builds its JSON by hand, so a name with a quote or a
// brace must be escaped — otherwise it corrupts every other setting.
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = 'settingsState';

/// Reads throw (a failing plugin or disk); writes are recorded instead.
class _FailingReadStore extends SharedPreferencesStorePlatform {
  final written = <String, Object>{};

  @override
  Future<Map<String, Object>> getAll() =>
      throw Exception('simulated read failure');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    written[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    written.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    written.clear();
    return true;
  }
}

Future<Settings> _loadFrom(String json) async {
  SharedPreferences.setMockInitialValues({_prefsKey: json});
  final settings = Settings();
  await settings.loadFromDisk();
  return settings;
}

/// A second `Settings` reading what the first one wrote to the (mock) disk.
Future<Settings> _reload() async {
  final settings = Settings();
  await settings.loadFromDisk();
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('device id', () {
    test('is created on first start', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.loadFromDisk();
      expect(settings.deviceId, isNotEmpty);
    });

    test('is created for a save written before this setting existed', () async {
      final settings = await _loadFrom('{"darkMode": true}');
      expect(settings.deviceId, isNotEmpty);
    });

    test('is saved so the next start keeps the same one', () async {
      SharedPreferences.setMockInitialValues({});
      final first = Settings();
      await first.loadFromDisk();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_prefsKey), contains(first.deviceId),
          reason: 'the generated id must reach the disk during the first load');
    });

    test('survives a save and load, and is not regenerated', () async {
      SharedPreferences.setMockInitialValues({});
      final first = Settings();
      await first.loadFromDisk();
      await first.saveToDisk();

      final again = await _reload();
      expect(again.deviceId, equals(first.deviceId));

      await again.saveToDisk();
      final third = await _reload();
      expect(third.deviceId, equals(first.deviceId));
    });

    test('two fresh devices get different ids', () async {
      SharedPreferences.setMockInitialValues({});
      final a = Settings();
      await a.loadFromDisk();
      SharedPreferences.setMockInitialValues({});
      final b = Settings();
      await b.loadFromDisk();
      expect(a.deviceId, isNot(equals(b.deviceId)));
    });
  });

  group('device name and played characters', () {
    test('default to empty', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.loadFromDisk();
      expect(settings.deviceName.value, isEmpty);
      expect(settings.devicePlays.value, isEmpty);
    });

    test('a name with quotes and braces survives a round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final saved = Settings();
      await saved.loadFromDisk();
      saved.deviceName.value = 'Kev\'s "tablet" {home}';
      await saved.saveToDisk();

      final loaded = await _reload();
      expect(loaded.deviceName.value, equals('Kev\'s "tablet" {home}'));
      expect(loaded.deviceId, equals(saved.deviceId),
          reason: 'an escaped name must not corrupt the rest of the payload');
    });

    test('played characters survive a round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final saved = Settings();
      await saved.loadFromDisk();
      saved.devicePlays.value = ['blinkblade@1', 'geminate@2'];
      await saved.saveToDisk();

      final loaded = await _reload();
      expect(loaded.devicePlays.value, equals(['blinkblade@1', 'geminate@2']));
    });

    test('a malformed plays value is ignored, not thrown on', () async {
      final settings = await _loadFrom('{"deviceId":"d","devicePlays":"nope"}');
      expect(settings.devicePlays.value, isEmpty);
    });

    test('a failed read does not look like a first start', () async {
      // There IS a saved state — the read just could not reach it. Generating
      // an id now and saving would write defaults over the user's settings.
      SharedPreferences.setMockInitialValues({_prefsKey: '{"darkMode":true}'});
      final store = _FailingReadStore();
      SharedPreferencesStorePlatform.instance = store;
      final settings = Settings();
      await settings.loadFromDisk();
      expect(settings.deviceId, isEmpty);
      expect(store.written, isEmpty,
          reason: 'nothing may be written when the read failed');
    });
  });
}
