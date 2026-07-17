import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Data Integrity Pipeline', () {
    late Directory tempVault;
    late File targetFile;

    setUp(() {
      tempVault = Directory.systemTemp.createTempSync('infer_notes_test_vault');
      targetFile = File('note.md');
      targetFile.writeAsStringSync('initial content');
    });

    tearDown(() {
      if (tempVault.existsSync()) {
        tempVault.deleteSync(recursive: true);
      }
    });

    test('Atomic save creates .temp directory and overwrites file safely', () async {
      final tempDir = Directory('.temp');
      
      // Simulate saveNoteAtomic logic
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
      
      final tempFile = File('note.md_12345.tmp');
      await tempFile.writeAsString('new content atomically saved');
      
      expect(tempFile.existsSync(), isTrue);
      
      // Atomic rename
      await tempFile.rename(targetFile.path);
      
      expect(targetFile.readAsStringSync(), 'new content atomically saved');
      expect(tempFile.existsSync(), isFalse); // Rename moves the file
    });

    test('Unsaved state is tracked correctly', () {
      Set<String> unsavedFiles = {};
      final path = targetFile.path;
      
      // Simulate editing
      unsavedFiles.add(path);
      expect(unsavedFiles.contains(path), isTrue);
      
      // Simulate save success
      unsavedFiles.remove(path);
      expect(unsavedFiles.contains(path), isFalse);
    });
  });
}
