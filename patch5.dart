import 'dart:io';

void main() {
  final file = File('lib/features/aura/aura_metrics_engine.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    "return '::';",
    "return '\:\:\';"
  );
  
  file.writeAsStringSync(content);
}
