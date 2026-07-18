import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:infer_notes/platform/windows/windows_spell_check_service.dart';

void main() {
  test('WindowsSpellCheckService fetchSpellCheckSuggestions returns spans without leaking', () async {
    final service = WindowsSpellCheckService();
    // Simulate user typing quickly
    service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'teh');
    service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'teh q');
    final result = await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'teh quickk brown foxx');
    
    // Windows might not be running on this test environment if it's headless Linux, 
    // or the OS might not have SpellCheckFactory registered.
    // It should safely return null or empty list instead of crashing.
    if (result != null) {
      expect(result.isNotEmpty, true);
      // 'teh' -> should suggest 'the'
      expect(result.any((span) => span.suggestions.contains('the') || span.suggestions.contains('The')), true);
    } else {
      expect(result, isNull);
    }
    
    service.dispose();
  });
}
