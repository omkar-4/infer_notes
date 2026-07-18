import 'dart:io';

void main() {
  final file = File('lib/features/aura/aura_metrics_engine.dart');
  var content = file.readAsStringSync();
  
  final oldLogic = '''    void _cleanupOldKeystrokes() {
    final now = DateTime.now();
    _recentKeystrokes.removeWhere((ts) => now.difference(ts).inSeconds > 60);
  }

  void _recalculateWPM() {
    _cleanupOldKeystrokes();
    if (_recentKeystrokes.isEmpty) {
      _currentWPM = 0;
      return;
    }
    
    final now = DateTime.now();
    final oldest = _recentKeystrokes.first;
    double secondsElapsed = now.difference(oldest).inMilliseconds / 1000.0;
    
    if (secondsElapsed < 10.0) secondsElapsed = 10.0;
    
    double words = _recentKeystrokes.length / 5.0;
    double wpm = words * (60.0 / secondsElapsed);
    
    if (wpm > 250) wpm = 250;
    _currentWPM = wpm.round();
  }''';

  final newLogic = '''  DateTime? _wpmBlockStartTime;

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
  }''';

  content = content.replaceFirst(oldLogic, newLogic);
  file.writeAsStringSync(content);
}
