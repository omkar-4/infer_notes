import 'dart:io';

void main() {
  final file = File('lib/features/notes/note_editor_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
      "import 'package:infer_notes/features/aura/aura_status_bar.dart';",
      "import 'package:infer_notes/features/aura/aura_status_bar.dart';\nimport 'package:infer_notes/features/aura/aura_metrics_engine.dart';");

  content = content.replaceFirst(
      "const SnackBar(\n        content: Text('You are already using the latest version.'),\n        duration: Duration(seconds: 2),",
      "SnackBar(\n        content: Text('You are already using the latest version (\).'),\n        duration: const Duration(seconds: 2),");

  content = content.replaceFirst(
      "onChanged: (val) {\n                                        if (currentFilePath != null) {\n                                          _fileCache[currentFilePath!] = val;\n                                          setState(() {\n                                            unsavedFiles.add(currentFilePath!);\n                                          });\n                                        }\n                                      },",
      "onChanged: (val) {\n                                        if (currentFilePath != null) {\n                                          final oldText = _fileCache[currentFilePath!] ?? '';\n                                          _fileCache[currentFilePath!] = val;\n                                          AuraMetricsEngine().onTextChanged(oldText, val);\n                                          if (!unsavedFiles.contains(currentFilePath!)) {\n                                            setState(() {\n                                              unsavedFiles.add(currentFilePath!);\n                                            });\n                                          }\n                                        }\n                                      },");

  file.writeAsStringSync(content);
}
