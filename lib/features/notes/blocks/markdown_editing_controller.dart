import 'package:flutter/material.dart';

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final textVal = text;

    // Hide syntax by setting its color to transparent and font size to 0
    final syntaxStyle = baseStyle.copyWith(
      color: Colors.transparent,
      fontSize: 0.0,
    );

    final RegExp pattern = RegExp(
      r'(\*\*(.*?)\*\*)|(_([^_]+)_)|(`([^`]+)`)',
      dotAll: true,
    );

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in pattern.allMatches(textVal)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: textVal.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(1) != null) {
        // Bold: **text**
        final innerText = match.group(2) ?? '';
        spans.add(TextSpan(text: '**', style: syntaxStyle));
        spans.add(TextSpan(
          text: innerText,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
        spans.add(TextSpan(text: '**', style: syntaxStyle));
      } else if (match.group(3) != null) {
        // Italic: _text_
        final innerText = match.group(4) ?? '';
        spans.add(TextSpan(text: '_', style: syntaxStyle));
        spans.add(TextSpan(
          text: innerText,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
        spans.add(TextSpan(text: '_', style: syntaxStyle));
      } else if (match.group(5) != null) {
        // Inline code: `text`
        final innerText = match.group(6) ?? '';
        spans.add(TextSpan(text: '`', style: syntaxStyle));
        spans.add(TextSpan(
          text: innerText,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.withOpacity(0.2),
          ),
        ));
        spans.add(TextSpan(text: '`', style: syntaxStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < textVal.length) {
      spans.add(TextSpan(
        text: textVal.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}
