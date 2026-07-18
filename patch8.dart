import 'dart:io';

void main() {
  final file = File('lib/features/notes/note_editor_screen.dart');
  var content = file.readAsStringSync();
  
  final oldLogic = '''                                      onChanged: (val) {
                                        if (currentFilePath != null) {
                                          _fileCache[currentFilePath!] = val;
                                          setState(() {
                                            unsavedFiles.add(currentFilePath!);
                                          });
                                        }
                                      },''';

  final newLogic = '''                                      onChanged: (val) {
                                        if (currentFilePath != null) {
                                          final oldText = _fileCache[currentFilePath!] ?? '';
                                          _fileCache[currentFilePath!] = val;
                                          AuraMetricsEngine().onTextChanged(oldText, val);
                                          setState(() {
                                            unsavedFiles.add(currentFilePath!);
                                          });
                                        }
                                      },''';

  content = content.replaceFirst(oldLogic, newLogic);
  file.writeAsStringSync(content);
}
