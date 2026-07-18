import 'package:english_words/english_words.dart';
import 'dart:math';

class NlpEngine {
  static late final List<String> commonWords;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    commonWords = all.where((w) => w.length >= 3 && RegExp(r'^[a-z]+$').hasMatch(w)).toList();
    commonWords.sort();
    _initialized = true;
  }

  static String? getSuggestion(String currentWord) {
    if (!_initialized) initialize();
    if (currentWord.length < 3) return null;
    
    final lower = currentWord.toLowerCase();

    // 1. O(log N) Binary Search for prefix
    int low = 0;
    int high = commonWords.length - 1;
    
    while (low <= high) {
      int mid = low + ((high - low) >> 1);
      int comp = commonWords[mid].compareTo(lower);
      
      if (comp == 0) return null;
      
      if (comp < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    
    if (low < commonWords.length && commonWords[low].startsWith(lower)) {
      int bestIdx = low;
      int shortestLen = commonWords[low].length;
      for (int i = low; i < commonWords.length; i++) {
        if (!commonWords[i].startsWith(lower)) break;
        if (commonWords[i].length < shortestLen) {
          shortestLen = commonWords[i].length;
          bestIdx = i;
        }
      }
      return _matchCase(currentWord, commonWords[bestIdx]);
    }
    
    // 2. Levenshtein for typos
    if (lower.length >= 4) {
      String bestMatch = '';
      int bestDist = 3;
      
      for (final word in commonWords) {
        if (word[0] != lower[0]) continue;
        if ((word.length - lower.length).abs() > 2) continue;
        
        final dist = _levenshtein(lower, word);
        if (dist < bestDist) {
          bestDist = dist;
          bestMatch = word;
          if (dist == 1) break;
        }
      }
      
      if (bestDist <= 2 && bestMatch.isNotEmpty) {
        return _matchCase(currentWord, bestMatch);
      }
    }
    
    return null;
  }

  static String _matchCase(String original, String match) {
    if (original.isEmpty) return match;
    bool isUpper = original[0] == original[0].toUpperCase();
    if (isUpper) {
      return match[0].toUpperCase() + match.substring(1);
    }
    return match;
  }

  static int _levenshtein(String a, String b) {
    var v0 = List<int>.filled(b.length + 1, 0);
    var v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i <= b.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }
}
