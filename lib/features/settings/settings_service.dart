import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  // Highly optimized ValueNotifiers for O(1) reactive UI updates
  final ValueNotifier<bool> showWordCount = ValueNotifier(true);
  final ValueNotifier<bool> showWPM = ValueNotifier(true);
  final ValueNotifier<bool> showTimer = ValueNotifier(true);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    showWordCount.value = _prefs!.getBool('setting_show_words') ?? true;
    showWPM.value = _prefs!.getBool('setting_show_wpm') ?? true;
    showTimer.value = _prefs!.getBool('setting_show_timer') ?? true;
  }

  void toggleWordCount(bool val) {
    showWordCount.value = val;
    _prefs?.setBool('setting_show_words', val);
  }

  void toggleWPM(bool val) {
    showWPM.value = val;
    _prefs?.setBool('setting_show_wpm', val);
  }

  void toggleTimer(bool val) {
    showTimer.value = val;
    _prefs?.setBool('setting_show_timer', val);
  }
}
