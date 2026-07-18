import 'dart:io';

void main() {
  final file = File('lib/features/notes/note_editor_screen.dart');
  var content = file.readAsStringSync();
  
  final oldLogic = '''                                      style: Theme.of(context).textTheme.bodyLarge,''';

  final newLogic = '''                                      style: Theme.of(context).textTheme.bodyLarge,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Start typing...',
                                        contentPadding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 16.0),
                                      ),
                                      onChanged: (val) {
                                        if (currentFilePath != null) {
                                          final oldText = _fileCache[currentFilePath!] ?? '';
                                          _fileCache[currentFilePath!] = val;
                                          AuraMetricsEngine().onTextChanged(oldText, val);
                                          setState(() {
                                            unsavedFiles.add(currentFilePath!);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                    ),
                  ],''';

  content = content.replaceFirst(oldLogic, newLogic);
  file.writeAsStringSync(content);
}
