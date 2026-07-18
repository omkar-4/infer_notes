import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';

class AutocompleteController extends TextEditingController {
  String? currentSuggestion;
  String? suggestionSuffix;
  int suggestionStartIndex = -1;

  AutocompleteController({super.text}) {
    addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = this.text;
    final selection = this.selection;
    
    // Only suggest if cursor is at the end of a word
    if (selection.isValid && selection.isCollapsed) {
      final cursorPosition = selection.baseOffset;
      
      // Find the word currently being typed
      // Search backwards from cursor for a space or newline
      int startIndex = -1;
      for (int i = cursorPosition - 1; i >= 0; i--) {
        if (RegExp(r'\s').hasMatch(text[i])) {
          startIndex = i;
          break;
        }
      }
      
      final currentWord = text.substring(startIndex + 1, cursorPosition);
      
      if (currentWord.length >= 3 && RegExp(r'^[a-zA-Z]+$').hasMatch(currentWord)) {
        // Find best match in english_words
        // We just take the first word that starts with the current word
        final match = all.where((w) => w.startsWith(currentWord.toLowerCase())).firstOrNull;
        
        if (match != null && match.length > currentWord.length) {
          // Preserve capitalization of the typed part, suggest the rest
          suggestionStartIndex = startIndex + 1;
          currentSuggestion = match;
          suggestionSuffix = match.substring(currentWord.length);
          return;
        }
      }
    }
    
    currentSuggestion = null;
    suggestionSuffix = null;
    suggestionStartIndex = -1;
  }

  void acceptSuggestion() {
    if (suggestionSuffix != null && selection.isValid && selection.isCollapsed) {
      final cursor = selection.baseOffset;
      final newText = text.replaceRange(cursor, cursor, suggestionSuffix!);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + suggestionSuffix!.length),
      );
    }
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (suggestionSuffix == null || !selection.isValid || !selection.isCollapsed) {
      return TextSpan(style: style, text: text);
    }

    final cursor = selection.baseOffset;
    
    // If the cursor is not at the end of the text, we have to split the text to insert the ghost text at the cursor
    final beforeCursor = text.substring(0, cursor);
    final afterCursor = text.substring(cursor);

    return TextSpan(
      style: style,
      children: [
        TextSpan(text: beforeCursor),
        TextSpan(
          text: suggestionSuffix,
          style: style?.copyWith(color: Colors.grey.withValues(alpha: 0.6)),
        ),
        TextSpan(text: afterCursor),
      ],
    );
  }
}

