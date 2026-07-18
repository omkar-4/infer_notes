import 'dart:io';

void main() {
  final file = File('lib/features/aura/aura_metrics_engine.dart');
  var content = file.readAsStringSync();
  
  final methodStr = '''  String getFormattedTime(String filePath) {
    final metrics = _metricsCache[filePath];
    if (metrics == null) return "00:00:00";
    final totalSeconds = metrics.totalTimeSpentSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '\:\:\';
  }
}''';

  content = content.replaceFirst(RegExp(r'\}\s*$'), methodStr);
  file.writeAsStringSync(content);
}
