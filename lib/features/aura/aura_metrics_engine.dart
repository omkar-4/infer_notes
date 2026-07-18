import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class NoteAuraMetrics {
  final String filePath;
  int totalTimeSpentSeconds;
  int typedCharacters;
  
  NoteAuraMetrics({
    required this.filePath,
    this.totalTimeSpentSeconds = 0,
    this.typedCharacters = 0,
  });
}

class AuraMetricsEngine {
  static final AuraMetricsEngine _instance = AuraMetricsEngine._internal();
  factory AuraMetricsEngine() => _instance;
  AuraMetricsEngine._internal();

  SharedPreferences? _prefs;
  
  final Map<String, NoteAuraMetrics> _metricsCache = {};
  
  String? _activeFilePath;
  Timer? _sessionTimer;
  
  final List<DateTime> _recentKeystrokes = [];
  
  int _currentWPM = 0;
  int _wordCount = 0;

  int get currentWPM => _currentWPM;
  int get currentWordCount => _wordCount;

  final StreamController<void> _metricsUpdateController = StreamController<void>.broadcast();
  Stream<void> get onMetricsUpdated => _metricsUpdateController.stream;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void setActiveNote(String? path, String initialText) {
    _sessionTimer?.cancel();
    _activeFilePath = path;
    _recentKeystrokes.clear();
    
    _currentWPM = 0;
    _wordCount = _calculateWordCount(initialText);
    
    if (path != null) {
      if (!_metricsCache.containsKey(path)) {
        _loadMetricsForPath(path);
      }
      
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_activeFilePath != null && _metricsCache.containsKey(_activeFilePath)) {
          _metricsCache[_activeFilePath!]!.totalTimeSpentSeconds += 1;
          _cleanupOldKeystrokes();
          _recalculateWPM();
          _saveMetricsThrottled(_activeFilePath!);
          _metricsUpdateController.add(null);
        }
      });
      _metricsUpdateController.add(null);
    }
  }

  void _loadMetricsForPath(String path) {
    if (_prefs == null) return;
    final timeKey = 'aura_time_$path';
    final charsKey = 'aura_chars_$path';
    
    _metricsCache[path] = NoteAuraMetrics(
      filePath: path,
      totalTimeSpentSeconds: _prefs!.getInt(timeKey) ?? 0,
      typedCharacters: _prefs!.getInt(charsKey) ?? 0,
    );
  }

  Timer? _saveThrottleTimer;
  void _saveMetricsThrottled(String path) {
    if (_saveThrottleTimer?.isActive ?? false) return;
    _saveThrottleTimer = Timer(const Duration(seconds: 5), () {
      final metrics = _metricsCache[path];
      if (metrics != null && _prefs != null) {
        _prefs!.setInt('aura_time_$path', metrics.totalTimeSpentSeconds);
        _prefs!.setInt('aura_chars_$path', metrics.typedCharacters);
      }
    });
  }

  void onTextChanged(String oldText, String newText) {
    if (_activeFilePath == null) return;
    final metrics = _metricsCache[_activeFilePath!];
    if (metrics == null) return;

    _wordCount = _calculateWordCount(newText);

    int lengthDiff = newText.length - oldText.length;
    
    if (lengthDiff > 0 && lengthDiff <= 5) {
       metrics.typedCharacters += lengthDiff;
       for (int i = 0; i < lengthDiff; i++) {
         _recentKeystrokes.add(DateTime.now());
       }
       _recalculateWPM();
    }
    _metricsUpdateController.add(null);
  }

  int _calculateWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  DateTime? _wpmBlockStartTime;

  void _cleanupOldKeystrokes() {
    if (_recentKeystrokes.isEmpty) {
      _wpmBlockStartTime = null;
      return;
    }
    
    _wpmBlockStartTime ??= _recentKeystrokes.first;
    final now = DateTime.now();
    
    // Discrete minute block: Reset to 0 exactly upon completion of a minute
    if (now.difference(_wpmBlockStartTime!).inSeconds >= 60) {
      _recentKeystrokes.clear();
      _wpmBlockStartTime = null;
    }
  }

  void _recalculateWPM() {
    _cleanupOldKeystrokes();
    _currentWPM = (_recentKeystrokes.length / 5.0).round();
  }
  String getFormattedTime(String filePath) {
    final metrics = _metricsCache[filePath];
    if (metrics == null) return "00:00:00";
    final totalSeconds = metrics.totalTimeSpentSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, "0")}:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}';
  }
}

