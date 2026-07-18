import 'dart:io';

void main() {
  final file = File('lib/features/aura/aura_metrics_engine.dart');
  var content = file.readAsStringSync();
  
  // Clean up the broken return statement
  content = content.replaceAll(RegExp(r"return '.*';"), "return '\:\:\';");
  
  file.writeAsStringSync(content);
}
