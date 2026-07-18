import 'package:flutter/material.dart';

Offset getCursorPosition(String text, int cursorIndex, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  );
  painter.layout(maxWidth: maxWidth);
  return painter.getOffsetForCaret(TextPosition(offset: cursorIndex), Rect.zero);
}
