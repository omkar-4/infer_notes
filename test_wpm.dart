import 'package:infer_notes/features/aura/aura_metrics_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  SharedPreferences.setMockInitialValues({});
  final engine = AuraMetricsEngine();
  await engine.initialize();
  engine.setActiveNote('test.md', '');
  
  print('Initial WPM: ${engine.currentWPM}');
  
  engine.onTextChanged('', 'a');
  engine.onTextChanged('a', 'ab');
  engine.onTextChanged('ab', 'abc');
  engine.onTextChanged('abc', 'abcd');
  engine.onTextChanged('abcd', 'abcde');
  
  print('WPM after 5 chars (1 word): ${engine.currentWPM}');
  
  for (int i = 0; i < 20; i++) {
    engine.onTextChanged('abcde', 'abcdef');
  }
  
  print('WPM after 25 chars (5 words): ${engine.currentWPM}');
}
