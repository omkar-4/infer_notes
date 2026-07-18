import 'dart:io';

void main() {
  final file = File('lib/features/aura/aura_metrics_engine.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    "return '::';",
    "return '${hours.toString().padLeft(2, \"0\")}:${minutes.toString().padLeft(2, \"0\")}:${seconds.toString().padLeft(2, \"0\")}';"
  );
  
  file.writeAsStringSync(content);
}
